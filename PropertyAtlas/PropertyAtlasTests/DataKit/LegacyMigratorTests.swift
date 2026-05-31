import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LegacyMigratorTests {
    @Test func migrateCreatesTianjinDemoDatasetWhenLegacyDataExists() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.count == 1)
        #expect(datasets.first?.name == "天津 demo")
    }

    @Test func migrateIsIdempotent() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        try LegacyMigrator.run(in: ctx)
        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.count == 1)
    }

    @Test func migrateNoOpWhenNoLegacyDataAndNoExistingDataset() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        try LegacyMigrator.run(in: ctx)
        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.isEmpty)
    }

    @Test func migrateConvertsLegacySchoolsToNewSchools() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let ls = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
        ls.lat = 39.122
        ls.lon = 117.193
        ls.isJiunian = false
        ls.is12Year = false
        ls.isMarketKey = true
        ls.communitiesText = "静安社区..."
        ls.foundedYear = 1954
        ctx.insert(ls)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let schools = try ctx.fetch(FetchDescriptor<School>())
        #expect(schools.count == 1)
        let s = try #require(schools.first)
        #expect(s.name == "鞍山道小学")
        #expect(s.category == "小学")
        #expect(s.grade == "重点")
        #expect(s.form == "普通")
        #expect(s.latitude == 39.122)
        #expect(s.longitude == 117.193)
        #expect(s.foundYear == 1954)
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
            .filter { $0.entityType == "school" }
        #expect(defs.contains { $0.key == "isMarketKey" })
    }

    @Test func migrateConvertsLegacyCompoundsToNewCompounds() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "中海西派国印", district: "河北区", latitude: 39.155, longitude: 117.190)
        lc.buildYear = 2022
        lc.developer = "中海"
        lc.propertyMgmt = "中海物业"
        lc.propertyFeeCents = 580
        lc.finishType = "毛坯/精装"
        lc.deliveryTime = "现房"
        lc.isNewHouse = true
        lc.availableUnits = "10-50"
        lc.areaSegments = "105,125,洋房133停售"
        lc.priceSegments = "一期现房105精装400万左右"
        lc.sourceCode = "YH-XLSX"
        lc.amapPoiId = "B0FFK1H7MQ"
        lc.greeningRatio = 35.0
        lc.sensitivePros = "现房, 即买即住"
        lc.sensitiveCons = "价格高"
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let compounds = try ctx.fetch(FetchDescriptor<Compound>())
        #expect(compounds.count == 1)
        let c = try #require(compounds.first)
        #expect(c.name == "中海西派国印")
        #expect(c.latitude == 39.155)
        #expect(c.longitude == 117.190)
        #expect(c.buildYear == 2022)
        #expect(c.propertyFeeCents == 580)
        #expect(c.finishType == "毛坯/精装")
        #expect(c.isNewHouse == true)
        #expect(c.privateNotes?.contains("现房") == true)
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
            .filter { $0.entityType == "compound" }
        #expect(defs.contains { $0.key == "sourceCode" })
        #expect(defs.contains { $0.key == "amapPoiId" })
        #expect(defs.contains { $0.key == "greeningRatio" })
    }

    @Test func migrateConvertsSchoolZonesToAreas() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lz = LegacySchoolZone(
            name: "第一学片",
            tier: "重点",
            primaryDistrict: "和平区",
            geometry: #"{"type":"Polygon","coordinates":[[[117.1,39.1],[117.2,39.1],[117.2,39.2],[117.1,39.2],[117.1,39.1]]]}"#,
            geometryStage: "hull"
        )
        lz.residencyYears = 3
        lz.fillOpacity = 0.3
        lz.textDescription = "包含...居委会"
        ctx.insert(lz)
        // Trigger migration with a LegacyCompound (so hasLegacy is true)
        let lc = LegacyCompound(name: "dummy", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let areas = try ctx.fetch(FetchDescriptor<Area>())
        #expect(areas.contains { $0.name == "第一学片" })
        let area = try #require(areas.first { $0.name == "第一学片" })
        #expect(area.geometryKind == "polygon")
        #expect(area.fillOpacity == 0.3)
        #expect(area.textDescription == "包含...居委会")
        // residencyYears + tier migrated to customField
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
        #expect(defs.contains { $0.key == "residencyYears" })
        #expect(defs.contains { $0.key == "tier" })
    }

    @Test func migrateConvertsCompoundSchoolMatchToEdges() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        let ls = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
        ls.lat = 39.12
        ls.lon = 117.19
        let m = CompoundSchoolMatch(compoundId: lc.id, compoundName: "x", district: "和平区")
        m.primaryMatchesJSON = #"[{"school_id":"\#(ls.id.uuidString)","school_name":"鞍山道小学","match_kind":"name"}]"#
        m.middleMatchesJSON = "[]"
        ctx.insert(lc)
        ctx.insert(ls)
        ctx.insert(m)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let edges = try ctx.fetch(FetchDescriptor<Edge>())
        let primary = edges.filter { $0.label == "对口小学" }
        #expect(primary.count == 1)
        #expect(primary.first?.fromId == lc.id)
        #expect(primary.first?.fromType == "compound")
        #expect(primary.first?.toId == ls.id)
        #expect(primary.first?.toType == "school")
        #expect(primary.first?.directed == true)
    }

    @Test func migrateConvertsSchoolGroupToEdges() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let leader = LegacySchool(name: "实验中学", type: "初中", district: "和平区", tier: "重点")
        leader.lat = 39.1
        leader.lon = 117.2
        let member = LegacySchool(name: "实验中学分校", type: "初中", district: "和平区", tier: "区重点")
        member.lat = 39.11
        member.lon = 117.21
        let g = SchoolGroup(name: "实验集团", district: "和平区")
        g.leadsJSON = #"[{"name":"实验中学","school_id":"\#(leader.id.uuidString)"}]"#
        g.membersJSON = #"[{"name":"实验中学分校","school_id":"\#(member.id.uuidString)"}]"#
        ctx.insert(leader)
        ctx.insert(member)
        ctx.insert(g)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let edges = try ctx.fetch(FetchDescriptor<Edge>())
        #expect(edges.contains { $0.label == "集团成员" && $0.fromId == leader.id && $0.toId == member.id })
    }

    @Test func migrateConvertsZoneMiddleSchoolPoolToEdges() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let middle = LegacySchool(name: "耀华中学", type: "初中", district: "和平区", tier: "重点")
        middle.lat = 39.12
        middle.lon = 117.19
        ctx.insert(middle)
        let z = LegacySchoolZone(
            name: "第一学片",
            tier: "重点",
            primaryDistrict: "和平区",
            geometry: #"{"type":"Polygon","coordinates":[[[117,39],[118,39],[118,40],[117,40],[117,39]]]}"#,
            geometryStage: "hull"
        )
        z.middleSchoolPoolJSON = #"["耀华中学"]"#
        ctx.insert(z)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let edges = try ctx.fetch(FetchDescriptor<Edge>())
        let pool = edges.filter { $0.label == "片内中学" && $0.fromType == "area" }
        #expect(pool.count == 1)
        #expect(pool.first?.toType == "school")
        #expect(pool.first?.toId == middle.id)
    }

    @Test func migrateSeedsDefaultEnumOptions() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let enums = try ctx.fetch(FetchDescriptor<EnumOption>())
        let scopes = Set(enums.map(\.scope))
        #expect(scopes.contains("school.category"))
        #expect(scopes.contains("school.grade"))
        #expect(scopes.contains("school.form"))
        #expect(scopes.contains("edge.label"))
        #expect(scopes.contains("area.category"))
        let cat = enums.filter { $0.scope == "school.category" }.map(\.label)
        #expect(cat.contains("小学"))
        #expect(cat.contains("初中"))
    }

    @Test func migrateSeedsDefaultFilterFieldConfigs() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let configs = try ctx.fetch(FetchDescriptor<FilterFieldConfig>())
        let schoolSlots = configs.filter { $0.entityType == "school" }
            .sorted { $0.slot < $1.slot }
            .map(\.fieldKey)
        #expect(schoolSlots == ["category", "grade", "form"])
        let compoundSlots = configs.filter { $0.entityType == "compound" }
            .sorted { $0.slot < $1.slot }
            .map(\.fieldKey)
        #expect(compoundSlots == ["finishType", "isNewHouse"])
    }

    @Test func migrateSeedsPalettesThemesAndDefaultLayer() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)

        let palettes = try ctx.fetch(FetchDescriptor<Palette>())
        let names = Set(palettes.map(\.name))
        #expect(names.contains("default-rainbow"))
        #expect(names.contains("category-cool"))
        #expect(names.contains("category-warm"))
        #expect(names.contains("mono-blue"))

        let themes = try ctx.fetch(FetchDescriptor<Theme>())
        #expect(themes.contains { $0.name == "字段总览" })
        #expect(themes.contains { $0.name == "学区视图" })
        #expect(themes.contains { $0.name == "商圈视图" })
        #expect(themes.contains { $0.name == "新房地图" })

        let layers = try ctx.fetch(FetchDescriptor<Layer>())
        #expect(layers.contains { $0.isDefault && $0.name == "全部" })

        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.first?.activeThemeId != nil)
    }

    @Test func migrateMigratesHardcodedCameraPresets() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let presets = try ctx.fetch(FetchDescriptor<CameraPreset>())
        let names = Set(presets.map(\.name))
        #expect(names == ["和平区", "河西区", "南开区", "河东区", "河北区", "红桥区"])
        let heping = try #require(presets.first { $0.name == "和平区" })
        #expect(heping.centerLat == 39.125)
        #expect(heping.centerLon == 117.205)
        #expect(heping.distance == 12000)
    }

    @Test func migrateConvertsAdmissionDocsToDocuments() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let doc = LegacyAdmissionDoc(title: "2024 和平区招生简章", district: "和平区", year: 2024)
        doc.ocrText = "..."
        doc.sourceUrl = "https://example.com"
        ctx.insert(doc)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let documents = try ctx.fetch(FetchDescriptor<Document>())
        #expect(documents.count == 1)
        let d = try #require(documents.first)
        #expect(d.title == "2024 和平区招生简章")
        #expect(d.kind == "pdf")
        #expect(d.ocrText == "...")
    }

    @Test func migrateConvertsBuiltinTagsToTags() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let bt = BuiltinTag(category: "感受", label: "通风良好", polarity: "正")
        ctx.insert(bt)
        let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let tags = try ctx.fetch(FetchDescriptor<PropertyAtlas.Tag>())
        #expect(tags.count == 1)
        #expect(tags.first?.label == "通风良好")
        #expect(tags.first?.polarity == "positive")
    }

    @Test func datasetIdIsStableAcrossRuns() throws {
        // Run 1
        let container1 = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx1 = ModelContext(container1)
        let ls1 = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
        ctx1.insert(ls1)
        try ctx1.save()
        try LegacyMigrator.run(in: ctx1)
        let datasets1 = try ctx1.fetch(FetchDescriptor<Dataset>())
        let id1 = try #require(datasets1.first).id

        // Run 2 — separate in-memory container
        let container2 = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx2 = ModelContext(container2)
        let ls2 = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
        ctx2.insert(ls2)
        try ctx2.save()
        try LegacyMigrator.run(in: ctx2)
        let datasets2 = try ctx2.fetch(FetchDescriptor<Dataset>())
        let id2 = try #require(datasets2.first).id

        #expect(id1 == id2)
    }

    @Test func seedsSchoolStyleRulesAndAttachesToThemes() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let ls = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
        ctx.insert(ls)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)

        let schoolRules = try ctx.fetch(FetchDescriptor<StyleRule>())
            .filter { $0.entityType == "school" }
        #expect(!schoolRules.isEmpty)
        #expect(schoolRules.contains { $0.appliesLabelVisible == true })
        #expect(schoolRules.contains { $0.appliesGlyph == "重" })
        #expect(schoolRules.contains { $0.appliesGlyph == "普" })

        let themes = try ctx.fetch(FetchDescriptor<Theme>())
        let overview = try #require(themes.first { $0.name == "字段总览" })
        #expect(!overview.styleRuleIds.isEmpty)
        let ruleIds = Set(schoolRules.map(\.id))
        #expect(overview.styleRuleIds.contains { ruleIds.contains($0) })
    }
}
