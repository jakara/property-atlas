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

    static func run(in ctx: ModelContext) throws {
        if try !ctx.fetch(FetchDescriptor<Dataset>()).isEmpty { return }
        let hasLegacy: Bool = try (
            !ctx.fetch(FetchDescriptor<LegacyCompound>()).isEmpty
                || !ctx.fetch(FetchDescriptor<LegacySchool>()).isEmpty
                || !ctx.fetch(FetchDescriptor<LegacySchoolZone>()).isEmpty
        )
        if !hasLegacy { return }

        let dataset = Dataset(name: datasetName)
        ctx.insert(dataset)
        try migrateAreas(dataset: dataset, in: ctx)
        try migrateSchools(dataset: dataset, in: ctx)
        try migrateCompounds(dataset: dataset, in: ctx)
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
