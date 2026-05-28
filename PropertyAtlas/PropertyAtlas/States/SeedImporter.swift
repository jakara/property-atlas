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

    static func needsImport(_ context: ModelContext) -> Bool {
        var fd = FetchDescriptor<LegacySchoolZone>()
        fd.fetchLimit = 1
        return ((try? context.fetchCount(fd)) ?? 0) == 0
    }

    /// Returns true if import ran, false if skipped (already imported).
    @discardableResult
    static func runIfNeeded(
        into context: ModelContext,
        progress: @escaping (Double, String) -> Void = { _, _ in }
    ) throws -> Bool {
        // P1: Try legacy migration first (idempotent)
        try LegacyMigrator.run(in: context)
        // If migration produced a Dataset, skip the rest (already migrated)
        let datasets = try context.fetch(FetchDescriptor<Dataset>())
        if !datasets.isEmpty {
            progress(1.0, "已迁移")
            return false
        }

        guard needsImport(context) else {
            progress(1.0, "已导入")
            return false
        }
        progress(0.05, "读取 zones.json")
        let zones = try loadJSON("zones")
        progress(0.10, "读取 schools.json")
        let schools = try loadJSON("schools")
        progress(0.15, "读取 compounds.json")
        let compounds = try? loadJSON("compounds")
        progress(0.18, "读取 groups.json")
        let groups = try? loadJSON("groups")
        progress(0.20, "读取 policies.json")
        let policies = try? loadJSON("policies")
        progress(0.22, "读取 admission_rates.json")
        let admission = try? loadJSON("admission_rates")
        progress(0.24, "读取 compound_school_match.json")
        let matches = try? loadJSON("compound_school_match")

        progress(0.30, "导入 zones")
        importZones(zones, into: context)

        progress(0.50, "导入 schools")
        importSchools(schools, into: context)

        if let compounds {
            progress(0.70, "导入 compounds")
            importCompounds(compounds, into: context)
        }
        if let groups {
            progress(0.78, "导入 groups")
            importGroups(groups, into: context)
        }
        if let policies {
            progress(0.82, "导入 policies")
            importPolicies(policies, into: context)
        }
        if let admission {
            progress(0.85, "导入 admission_rates")
            importAdmissionRates(admission, into: context)
        }
        if let matches {
            progress(0.88, "导入 compound_school_match")
            importCompoundSchoolMatches(matches, into: context)
        }

        progress(0.92, "聚合 zone tier")
        aggregateZoneTier(context: context)

        progress(0.95, "保存")
        try context.save()
        progress(1.0, "完成")
        return true
    }

    /// Zone tier = max coarse tier across schools whose zoneId == zone.id.
    private static func aggregateZoneTier(context: ModelContext) {
        let priority = ["重点": 2, "区重点": 1, "普通": 0]
        let zones = (try? context.fetch(FetchDescriptor<LegacySchoolZone>())) ?? []
        let schools = (try? context.fetch(FetchDescriptor<LegacySchool>())) ?? []
        var byZone: [UUID: [LegacySchool]] = [:]
        for s in schools {
            guard let zid = s.zoneId else { continue }
            byZone[zid, default: []].append(s)
        }
        for zone in zones {
            let members = byZone[zone.id] ?? []
            if members.isEmpty { continue }
            let best = members.map(\.tier)
                .max { (priority[$0] ?? 0) < (priority[$1] ?? 0) }
            zone.tier = best ?? "普通"
        }
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

    private static func importZones(_ root: [String: Any], into context: ModelContext) {
        guard let items = root["items"] as? [[String: Any]] else { return }
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
            let zone = LegacySchoolZone(
                id: uuid(from: seedId),
                name: zoneName,
                tier: "普通", // aggregateZoneTier 会覆盖
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
            context.insert(zone)
        }
    }

    // MARK: - Schools

    private static func importSchools(_ root: [String: Any], into context: ModelContext) {
        guard let items = root["items"] as? [[String: Any]] else { return }
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
            let school = LegacySchool(
                id: uuid(from: seedId),
                name: name,
                type: type,
                zoneId: zoneId,
                district: district,
                tier: tier
            )
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
            context.insert(school)
        }
    }

    // MARK: - Compounds

    private static func importCompounds(_ root: [String: Any], into context: ModelContext) {
        guard let items = root["items"] as? [[String: Any]] else { return }
        for item in items {
            guard let seedId = item["id"] as? String,
                  let name = item["name"] as? String,
                  let district = item["district"] as? String
            else { continue }
            // JSON 无 lat/lon, 默认值
            let lat = (item["latitude"] as? Double) ?? (item["lat"] as? Double) ?? 39.1
            let lon = (item["longitude"] as? Double) ?? (item["lon"] as? Double) ?? 117.2
            let c = LegacyCompound(
                id: uuid(from: seedId),
                name: name,
                district: district,
                latitude: lat,
                longitude: lon
            )
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
            context.insert(c)
        }
    }

    // MARK: - Groups

    private static func importGroups(_ root: [String: Any], into context: ModelContext) {
        guard let items = root["items"] as? [[String: Any]] else { return }
        for item in items {
            guard let seedId = item["id"] as? String,
                  let name = item["name"] as? String,
                  let district = item["district"] as? String
            else { continue }
            let g = SchoolGroup(id: uuid(from: seedId), name: name, district: district)
            g.leadsJSON = encodeIfPresent(item["leads"]) ?? "[]"
            g.membersJSON = encodeIfPresent(item["members"]) ?? "[]"
            g.note = item["note"] as? String
            context.insert(g)
        }
    }

    // MARK: - Policies

    private static func importPolicies(_ root: [String: Any], into context: ModelContext) {
        guard let items = root["items"] as? [[String: Any]] else { return }
        for item in items {
            guard let seedId = item["id"] as? String,
                  let category = item["category"] as? String,
                  let name = item["name"] as? String
            else { continue }
            let p = Policy(id: uuid(from: seedId), category: category, name: name)
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
            context.insert(p)
        }
    }

    // MARK: - Admission rates

    private static func importAdmissionRates(_ root: [String: Any], into context: ModelContext) {
        guard let items = root["items"] as? [[String: Any]] else { return }
        for item in items {
            guard let district = item["district"] as? String,
                  let year = item["year"] as? Int
            else { continue }
            let seedKey = "adm_\(district)_\(year)"
            let r = AdmissionRate(id: uuid(from: seedKey), district: district, year: year)
            r.gaokaoAdmitPct = (item["gaokao_admit_pct"] as? Int) ?? 0
            r.vocationalAdmitPct = (item["vocational_admit_pct"] as? Int) ?? 0
            r.sourceCode = item["source"] as? String
            context.insert(r)
        }
    }

    // MARK: - Compound-school matches

    private static func importCompoundSchoolMatches(_ root: [String: Any], into context: ModelContext) {
        guard let items = root["items"] as? [[String: Any]] else { return }
        for item in items {
            guard let cid = item["compound_id"] as? String,
                  let cname = item["compound_name"] as? String,
                  let district = item["district"] as? String
            else { continue }
            let m = CompoundSchoolMatch(
                id: uuid(from: "match_" + cid),
                compoundId: uuid(from: cid),
                compoundName: cname,
                district: district
            )
            m.mappedDistrict = item["mapped_district"] as? String
            m.primaryMatchesJSON = encodeIfPresent(item["primary_matches"]) ?? "[]"
            m.middleMatchesJSON = encodeIfPresent(item["middle_matches"]) ?? "[]"
            m.needsManualReview = (item["needs_manual_review"] as? Bool) ?? false
            context.insert(m)
        }
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
