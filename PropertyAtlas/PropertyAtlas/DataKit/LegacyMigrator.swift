import Foundation
import SwiftData

/// Seed importer: writes new @Models (Models/Entities/*, Core/*, Style/*,
/// Display/*, Schema/*, Media/*) from an in-memory `SeedBundle` of `*Seed`
/// DTOs (decoded from bundled JSON by SeedImporter). One-shot per dataset —
/// idempotent (skips when a Dataset already exists).
@MainActor
enum LegacyMigrator {
    static let datasetName = "天津 demo"

    /// 稳定 datasetId:同 datasetName 永远派生同一 UUID,避免重跑孤立旧实体。
    static func stableDatasetId(name: String) -> UUID {
        SeedImporter.uuid(from: "dataset:" + name)
    }

    /// 删除 datasetId 不指向任何现存 Dataset 的残留实体(开发期多版迁移遗留)。
    /// 每次启动调用,独立于 run() 的 "Dataset 已存在则跳过" 守卫。硬删(无 CloudKit 顾虑)。
    static func cleanupOrphans(in ctx: ModelContext) {
        let validIds = Set((try? ctx.fetch(FetchDescriptor<Dataset>()))?.map(\.id) ?? [])
        func purge<T: PersistentModel>(_ type: T.Type, _ dsId: (T) -> UUID) {
            let all = (try? ctx.fetch(FetchDescriptor<T>())) ?? []
            for e in all where !validIds.contains(dsId(e)) {
                ctx.delete(e)
            }
        }
        purge(School.self) { $0.datasetId }
        purge(Compound.self) { $0.datasetId }
        purge(POI.self) { $0.datasetId }
        purge(Area.self) { $0.datasetId }
        purge(Theme.self) { $0.datasetId }
        purge(StyleRule.self) { $0.datasetId }
        purge(Layer.self) { $0.datasetId }
        purge(EnumOption.self) { $0.datasetId }
        purge(CameraPreset.self) { $0.datasetId }
        purge(Edge.self) { $0.datasetId }
        purge(Tag.self) { $0.datasetId }
        purge(CustomFieldDef.self) { $0.datasetId }
    }

    /// 把 layerId == nil 的实体补设为本 dataset 的【默认】图层。幂等,每次启动可调。
    static func backfillLayerIds(in ctx: ModelContext) {
        let datasets = (try? ctx.fetch(FetchDescriptor<Dataset>())) ?? []
        let layers = (try? ctx.fetch(FetchDescriptor<Layer>())) ?? []
        for ds in datasets {
            // 兜底目标与 RootView.defaultLayerId 一致:isDefault 优先,否则 zIndex 最小的图层
            let dsLayers = layers.filter { $0.datasetId == ds.id && !$0.deleted }
            let homeLayer = dsLayers.first(where: { $0.isDefault })
                ?? dsLayers.sorted { $0.zIndex < $1.zIndex }.first
            // 旧库追溯改名:默认图层早期 seed 叫「全部」,现统一「默认」(幂等)。
            if let homeLayer, homeLayer.name == "全部" {
                homeLayer.name = "默认"
                homeLayer.updatedAt = Date()
            }
            guard let home = homeLayer?.id else { continue }
            assignNilToDefault(Compound.self, ds.id, home, ctx)
            assignNilToDefault(School.self, ds.id, home, ctx)
            assignNilToDefault(POI.self, ds.id, home, ctx)
            assignNilToDefault(Area.self, ds.id, home, ctx)
        }
    }

    private static func assignNilToDefault<T: PersistentModel & LayerAssignable>(
        _ type: T.Type, _ dsId: UUID, _ home: UUID, _ ctx: ModelContext
    ) {
        let all = (try? ctx.fetch(FetchDescriptor<T>())) ?? []
        for e in all where e.datasetId == dsId && e.layerId == nil && !e.deleted {
            e.layerId = home
        }
    }

    static func run(seeds: SeedBundle, in ctx: ModelContext) throws {
        if try !ctx.fetch(FetchDescriptor<Dataset>()).isEmpty { return }
        let hasData = !seeds.zones.isEmpty || !seeds.schools.isEmpty || !seeds.compounds.isEmpty
        if !hasData { return }

        let dataset = Dataset(name: datasetName)
        dataset.id = stableDatasetId(name: datasetName)
        ctx.insert(dataset)
        try migrateAreas(seeds.zones, dataset: dataset, in: ctx)
        try migrateSchools(seeds.schools, dataset: dataset, in: ctx)
        try migrateCompounds(seeds.compounds, dataset: dataset, in: ctx)
        try migrateEdges(seeds, dataset: dataset, in: ctx)
        try seedEnumOptions(dataset: dataset, in: ctx)
        try seedPalettesThemesLayers(dataset: dataset, in: ctx)
        try seedCameraPresets(dataset: dataset, in: ctx)
        try ctx.save()
    }

    // MARK: stage 2 — SchoolZone → Area

    private static func migrateAreas(_ zones: [ZoneSeed], dataset: Dataset, in ctx: ModelContext) throws {
        for z in zones {
            let area = Area(
                datasetId: dataset.id,
                name: AreaNameFormatter.displayName(district: z.primaryDistrict, zoneName: z.name),
                geometryKind: z.geometryStage == "raster" ? "raster" : "polygon",
                geometryJSON: z.geometry
            )
            area.id = z.id // preserve id for edges
            area.fillOpacity = z.fillOpacity
            area.textDescription = z.textDescription
            area.strokeHex = z.strokeColorHex
            // sensitive → privateNotes
            let sensitive = [z.sensitiveHighlight, z.sensitiveSource, z.sensitiveNote]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            area.privateNotes = sensitive.isEmpty ? nil : sensitive

            // Migrate stripped baseFields → customField
            var customFields: [String: AnyJSON] = [:]
            if let y = z.residencyYears {
                customFields["residencyYears"] = .int(y)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "area",
                    key: "residencyYears",
                    label: "居住年限",
                    type: "int",
                    unit: "年",
                    in: ctx
                )
            }
            if !z.tier.isEmpty, z.tier != "普通" {
                customFields["tier"] = .string(z.tier)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "area",
                    key: "tier",
                    label: "学片级别",
                    type: "string",
                    unit: nil,
                    in: ctx
                )
            }
            if !customFields.isEmpty {
                area.customFieldsJSON = try? JSONHelpers.encode(customFields)
            }
            ctx.insert(area)
        }
    }

    /// 幂等改名:对已迁移的库,按 area.id 关联回 seed zone 取 district,重写 Area.name 为显示名。
    /// 由 dataset.areaNamesNormalizedV1 闸门保证只跑一次。新库走 migrateAreas 已直接写显示名。
    static func normalizeAreaNames(zones: [ZoneSeed], dataset: Dataset, in ctx: ModelContext) {
        guard !dataset.areaNamesNormalizedV1 else { return }
        let byId = Dictionary(zones.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let dsId = dataset.id
        let areas = (try? ctx.fetch(FetchDescriptor<Area>(
            predicate: #Predicate { $0.datasetId == dsId }
        ))) ?? []
        for a in areas {
            guard let z = byId[a.id] else { continue }
            let newName = AreaNameFormatter.displayName(district: z.primaryDistrict, zoneName: z.name)
            if a.name != newName {
                a.name = newName
                a.updatedAt = Date()
            }
        }
        dataset.areaNamesNormalizedV1 = true
    }

    /// NormalFilter 已无 entityType(图层中心化重构后类型由所属图层定),此回填作废 → no-op。
    static func migrateFilterEntityTypes(dataset: Dataset, in ctx: ModelContext) {
        dataset.filterEntityTypeMigratedV1 = true
    }

    /// 纯逻辑:按过滤器名 / 字段 key 推断实体类型(category 跨类型歧义 → nil)。
    static func inferEntityType(name: String, dimension: MapDimension) -> String? {
        let byName: [String: String] = [
            "精装类型": "compound", "阶段": "school", "POI 类型": "poi", "POI类型": "poi",
            "区域类型": "area", "等级": "school", "新房/二手": "compound", "学制": "school",
        ]
        if let t = byName[name] { return t }
        if dimension.kind == .field, let k = dimension.fieldKey {
            let byKey: [String: String] = [
                "finishType": "compound", "isNewHouse": "compound", "deliveryTime": "compound",
                "developer": "compound", "propertyMgmt": "compound", "buildYear": "compound",
                "areaSegments": "compound", "priceSegments": "compound",
                "grade": "school", "form": "school", "capacity": "school", "communitiesText": "school",
                "textDescription": "area",
            ]
            return byKey[k]
        }
        return nil
    }

    // MARK: stage 3 — LegacySchool → School

    private static func migrateSchools(_ legacySchools: [SchoolSeed], dataset: Dataset, in ctx: ModelContext) throws {
        for ls in legacySchools {
            let s = School(
                datasetId: dataset.id,
                name: ls.name,
                latitude: ls.lat ?? 0,
                longitude: ls.lon ?? 0
            )
            s.id = ls.id
            s.category = ls.type.isEmpty ? nil : ls.type
            s.grade = ls.tier.isEmpty ? nil : ls.tier
            s.form = ls.is12Year ? "十二年制" : (ls.isJiunian ? "九年一贯" : "普通")
            s.address = ls.address
            s.phone = ls.phone
            s.communitiesText = ls.communitiesText
            s.foundYear = ls.foundedYear
            s.motto = ls.motto
            s.websiteUrl = ls.websiteUrl
            s.sourceUrl = ls.sourceUrl

            // sensitive → privateNotes
            let sensParts: [String] = [
                ls.sensitiveTierLabel.map { "tierLabel: \($0)" },
                ls.sensitiveComment,
                ls.sensitiveNote,
                ls.sensitiveSource.map { "source: \($0)" },
            ].compactMap { $0 }.filter { !$0.isEmpty }
            s.privateNotes = sensParts.isEmpty ? nil : sensParts.joined(separator: "\n")

            // customField migration
            var custom: [String: AnyJSON] = [:]
            if ls.isMarketKey {
                custom["isMarketKey"] = .bool(true)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "school",
                    key: "isMarketKey",
                    label: "市重点",
                    type: "bool",
                    unit: nil,
                    in: ctx
                )
            }
            if ls.isMarketFive {
                custom["isMarketFive"] = .bool(true)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "school",
                    key: "isMarketFive",
                    label: "市五所",
                    type: "bool",
                    unit: nil,
                    in: ctx
                )
            }
            if let c = ls.campuses, !c.isEmpty {
                custom["campuses"] = .string(c)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "school",
                    key: "campuses",
                    label: "分校",
                    type: "multiline",
                    unit: nil,
                    in: ctx
                )
            }
            if let t = ls.tuition, !t.isEmpty {
                custom["tuition"] = .string(t)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "school",
                    key: "tuition",
                    label: "学费",
                    type: "string",
                    unit: nil,
                    in: ctx
                )
            }
            if let src = ls.sourceCode, !src.isEmpty {
                custom["sourceCode"] = .string(src)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "school",
                    key: "sourceCode",
                    label: "信源",
                    type: "string",
                    unit: nil,
                    in: ctx
                )
            }
            if !custom.isEmpty {
                s.customFieldsJSON = try? JSONHelpers.encode(custom)
            }

            ctx.insert(s)
        }
    }

    // MARK: stage 4 — LegacyCompound → Compound

    private static func migrateCompounds(_ legacy: [CompoundSeed], dataset: Dataset, in ctx: ModelContext) throws {
        for lc in legacy {
            let c = Compound(
                datasetId: dataset.id,
                name: lc.name,
                latitude: lc.latitude,
                longitude: lc.longitude
            )
            c.id = lc.id
            c.aliases = lc.aliases
            c.address = lc.address
            c.buildYear = lc.buildYear
            c.developer = lc.developer
            c.propertyMgmt = lc.propertyMgmt
            c.propertyFeeCents = lc.propertyFeeCents
            c.landYears = lc.landYears
            c.finishType = lc.finishType
            c.deliveryTime = lc.deliveryTime
            c.isNewHouse = lc.isNewHouse
            c.availableUnits = lc.availableUnits
            c.areaSegments = lc.areaSegments
            c.priceSegments = lc.priceSegments
            c.sourceUrl = lc.sourceUrl

            // sensitive → privateNotes
            let parts: [String] = [
                lc.sensitivePros.map { "Pros: \($0)" },
                lc.sensitiveCons.map { "Cons: \($0)" },
                lc.sensitiveSource.map { "Source: \($0)" },
                lc.sensitiveNote,
            ].compactMap { $0 }.filter { !$0.isEmpty }
            c.privateNotes = parts.isEmpty ? nil : parts.joined(separator: "\n")

            // customField migration
            var custom: [String: AnyJSON] = [:]
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "sourceCode", label: "信源", type: "string", value: lc.sourceCode, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "sourceRow", label: "信源行", type: "int", value: lc.sourceRow, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "amapPoiId", label: "高德 POI ID", type: "string", value: lc.amapPoiId, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "contributedBy", label: "贡献者", type: "string", value: lc.contributedBy, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "verifiedAt", label: "核实时间", type: "date", value: lc.verifiedAt, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "totalBuildings", label: "栋数", type: "int", value: lc.totalBuildings, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "greeningRatio", label: "绿化率", type: "double", value: lc.greeningRatio, ctx: ctx, unit: "%")
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "parkingRatio", label: "车位比", type: "double", value: lc.parkingRatio, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "districtGroup", label: "区组", type: "string", value: lc.districtGroup, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "streetBlock", label: "街区", type: "string", value: lc.streetBlock, ctx: ctx)
            addCustom(&custom, dataset: dataset.id, entity: "compound", key: "district", label: "行政区", type: "string", value: lc.district.isEmpty ? nil : lc.district, ctx: ctx)
            if !custom.isEmpty {
                c.customFieldsJSON = try? JSONHelpers.encode(custom)
            }
            ctx.insert(c)
        }
    }

    private static func addCustom(
        _ dict: inout [String: AnyJSON],
        dataset: UUID,
        entity: String,
        key: String,
        label: String,
        type: String,
        value: (some Any)?,
        ctx: ModelContext,
        unit: String? = nil
    ) {
        guard let v = value else { return }
        let json: AnyJSON
        switch v {
        case let s as String:
            if s.isEmpty { return }
            json = .string(s)
        case let i as Int:
            json = .int(i)
        case let d as Double:
            json = .double(d)
        case let b as Bool:
            json = .bool(b)
        case let date as Date:
            json = .string(ISO8601DateFormatter().string(from: date))
        default:
            return
        }
        dict[key] = json
        registerCustomFieldDef(datasetId: dataset, entityType: entity, key: key, label: label, type: type, unit: unit, in: ctx)
    }

    // MARK: stage 5 — Edges

    private struct MatchEntry: Decodable {
        let school_id: String
        let school_name: String?
    }

    private struct GroupEntry: Decodable {
        let name: String
        let school_id: String?
    }

    private static func migrateEdges(_ seeds: SeedBundle, dataset: Dataset, in ctx: ModelContext) throws {
        try migrateCompoundSchoolMatches(seeds.matches, dataset: dataset, in: ctx)
        try migratePrimarySchoolId(seeds.compounds, dataset: dataset, in: ctx)
        try migrateZoneMiddleSchoolPool(seeds.zones, seeds.schools, dataset: dataset, in: ctx)
        try migrateSchoolGroups(seeds.groups, dataset: dataset, in: ctx)
        try migratePrimaryArea(seeds.compounds, seeds.schools, dataset: dataset, in: ctx)
    }

    private static func migratePrimaryArea(_ compounds: [CompoundSeed], _ schools: [SchoolSeed], dataset: Dataset, in ctx: ModelContext) throws {
        let dsId = dataset.id
        for lc in compounds {
            guard let to = lc.zoneId else { continue }
            ctx.insert(Edge(
                datasetId: dsId,
                fromId: lc.id,
                fromType: "compound",
                toId: to,
                toType: "area",
                label: "所属片区",
                directed: true
            ))
        }
        for ls in schools {
            guard let to = ls.zoneId else { continue }
            ctx.insert(Edge(
                datasetId: dsId,
                fromId: ls.id,
                fromType: "school",
                toId: to,
                toType: "area",
                label: "所属片区",
                directed: true
            ))
        }
    }

    private static func migrateCompoundSchoolMatches(_ matches: [MatchSeed], dataset: Dataset, in ctx: ModelContext) throws {
        for m in matches {
            let primary: [MatchEntry] = (try? JSONHelpers.decode(m.primaryMatchesJSON)) ?? []
            for entry in primary {
                guard let toId = UUID(uuidString: entry.school_id) else { continue }
                let e = Edge(
                    datasetId: dataset.id,
                    fromId: m.compoundId, fromType: "compound",
                    toId: toId, toType: "school",
                    label: "对口小学",
                    directed: true
                )
                ctx.insert(e)
            }
            let middle: [MatchEntry] = (try? JSONHelpers.decode(m.middleMatchesJSON)) ?? []
            for entry in middle {
                guard let toId = UUID(uuidString: entry.school_id) else { continue }
                let e = Edge(
                    datasetId: dataset.id,
                    fromId: m.compoundId, fromType: "compound",
                    toId: toId, toType: "school",
                    label: "片内中学",
                    directed: true
                )
                ctx.insert(e)
            }
        }
    }

    private static func migratePrimarySchoolId(_ compounds: [CompoundSeed], dataset: Dataset, in ctx: ModelContext) throws {
        for lc in compounds {
            guard let to = lc.primarySchoolId else { continue }
            // Skip if already emitted by CompoundSchoolMatch (avoid dup)
            let dsId = dataset.id
            let fromId = lc.id
            let descriptor = FetchDescriptor<Edge>(
                predicate: #Predicate { $0.fromId == fromId && $0.toId == to && $0.label == "对口小学" && $0.datasetId == dsId }
            )
            let existing = try? ctx.fetch(descriptor)
            if existing?.isEmpty == false { continue }
            let e = Edge(
                datasetId: dataset.id,
                fromId: lc.id, fromType: "compound",
                toId: to, toType: "school",
                label: "对口小学",
                directed: true
            )
            ctx.insert(e)
        }
    }

    private static func migrateZoneMiddleSchoolPool(_ zones: [ZoneSeed], _ allSchools: [SchoolSeed], dataset: Dataset, in ctx: ModelContext) throws {
        var schoolByName: [String: SchoolSeed] = [:]
        for s in allSchools {
            schoolByName[s.name] = s
        }
        for z in zones {
            guard let poolJSON = z.middleSchoolPoolJSON else { continue }
            let names: [String] = (try? JSONHelpers.decode(poolJSON)) ?? []
            for name in names {
                guard let school = schoolByName[name] else { continue }
                let e = Edge(
                    datasetId: dataset.id,
                    fromId: z.id, fromType: "area",
                    toId: school.id, toType: "school",
                    label: "片内中学",
                    directed: true
                )
                ctx.insert(e)
            }
        }
    }

    private static func migrateSchoolGroups(_ groups: [GroupSeed], dataset: Dataset, in ctx: ModelContext) throws {
        for g in groups {
            let leads: [GroupEntry] = (try? JSONHelpers.decode(g.leadsJSON)) ?? []
            let members: [GroupEntry] = (try? JSONHelpers.decode(g.membersJSON)) ?? []
            guard let leaderEntry = leads.first,
                  let leaderIdStr = leaderEntry.school_id,
                  let leaderId = UUID(uuidString: leaderIdStr)
            else { continue }
            for memberEntry in members {
                guard let memberIdStr = memberEntry.school_id,
                      let memberId = UUID(uuidString: memberIdStr),
                      memberId != leaderId
                else { continue }
                let e = Edge(
                    datasetId: dataset.id,
                    fromId: leaderId, fromType: "school",
                    toId: memberId, toType: "school",
                    label: "集团成员",
                    directed: true
                )
                e.note = g.name
                ctx.insert(e)
            }
        }
    }

    // MARK: stage 6 — EnumOption seeds

    private static func seedEnumOptions(dataset: Dataset, in ctx: ModelContext) throws {
        let seeds: [(scope: String, labels: [String])] = [
            ("school.category", ["小学", "初中", "九年一贯", "十二年制", "幼儿园", "职业"]),
            ("school.grade", ["重点", "区重点", "普通"]),
            ("school.form", ["普通", "九年一贯", "十二年制"]),
            ("compound.finishType", ["毛坯", "精装", "毛坯/精装"]),
            ("compound.deliveryTime", ["现房", "期房"]),
            ("poi.category", ["地铁站", "商场", "医院", "办事处", "学区办", "公交站", "景点"]),
            ("area.category", ["行政区", "片区", "学区", "道路", "街道", "商圈", "管辖区"]),
            ("edge.label", ["对口小学", "片内中学", "周边", "集团成员", "集团领办", "管辖", "属于", "所属片区"]),
        ]
        for (scope, labels) in seeds {
            for (idx, label) in labels.enumerated() {
                let opt = EnumOption(
                    datasetId: dataset.id,
                    scope: scope,
                    label: label,
                    sortOrder: idx
                )
                ctx.insert(opt)
            }
        }
    }

    /// 幂等补齐 area.category 枚举值(既有库无闸,按 scope+label 去重补缺)。新增 学区/道路/街道。
    static func ensureAreaCategoryOptions(dataset: Dataset, in ctx: ModelContext) {
        let dsId = dataset.id
        let scope = "area.category"
        let existing = ((try? ctx.fetch(FetchDescriptor<EnumOption>(
            predicate: #Predicate { $0.datasetId == dsId && $0.scope == scope && !$0.deleted }
        ))) ?? []).map(\.label)
        let want = ["学区", "道路", "街道"]
        var nextOrder = existing.count
        for label in want where !existing.contains(label) {
            ctx.insert(EnumOption(datasetId: dsId, scope: scope, label: label, sortOrder: nextOrder))
            nextOrder += 1
        }
    }

    // MARK: stage 8 — Palette + Theme + Layer seeds

    private static func seedPalettesThemesLayers(dataset: Dataset, in ctx: ModelContext) throws {
        let palettes: [(name: String, colors: [String])] = [
            ("default-rainbow", ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#5AC8FA", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E"]),
            ("category-cool", ["#5AC8FA", "#34C759", "#007AFF", "#5856D6", "#00C7BE", "#30B0C7"]),
            ("category-warm", ["#FF3B30", "#FF9500", "#FFCC00", "#FF2D55", "#FF6482", "#D02D7E"]),
            ("mono-blue", ["#E1F0FF", "#9CCBFB", "#4DA3F0", "#1B69D6"]),
        ]
        var defaultPalette: Palette?
        for (idx, p) in palettes.enumerated() {
            let palette = Palette(name: p.name, colorsHex: p.colors, builtIn: true)
            palette.sortOrder = idx
            ctx.insert(palette)
            if idx == 0 { defaultPalette = palette } // default-rainbow
        }

        let defaultLayer = Layer(datasetId: dataset.id, name: "默认")
        defaultLayer.isDefault = true
        defaultLayer.enabled = true
        defaultLayer.dynamicQueryJSON = nil
        defaultLayer.sortOrder = 0
        ctx.insert(defaultLayer)

        let baseVisibility = #"{"compound":true,"school":true,"poi":true,"area":true}"#
        let onlyPOIAndArea = #"{"compound":false,"school":false,"poi":true,"area":true}"#
        let onlyCompound = #"{"compound":true,"school":false,"poi":false,"area":false}"#

        let t1 = Theme(datasetId: dataset.id, name: "字段总览")
        t1.sortOrder = 0
        t1.isActive = true
        ctx.insert(t1)

        let t2 = Theme(datasetId: dataset.id, name: "学区视图")
        t2.sortOrder = 1
        ctx.insert(t2)

        let t3 = Theme(datasetId: dataset.id, name: "商圈视图")
        t3.sortOrder = 2
        ctx.insert(t3)

        let t4 = Theme(datasetId: dataset.id, name: "新房地图")
        t4.sortOrder = 3
        ctx.insert(t4)

        // P8b: per-view literals (formerly stored on Theme, now written
        // directly onto each MapView). Same order as themes [t1, t2, t3, t4].
        let viewSeeds: [ViewSeed] = [
            ViewSeed(visibilityJSON: baseVisibility),
            ViewSeed(visibilityJSON: baseVisibility, copyTitle: "学区分布图", copySubtitle: "2026 招生季"),
            ViewSeed(visibilityJSON: onlyPOIAndArea),
            ViewSeed(visibilityJSON: onlyCompound),
        ]

        // P5: 学校样式规则 — 名称标签 + 等级(grade)→ 重/普 glyph + tier 配色
        let schoolRuleIds = seedSchoolStyleRules(dataset: dataset, in: ctx)
        t1.styleRuleIds = schoolRuleIds // 挂进"字段总览"
        t2.styleRuleIds = schoolRuleIds // 挂进"学区视图"

        dataset.activeThemeId = t1.id

        // P8a: default layer zIndex + themeId (default layer → active theme)
        defaultLayer.zIndex = 0
        defaultLayer.themeId = t1.id

        // P8a: seed one MapView per theme (additive)
        try seedMapViews(
            dataset: dataset,
            defaultLayerId: defaultLayer.id,
            themes: [t1, t2, t3, t4],
            viewSeeds: viewSeeds,
            palette: defaultPalette,
            in: ctx
        )
    }

    /// P8b: per-view literal values that used to live on Theme. Carries the
    /// 9 former-global fields (minus defaultEnabledLayerIds, which is dropped
    /// because views already set enabledLayerIds = [defaultLayerId]).
    private struct ViewSeed {
        var cameraPresetId: UUID?
        var visibilityJSON: String
        var spotlightOnSelect: Bool = true
        var drawEdgeLines: [String] = []
        var bgMapStyle: String = "standard"
        var copyTitle: String?
        var copySubtitle: String?
        var copyWatermark: String?
    }

    /// P8a: seed one MapView per theme. normalFilters is a hardcoded list
    /// (P9b: formerly derived from per-field config rows); primaryFilter empty
    /// (no groupBy); paletteId = default palette; copy/camera/bg from theme.
    private static func seedMapViews(
        dataset: Dataset,
        defaultLayerId: UUID,
        themes: [Theme],
        viewSeeds: [ViewSeed],
        palette: Palette?,
        in ctx: ModelContext
    ) throws {
        let dsId = dataset.id
        // P9b: hardcoded NormalFilter list (formerly derived from per-field config
        // rows sorted by slot). Order is behavior-equivalent to the prior
        // slot-ascending derivation captured empirically before deletion.
        func fieldFilter(_ name: String, _ key: String) -> NormalFilter {
            NormalFilter(name: name, dimension: MapDimension(kind: .field, fieldKey: key, fieldSource: "base"))
        }
        let normals: [NormalFilter] = [
            fieldFilter("精装类型", "finishType"),
            fieldFilter("阶段", "category"),
            fieldFilter("POI 类型", "category"),
            fieldFilter("区域类型", "category"),
            fieldFilter("等级", "grade"),
            fieldFilter("新房/二手", "isNewHouse"),
            fieldFilter("学制", "form"),
        ]
        let normalsJSON = (try? JSONHelpers.encode(normals)) ?? "[]"
        let emptyPrimary = PrimaryFilter(conditions: [], groupBy: nil)
        let primaryJSON = (try? JSONHelpers.encode(emptyPrimary)) ?? #"{"conditions":[],"groupBy":null}"#

        for (idx, t) in themes.enumerated() {
            let seed = viewSeeds[idx]
            let v = MapView(datasetId: dsId, name: t.name)
            v.enabledLayerIds = [defaultLayerId]
            v.primaryFilterJSON = primaryJSON
            v.normalFiltersJSON = normalsJSON
            v.paletteId = palette?.id
            v.cameraPresetId = seed.cameraPresetId
            v.bgMapStyle = seed.bgMapStyle
            v.drawEdgeLines = seed.drawEdgeLines
            v.copyTitle = seed.copyTitle
            v.copySubtitle = seed.copySubtitle
            v.copyWatermark = seed.copyWatermark
            v.spotlightOnSelect = seed.spotlightOnSelect
            v.visibilityJSON = seed.visibilityJSON
            v.sortOrder = idx
            v.isActive = (idx == 0)
            ctx.insert(v)
        }
    }

    /// 学校样式:名称标签(低优先级) + grade → 重/普 glyph + tier 配色(高优先级)。
    private static func seedSchoolStyleRules(dataset: Dataset, in ctx: ModelContext) -> [UUID] {
        func schoolCond(_ value: String) -> String {
            let conds = [StyleCondition(field: "grade", op: .equals, value: .string(value))]
            return (try? JSONHelpers.encode(conds)) ?? "[]"
        }
        var ids: [UUID] = []

        let label = StyleRule(datasetId: dataset.id, name: "学校-显示名称", entityType: "school")
        label.priority = 0
        label.appliesShape = "square"
        label.appliesLabelVisible = true
        ctx.insert(label)
        ids.append(label.id)

        let tiers: [(grade: String, glyph: String)] = [
            ("重点", "重"),
            ("区重点", "重"),
            ("普通", "普"),
        ]
        let fills = ["#FF3B30", "#FF9500", "#8E8E93"]
        for (idx, tier) in tiers.enumerated() {
            let rule = StyleRule(datasetId: dataset.id, name: "学校-\(tier.grade)", entityType: "school")
            rule.priority = 10 + idx
            rule.conditionsJSON = schoolCond(tier.grade)
            rule.appliesGlyph = tier.glyph
            rule.appliesGlyphHex = "#FFFFFF"
            rule.appliesFillHex = fills[idx]
            rule.appliesLabelVisible = true
            ctx.insert(rule)
            ids.append(rule.id)
        }
        return ids
    }

    // MARK: stage 9 — CameraPreset seeds

    private static func seedCameraPresets(dataset: Dataset, in ctx: ModelContext) throws {
        let seeds: [(name: String, lat: Double, lon: Double, distance: Double)] = [
            ("和平区", 39.125, 117.205, 12000),
            ("河西区", 39.110, 117.225, 18000),
            ("南开区", 39.130, 117.150, 18000),
            ("河东区", 39.125, 117.235, 18000),
            ("河北区", 39.155, 117.205, 18000),
            ("红桥区", 39.165, 117.155, 18000),
        ]
        for (idx, s) in seeds.enumerated() {
            let p = CameraPreset(
                datasetId: dataset.id,
                name: s.name,
                centerLat: s.lat,
                centerLon: s.lon,
                distance: s.distance
            )
            p.sortOrder = idx
            ctx.insert(p)
        }
    }

    static func registerCustomFieldDef(
        datasetId: UUID,
        entityType: String,
        key: String,
        label: String,
        type: String,
        unit: String?,
        in ctx: ModelContext
    ) {
        let existing = try? ctx.fetch(FetchDescriptor<CustomFieldDef>(
            predicate: #Predicate { $0.datasetId == datasetId && $0.entityType == entityType && $0.key == key }
        ))
        if existing?.isEmpty == false { return }
        let def = CustomFieldDef(
            datasetId: datasetId,
            entityType: entityType,
            key: key,
            label: label,
            type: type,
            source: "migrated"
        )
        def.unit = unit
        ctx.insert(def)
    }
}
