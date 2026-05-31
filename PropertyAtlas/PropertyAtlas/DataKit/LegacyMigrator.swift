import Foundation
import SwiftData

/// One-shot migration from legacy @Model (LegacyCompound / LegacySchool /
/// LegacySchoolZone / LegacyAdmissionDoc + still-named-old: BuiltinTag /
/// CompoundSchoolMatch / SchoolGroup / Policy / AdmissionRate / SchoolScore)
/// to new @Models (Models/Entities/*, Core/*, Style/*, Display/*, Schema/*, Media/*).
/// Idempotent — safe to call multiple times.
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
        purge(FilterFieldConfig.self) { $0.datasetId }
        purge(EnumOption.self) { $0.datasetId }
        purge(CameraPreset.self) { $0.datasetId }
        purge(Edge.self) { $0.datasetId }
        purge(Tag.self) { $0.datasetId }
        purge(CustomFieldDef.self) { $0.datasetId }
    }

    static func run(in ctx: ModelContext) throws {
        if try !ctx.fetch(FetchDescriptor<Dataset>()).isEmpty { return }
        let hasLegacy: Bool = try (
            !ctx.fetch(FetchDescriptor<LegacyCompound>()).isEmpty
                || !ctx.fetch(FetchDescriptor<LegacySchool>()).isEmpty
                || !ctx.fetch(FetchDescriptor<LegacySchoolZone>()).isEmpty
        )
        if !hasLegacy { return }

        let dataset = Dataset(name: datasetName)
        dataset.id = stableDatasetId(name: datasetName)
        ctx.insert(dataset)
        try migrateAreas(dataset: dataset, in: ctx)
        try migrateSchools(dataset: dataset, in: ctx)
        try migrateCompounds(dataset: dataset, in: ctx)
        try migrateEdges(dataset: dataset, in: ctx)
        try seedEnumOptions(dataset: dataset, in: ctx)
        try seedFilterFields(dataset: dataset, in: ctx)
        try seedPalettesThemesLayers(dataset: dataset, in: ctx)
        try seedCameraPresets(dataset: dataset, in: ctx)
        try migrateAdmissionDocs(dataset: dataset, in: ctx)
        try migrateTags(dataset: dataset, in: ctx)
        try ctx.save()
    }

    // MARK: stage 2 — SchoolZone → Area

    private static func migrateAreas(dataset: Dataset, in ctx: ModelContext) throws {
        let zones = try ctx.fetch(FetchDescriptor<LegacySchoolZone>())
        for z in zones {
            let area = Area(
                datasetId: dataset.id,
                name: z.name,
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

    // MARK: stage 3 — LegacySchool → School

    private static func migrateSchools(dataset: Dataset, in ctx: ModelContext) throws {
        let legacySchools = try ctx.fetch(FetchDescriptor<LegacySchool>())
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
            s.primaryAreaId = ls.zoneId
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

    private static func migrateCompounds(dataset: Dataset, in ctx: ModelContext) throws {
        let legacy = try ctx.fetch(FetchDescriptor<LegacyCompound>())
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
            c.primaryAreaId = lc.zoneId
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

    private static func migrateEdges(dataset: Dataset, in ctx: ModelContext) throws {
        try migrateCompoundSchoolMatches(dataset: dataset, in: ctx)
        try migratePrimarySchoolId(dataset: dataset, in: ctx)
        try migrateZoneMiddleSchoolPool(dataset: dataset, in: ctx)
        try migrateSchoolGroups(dataset: dataset, in: ctx)
    }

    private static func migrateCompoundSchoolMatches(dataset: Dataset, in ctx: ModelContext) throws {
        let matches = try ctx.fetch(FetchDescriptor<CompoundSchoolMatch>())
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

    private static func migratePrimarySchoolId(dataset: Dataset, in ctx: ModelContext) throws {
        let compounds = try ctx.fetch(FetchDescriptor<LegacyCompound>())
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

    private static func migrateZoneMiddleSchoolPool(dataset: Dataset, in ctx: ModelContext) throws {
        let zones = try ctx.fetch(FetchDescriptor<LegacySchoolZone>())
        let allSchools = try ctx.fetch(FetchDescriptor<LegacySchool>())
        var schoolByName: [String: LegacySchool] = [:]
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

    private static func migrateSchoolGroups(dataset: Dataset, in ctx: ModelContext) throws {
        let groups = try ctx.fetch(FetchDescriptor<SchoolGroup>())
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
            ("area.category", ["行政区", "片区", "商圈", "管辖区"]),
            ("edge.label", ["对口小学", "片内中学", "周边", "集团成员", "集团领办", "管辖", "属于"]),
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

    // MARK: stage 7 — FilterFieldConfig seeds

    private static func seedFilterFields(dataset: Dataset, in ctx: ModelContext) throws {
        let seeds: [(entity: String, fields: [(key: String, label: String, source: String)])] = [
            ("compound", [
                ("finishType", "精装类型", "base"),
                ("isNewHouse", "新房/二手", "base"),
            ]),
            ("school", [
                ("category", "阶段", "base"),
                ("grade", "等级", "base"),
                ("form", "学制", "base"),
            ]),
            ("poi", [
                ("category", "POI 类型", "base"),
            ]),
            ("area", [
                ("category", "区域类型", "base"),
            ]),
        ]
        for (entity, fields) in seeds {
            for (idx, f) in fields.enumerated() {
                let c = FilterFieldConfig(
                    datasetId: dataset.id,
                    entityType: entity,
                    fieldKey: f.key,
                    fieldSource: f.source,
                    label: f.label,
                    slot: idx + 1
                )
                ctx.insert(c)
            }
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
        for (idx, p) in palettes.enumerated() {
            let palette = Palette(name: p.name, colorsHex: p.colors, builtIn: true)
            palette.sortOrder = idx
            ctx.insert(palette)
        }

        let defaultLayer = Layer(datasetId: dataset.id, name: "全部")
        defaultLayer.isDefault = true
        defaultLayer.enabled = true
        defaultLayer.dynamicQueryJSON = nil
        defaultLayer.sortOrder = 0
        ctx.insert(defaultLayer)

        let baseVisibility = #"{"compound":true,"school":true,"poi":true,"area":true}"#
        let onlyPOIAndArea = #"{"compound":false,"school":false,"poi":true,"area":true}"#
        let onlyCompound = #"{"compound":true,"school":false,"poi":false,"area":false}"#

        let t1 = Theme(datasetId: dataset.id, name: "字段总览")
        t1.visibilityJSON = baseVisibility
        t1.defaultEnabledLayerIds = [defaultLayer.id]
        t1.sortOrder = 0
        t1.isActive = true
        ctx.insert(t1)

        let t2 = Theme(datasetId: dataset.id, name: "学区视图")
        t2.visibilityJSON = baseVisibility
        t2.defaultEnabledLayerIds = [defaultLayer.id]
        t2.sortOrder = 1
        t2.copyTitle = "学区分布图"
        t2.copySubtitle = "2026 招生季"
        ctx.insert(t2)

        let t3 = Theme(datasetId: dataset.id, name: "商圈视图")
        t3.visibilityJSON = onlyPOIAndArea
        t3.defaultEnabledLayerIds = [defaultLayer.id]
        t3.sortOrder = 2
        ctx.insert(t3)

        let t4 = Theme(datasetId: dataset.id, name: "新房地图")
        t4.visibilityJSON = onlyCompound
        t4.defaultEnabledLayerIds = [defaultLayer.id]
        t4.sortOrder = 3
        ctx.insert(t4)

        dataset.activeThemeId = t1.id
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

    // MARK: stage 10 — LegacyAdmissionDoc → Document

    private static func migrateAdmissionDocs(dataset: Dataset, in ctx: ModelContext) throws {
        let docs = try ctx.fetch(FetchDescriptor<LegacyAdmissionDoc>())
        let areas = try ctx.fetch(FetchDescriptor<Area>())
        let fallback = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        for ld in docs {
            let owner = areas.first { $0.name.contains(ld.district) }?.id ?? fallback
            let d = Document(
                ownerEntityId: owner,
                ownerEntityType: "area",
                kind: "pdf",
                title: ld.title,
                url: ld.sourceUrl ?? ""
            )
            d.id = ld.id
            d.ocrText = ld.ocrText
            ctx.insert(d)
        }
    }

    // MARK: stage 11 — BuiltinTag → Tag

    private static func migrateTags(dataset: Dataset, in ctx: ModelContext) throws {
        let builtin = try ctx.fetch(FetchDescriptor<BuiltinTag>())
        for bt in builtin {
            let polarity = switch bt.polarity {
            case "正": "positive"
            case "负": "negative"
            default: "neutral"
            }
            let t = Tag(
                datasetId: dataset.id,
                category: bt.category,
                label: bt.label,
                polarity: polarity
            )
            t.id = bt.id
            t.sortOrder = bt.sortOrder
            ctx.insert(t)
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
