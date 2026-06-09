import CryptoKit
import Foundation
import SwiftData

@MainActor
enum SeedImporter {
    enum SeedError: Error {
        case bundleResourceMissing(String)
        case malformedJSON(String)
    }

    /// Dev hack: 本机源目录, 用于 hot reload 跳 bundle 缓存.
    static let devSourceDir = "/Users/fujie/projects/天津买房/reports/extracted"

    /// Deterministic UUID from JSON seed id ("sch_xxx" / "zon_xxx" / etc).
    /// MD5 → 16 bytes → UUID; identical strings produce identical UUIDs across runs.
    static func uuid(from seedId: String) -> UUID {
        let bytes = Array(Insecure.MD5.hash(data: Data(seedId.utf8)))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// Returns true if import ran, false if skipped (already imported).
    @discardableResult
    static func runIfNeeded(
        into context: ModelContext,
        progress: @escaping (Double, String) -> Void = { _, _ in }
    ) throws -> Bool {
        // 每次启动清理无主实体(独立于 seed 守卫)
        LegacyMigrator.cleanupOrphans(in: context)
        LegacyMigrator.backfillLayerIds(in: context) // 旧库兜底:nil → 默认层
        // 已有 Dataset → 已 seed,跳过
        if try !context.fetch(FetchDescriptor<Dataset>()).isEmpty {
            StyleConsolidationMigrator.run(in: context)
            normalizeAreaNamesIfNeeded(in: context)
            seedDistrictBoundariesIfNeeded(in: context)
            seedRoadLinesIfNeeded(in: context)
            migrateFilterEntityTypesIfNeeded(in: context)
            ensureAreaCategoryOptions(in: context)
            try context.save()
            progress(1.0, "已就绪")
            return false
        }

        progress(0.05, "读取 JSON")
        var bundle = SeedBundle()
        let zones = try loadJSON("zones")
        let schools = try loadJSON("schools")
        bundle.zones = parseZones(zones)
        bundle.schools = parseSchools(schools)
        if let compounds = try? loadJSON("compounds") { bundle.compounds = parseCompounds(compounds) }
        if let groups = try? loadJSON("groups") { bundle.groups = parseGroups(groups) }
        if let policies = try? loadJSON("policies") { bundle.policies = parsePolicies(policies) }
        if let admission = try? loadJSON("admission_rates") { bundle.admissionRates = parseAdmissionRates(admission) }
        if let matches = try? loadJSON("compound_school_match") { bundle.matches = parseMatches(matches) }

        progress(0.50, "聚合 zone tier")
        aggregateZoneTier(&bundle)

        progress(0.70, "迁移写入实体")
        try LegacyMigrator.run(seeds: bundle, in: context)
        LegacyMigrator.backfillLayerIds(in: context) // 新库:全部实体归默认层

        progress(0.95, "保存")
        StyleConsolidationMigrator.run(in: context)
        seedDistrictBoundariesIfNeeded(in: context)
        seedRoadLinesIfNeeded(in: context)
        migrateFilterEntityTypesIfNeeded(in: context)
        try context.save()
        progress(1.0, "完成")
        return true
    }

    /// Zone tier = max coarse tier across schools whose zoneId == zone.id.
    private static func aggregateZoneTier(_ bundle: inout SeedBundle) {
        let priority = ["重点": 2, "区重点": 1, "普通": 0]
        var byZone: [UUID: [SchoolSeed]] = [:]
        for s in bundle.schools {
            guard let zid = s.zoneId else { continue }
            byZone[zid, default: []].append(s)
        }
        for i in bundle.zones.indices {
            let members = byZone[bundle.zones[i].id] ?? []
            if members.isEmpty { continue }
            let best = members.map(\.tier).max { (priority[$0] ?? 0) < (priority[$1] ?? 0) }
            bundle.zones[i].tier = best ?? "普通"
        }
    }

    /// 已迁移库的幂等片区改名:仅当有 dataset 未标 areaNamesNormalizedV1 时才 load zones(便宜,101 行)。
    private static func normalizeAreaNamesIfNeeded(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>())) ?? []
        let pending = datasets.filter { !$0.areaNamesNormalizedV1 }
        guard !pending.isEmpty, let root = try? loadJSON("zones") else { return }
        let zones = parseZones(root)
        for ds in pending {
            LegacyMigrator.normalizeAreaNames(zones: zones, dataset: ds, in: context)
        }
    }

    /// 幂等播种天津 16 行政区边界为新 Area(GCJ-02,与现有数据/底图一致)。
    /// 确定性 id(dist_bound_{datasetId}_{adcode})防重复;归默认图层;闸门 districtBoundariesSeededV1。
    private static func seedDistrictBoundariesIfNeeded(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>())) ?? []
        let pending = datasets.filter { !$0.districtBoundariesSeededV1 }
        guard !pending.isEmpty, let root = try? loadJSON("district_boundaries") else { return }
        let items = parseDistrictBoundaries(root)
        guard !items.isEmpty else { return }
        for ds in pending {
            let dsId = ds.id
            let defaultLayerId = (try? context.fetch(FetchDescriptor<Layer>(
                predicate: #Predicate { $0.datasetId == dsId && !$0.deleted }
            )))?.first(where: { $0.isDefault })?.id
            for it in items {
                let aid = uuid(from: "dist_bound_\(dsId.uuidString)_\(it.adcode)")
                let exists = ((try? context.fetch(FetchDescriptor<Area>(
                    predicate: #Predicate { $0.id == aid }
                )))?.isEmpty == false)
                if exists { continue }
                let area = Area(datasetId: dsId, name: it.name, geometryKind: "polygon", geometryJSON: it.geometryJSON)
                area.id = aid
                area.layerId = defaultLayerId
                area.category = "行政区"
                area.fillOpacity = 0.08
                context.insert(area)
            }
            ds.districtBoundariesSeededV1 = true
        }
    }

    /// 幂等播种天津"三环十四射"道路为 Area 折线(GCJ-02)。确定性 id 防重复;
    /// 归默认图层;category="道路";ring/radial → tags;闸门 roadLinesSeededV1。
    private static func seedRoadLinesIfNeeded(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>())) ?? []
        let pending = datasets.filter { !$0.roadLinesSeededV1 }
        guard !pending.isEmpty, let root = try? loadJSON("road_lines") else { return }
        let items = parseRoadLines(root)
        guard !items.isEmpty else { return }
        for ds in pending {
            let dsId = ds.id
            let roadLayerId = roadNetworkLayerId(dsId: dsId, in: context)
            for it in items {
                let aid = uuid(from: "road_line_\(dsId.uuidString)_\(it.name)")
                let exists = ((try? context.fetch(FetchDescriptor<Area>(
                    predicate: #Predicate { $0.id == aid }
                )))?.isEmpty == false)
                if exists { continue }
                let area = Area(datasetId: dsId, name: it.name, geometryKind: "line", geometryJSON: it.geometryJSON)
                area.id = aid
                area.layerId = roadLayerId // 三环十四射 + 快速路 → 「路网」图层
                area.category = "道路"
                area.tags = it.tags // 三环十四射:总标签+环名/射线;快速路:["快速路"]
                area.styleFillHex = roadFillHex(tags: it.tags) // 三环各色 + 射线一色 + 快速路一色
                context.insert(area)
            }
            ds.roadLinesSeededV1 = true
        }
    }

    /// 「路网」图层 id:存在则复用,否则建一个。所有道路(三环十四射+快速路)归此层。
    private static func roadNetworkLayerId(dsId: UUID, in context: ModelContext) -> UUID? {
        let layers = (try? context.fetch(FetchDescriptor<Layer>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted }
        ))) ?? []
        if let existing = layers.first(where: { $0.name == "路网" }) { return existing.id }
        let layer = Layer(datasetId: dsId, name: "路网")
        layer.enabled = true
        layer.iconSF = "road.lanes"
        layer.sortOrder = (layers.map(\.sortOrder).max() ?? 0) + 1
        context.insert(layer)
        return layer.id
    }

    /// 道路按类上色:三环各一色,射线一色,快速路一色。线渲染取 fillHex 作线色。
    private static func roadFillHex(tags: [String]) -> String {
        if tags.contains("内环") { return "#E53935" } // 红
        if tags.contains("中环") { return "#FB8C00" } // 橙
        if tags.contains("外环") { return "#1E88E5" } // 蓝
        if tags.contains("快速路") { return "#8E24AA" } // 紫
        return "#43A047" // 射线/其他 — 绿
    }

    private static func parseRoadLines(
        _ root: [String: Any]
    ) -> [(name: String, geometryJSON: String, tags: [String])] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [(name: String, geometryJSON: String, tags: [String])] = []
        for it in items {
            guard let name = it["name"] as? String,
                  let geom = it["geometry"],
                  let data = try? JSONSerialization.data(withJSONObject: geom),
                  let geomStr = String(data: data, encoding: .utf8)
            else { continue }
            var tags: [String] = []
            if (it["express"] as? Bool) == true {
                tags = ["快速路"] // 快速路系统(高架),独立体系
            } else {
                tags.append("三环十四射") // 统一总标签,便于一键过滤
                if let ring = it["ring"] as? String, !ring.isEmpty { tags.append(ring) }
                if (it["radial"] as? Bool) == true { tags.append("射线") }
            }
            out.append((name, geomStr, tags))
        }
        return out
    }

    /// 幂等回填普通过滤器 entityType(旧库)。新库 seed 已带 entityType,会立即标记跳过。
    private static func migrateFilterEntityTypesIfNeeded(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>())) ?? []
        for ds in datasets where !ds.filterEntityTypeMigratedV1 {
            LegacyMigrator.migrateFilterEntityTypes(dataset: ds, in: context)
        }
    }

    /// 既有库幂等补齐 area.category 新枚举值(学区/道路/街道)。
    private static func ensureAreaCategoryOptions(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>())) ?? []
        for ds in datasets {
            LegacyMigrator.ensureAreaCategoryOptions(dataset: ds, in: context)
        }
    }

    private static func parseDistrictBoundaries(
        _ root: [String: Any]
    ) -> [(adcode: String, name: String, geometryJSON: String)] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [(adcode: String, name: String, geometryJSON: String)] = []
        for it in items {
            guard let name = it["name"] as? String,
                  let geom = it["geometry"],
                  let data = try? JSONSerialization.data(withJSONObject: geom),
                  let geomStr = String(data: data, encoding: .utf8)
            else { continue }
            let adcode = (it["adcode"] as? Int).map(String.init)
                ?? (it["adcode"] as? String)
                ?? name
            out.append((adcode, name, geomStr))
        }
        return out
    }

    // MARK: - Bundle / Dev source loading

    private static func loadJSON(_ name: String) throws -> [String: Any] {
        let devURL = URL(fileURLWithPath: "\(devSourceDir)/\(name).json")
        if FileManager.default.fileExists(atPath: devURL.path),
           let data = try? Data(contentsOf: devURL),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            return dict
        }
        let url = Bundle.main.url(forResource: name, withExtension: "json")
            ?? Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Seeds")
        guard let url else {
            throw SeedError.bundleResourceMissing("\(name).json")
        }
        let data = try Data(contentsOf: url)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SeedError.malformedJSON(name)
        }
        return dict
    }

    // MARK: - Zones

    private static func parseZones(_ root: [String: Any]) -> [ZoneSeed] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [ZoneSeed] = []
        for item in items {
            guard let seedId = item["id"] as? String,
                  let district = item["district"] as? String,
                  let zoneName = item["zone_name"] as? String
            else { continue }
            let stage = (item["geometry_stage"] as? String) ?? "hull"
            let geometryString: String
            if let geom = item["geometry"], !(geom is NSNull) {
                let data = (try? JSONSerialization.data(withJSONObject: geom)) ?? Data()
                geometryString = String(data: data, encoding: .utf8) ?? ""
            } else {
                geometryString = ""
            }
            var zone = ZoneSeed(
                id: uuid(from: seedId),
                name: zoneName,
                primaryDistrict: district,
                geometry: geometryString,
                geometryStage: stage
            )
            zone.textDescription = item["areas_text"] as? String
            zone.note = item["note"] as? String
            zone.structureJSON = encodeIfPresent(item["structure"])
            zone.middleSchoolPoolJSON = encodeIfPresent(item["middle_school_pool"])
            if let sens = item["sensitive"] as? [String: Any] {
                zone.sensitiveHighlight = sens["highlight"] as? String
                zone.sensitiveSource = sens["source"] as? String
                zone.sensitiveNote = sens["note"] as? String
            }
            out.append(zone)
        }
        return out
    }

    // MARK: - Schools

    private static func parseSchools(_ root: [String: Any]) -> [SchoolSeed] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [SchoolSeed] = []
        for item in items {
            guard let seedId = item["id"] as? String,
                  let name = item["name"] as? String,
                  let district = item["district"] as? String
            else { continue }
            let level = (item["level"] as? String) ?? "primary"
            let type = level == "middle" ? "初中" : "小学"
            let isJiunian = (item["is_jiunian"] as? Bool) == true
            let tier = coarseTierFromSensitive(item["sensitive"]) ?? "普通"
            let zoneId: UUID? = (item["zone_id"] as? String).map(uuid(from:))
            var school = SchoolSeed(id: uuid(from: seedId), name: name, district: district)
            school.type = type
            school.zoneId = zoneId
            school.tier = tier
            school.zoneName = item["zone_name"] as? String
            school.address = item["address"] as? String
            school.phone = item["phone"] as? String
            school.tuition = item["tuition"] as? String
            school.communitiesText = item["communities_text"] as? String
            school.notes = item["note"] as? String
            school.sourceCode = item["source"] as? String
            // campuses 可能是 int 或 string
            if let c = item["campuses"] as? Int { school.campuses = String(c) }
            else if let c = item["campuses"] as? String { school.campuses = c }
            school.isPublicSchool = !((item["is_private"] as? Bool) ?? false)
            school.isJiunian = isJiunian
            school.is12Year = (item["is_12year"] as? Bool) ?? false
            school.isMarketFive = (item["is_market_five"] as? Bool) ?? false
            school.isMarketKey = (item["is_market_key"] as? Bool) ?? false
            if let lat = item["lat"] as? Double, let lon = item["lon"] as? Double {
                school.lat = lat
                school.lon = lon
            }
            school.geocodeSource = item["geocode_source"] as? String
            school.geocodeConfidence = item["geocode_confidence"] as? String
            if let sens = item["sensitive"] as? [String: Any] {
                school.sensitiveTierLetter = sens["tier_letter"] as? String
                school.sensitiveTierLabel = sens["tier_label"] as? String
                school.sensitiveRankOverall = sens["rank_overall"] as? Int
                school.sensitiveTopPercentile = sens["top_percentile"] as? Int
                school.sensitiveTierRank = sens["tier_rank"] as? Int
                school.sensitiveComment = sens["comment"] as? String
                school.sensitiveDataOrigin = sens["data_origin"] as? String
                school.sensitiveSource = sens["source"] as? String
                school.sensitiveSourceUrl = sens["source_url"] as? String
                school.sensitiveNote = sens["note"] as? String
            }
            out.append(school)
        }
        return out
    }

    // MARK: - Compounds

    private static func parseCompounds(_ root: [String: Any]) -> [CompoundSeed] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [CompoundSeed] = []
        for item in items {
            guard let seedId = item["id"] as? String,
                  let name = item["name"] as? String,
                  let district = item["district"] as? String
            else { continue }
            // JSON 无 lat/lon, 默认值
            let lat = (item["latitude"] as? Double) ?? (item["lat"] as? Double) ?? 39.1
            let lon = (item["longitude"] as? Double) ?? (item["lon"] as? Double) ?? 117.2
            var c = CompoundSeed(id: uuid(from: seedId), name: name, district: district)
            c.latitude = lat
            c.longitude = lon
            c.districtGroup = item["district_group"] as? String
            c.address = (item["address"] as? String) ?? ""
            c.availableUnits = encodeIfPresent(item["available_units"])
            c.areaSegments = item["area_segments"] as? String
            c.priceSegments = item["price_segments"] as? String
            c.finishType = item["finish_type"] as? String
            c.deliveryTime = item["delivery_time"] as? String
            c.isNewHouse = (item["is_new_house"] as? Bool) ?? true
            c.sourceCode = item["source"] as? String
            c.sourceRow = item["source_row"] as? Int
            if let zid = item["zone_id"] as? String {
                c.zoneId = uuid(from: zid)
            }
            if let psid = item["primary_school_id"] as? String {
                c.primarySchoolId = uuid(from: psid)
            }
            if let sens = item["sensitive"] as? [String: Any] {
                c.sensitivePros = sens["pros"] as? String
                c.sensitiveCons = sens["cons"] as? String
                c.sensitiveSource = sens["source"] as? String
                c.sensitiveNote = sens["note"] as? String
            }
            out.append(c)
        }
        return out
    }

    // MARK: - Groups

    private static func parseGroups(_ root: [String: Any]) -> [GroupSeed] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [GroupSeed] = []
        for item in items {
            guard let seedId = item["id"] as? String,
                  let name = item["name"] as? String,
                  let district = item["district"] as? String
            else { continue }
            var g = GroupSeed(id: uuid(from: seedId), name: name, district: district)
            g.leadsJSON = encodeIfPresent(item["leads"]) ?? "[]"
            g.membersJSON = encodeIfPresent(item["members"]) ?? "[]"
            g.note = item["note"] as? String
            out.append(g)
        }
        return out
    }

    // MARK: - Policies

    private static func parsePolicies(_ root: [String: Any]) -> [PolicySeed] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [PolicySeed] = []
        for item in items {
            guard let seedId = item["id"] as? String,
                  let category = item["category"] as? String,
                  let name = item["name"] as? String
            else { continue }
            var p = PolicySeed(id: uuid(from: seedId), category: category, name: name)
            p.subcategory = item["subcategory"] as? String
            p.sourceCode = item["source"] as? String
            p.note = item["note"] as? String
            p.description_ = item["description"] as? String
            p.effectiveDate = item["effective_date"] as? String
            p.timing = item["timing"] as? String
            p.eligibilityJSON = encodeIfPresent(item["eligibility"])
            p.docsJSON = encodeIfPresent(item["docs"])
            p.applicableJSON = encodeIfPresent(item["applicable"])
            p.caveatsJSON = encodeIfPresent(item["caveats"])
            p.rulesJSON = encodeIfPresent(item["rules"])
            p.rulesByDistrictJSON = encodeIfPresent(item["rules_by_district"])
            p.schoolsJSON = encodeIfPresent(item["schools"])
            p.specificSchools3yrJSON = encodeIfPresent(item["specific_schools_3yr"])
            p.stepsJSON = encodeIfPresent(item["steps"])
            p.processJSON = encodeIfPresent(item["process"])
            out.append(p)
        }
        return out
    }

    // MARK: - Admission rates

    private static func parseAdmissionRates(_ root: [String: Any]) -> [AdmissionRateSeed] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [AdmissionRateSeed] = []
        for item in items {
            guard let district = item["district"] as? String,
                  let year = item["year"] as? Int
            else { continue }
            let seedKey = "adm_\(district)_\(year)"
            var r = AdmissionRateSeed(id: uuid(from: seedKey), district: district, year: year)
            r.gaokaoAdmitPct = (item["gaokao_admit_pct"] as? Int) ?? 0
            r.vocationalAdmitPct = (item["vocational_admit_pct"] as? Int) ?? 0
            r.sourceCode = item["source"] as? String
            out.append(r)
        }
        return out
    }

    // MARK: - Compound-school matches

    private static func parseMatches(_ root: [String: Any]) -> [MatchSeed] {
        guard let items = root["items"] as? [[String: Any]] else { return [] }
        var out: [MatchSeed] = []
        for item in items {
            guard let cid = item["compound_id"] as? String,
                  let cname = item["compound_name"] as? String,
                  let district = item["district"] as? String
            else { continue }
            var m = MatchSeed(
                id: uuid(from: "match_" + cid),
                compoundId: uuid(from: cid),
                compoundName: cname,
                district: district
            )
            m.mappedDistrict = item["mapped_district"] as? String
            m.primaryMatchesJSON = encodeIfPresent(item["primary_matches"]) ?? "[]"
            m.middleMatchesJSON = encodeIfPresent(item["middle_matches"]) ?? "[]"
            m.needsManualReview = (item["needs_manual_review"] as? Bool) ?? false
            out.append(m)
        }
        return out
    }

    // MARK: - Helpers

    /// JSON-encode any value (array/dict/scalar) into string; nil if missing or NSNull.
    private static func encodeIfPresent(_ v: Any?) -> String? {
        guard let v, !(v is NSNull) else { return nil }
        guard JSONSerialization.isValidJSONObject(v) || v is String || v is NSNumber else {
            // 标量 wrap in array to be JSON-valid
            return nil
        }
        if let s = v as? String { return s }
        if let data = try? JSONSerialization.data(withJSONObject: v, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8)
        {
            return str
        }
        return nil
    }

    /// 3-tier coarse: 重点 / 区重点 / 普通.
    /// Priority: tier_letter (precise) → tier_label (label).
    private static func coarseTierFromSensitive(_ raw: Any?) -> String? {
        guard let s = raw as? [String: Any] else { return nil }
        if let letter = s["tier_letter"] as? String, !letter.isEmpty {
            switch letter {
            case "A++", "A+": return "重点"
            case "A", "B+": return "区重点"
            default: return "普通"
            }
        }
        if let label = s["tier_label"] as? String, !label.isEmpty {
            switch label {
            case "重点", "顶尖", "强校": return "重点"
            case "区重点", "优质", "中上": return "区重点"
            default: return "普通"
            }
        }
        return nil
    }
}
