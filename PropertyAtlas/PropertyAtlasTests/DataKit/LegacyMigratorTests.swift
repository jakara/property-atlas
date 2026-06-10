import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LegacyMigratorTests {
    private func newCtx() throws -> ModelContext {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        return ModelContext(container)
    }

    @Test func migrateCreatesTianjinDemoDatasetWhenDataExists() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: UUID(), name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.count == 1)
        #expect(datasets.first?.name == "天津 demo")
    }

    @Test func migrateIsIdempotent() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: UUID(), name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)]
        try LegacyMigrator.run(seeds: b, in: ctx)
        try LegacyMigrator.run(seeds: b, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).count == 1)
    }

    @Test func migrateNoOpWhenEmptyBundleAndNoDataset() throws {
        let ctx = try newCtx()
        try LegacyMigrator.run(seeds: SeedBundle(), in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).isEmpty)
    }

    @Test func migrateConvertsSchoolsToNewSchools() throws {
        let ctx = try newCtx()
        var s = SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")
        s.type = "小学"
        s.tier = "重点"
        s.lat = 39.122
        s.lon = 117.193
        s.isMarketKey = true
        s.communitiesText = "静安社区..."
        s.foundedYear = 1954
        var b = SeedBundle()
        b.schools = [s]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let schools = try ctx.fetch(FetchDescriptor<School>())
        #expect(schools.count == 1)
        let sc = try #require(schools.first)
        #expect(sc.name == "鞍山道小学")
        #expect(sc.category == "小学")
        #expect(sc.grade == "重点")
        #expect(sc.form == "普通")
        #expect(sc.latitude == 39.122)
        #expect(sc.foundYear == 1954)
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>()).filter { $0.entityType == "school" }
        #expect(defs.contains { $0.key == "isMarketKey" })
    }

    @Test func migrateConvertsCompoundsToNewCompounds() throws {
        let ctx = try newCtx()
        var c = CompoundSeed(id: UUID(), name: "中海西派国印", district: "河北区", latitude: 39.155, longitude: 117.190)
        c.buildYear = 2022
        c.developer = "中海"
        c.propertyMgmt = "中海物业"
        c.propertyFeeCents = 580
        c.finishType = "毛坯/精装"
        c.deliveryTime = "现房"
        c.isNewHouse = true
        c.availableUnits = "10-50"
        c.areaSegments = "105,125"
        c.priceSegments = "现房105精装"
        c.sourceCode = "YH-XLSX"
        c.amapPoiId = "B0FFK1H7MQ"
        c.greeningRatio = 35.0
        c.sensitivePros = "现房, 即买即住"
        c.sensitiveCons = "价格高"
        var b = SeedBundle()
        b.compounds = [c]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let compounds = try ctx.fetch(FetchDescriptor<Compound>())
        #expect(compounds.count == 1)
        let cc = try #require(compounds.first)
        #expect(cc.name == "中海西派国印")
        #expect(cc.buildYear == 2022)
        #expect(cc.propertyFeeCents == 580)
        #expect(cc.finishType == "毛坯/精装")
        #expect(cc.privateNotes?.contains("现房") == true)
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>()).filter { $0.entityType == "compound" }
        #expect(defs.contains { $0.key == "sourceCode" })
        #expect(defs.contains { $0.key == "amapPoiId" })
        #expect(defs.contains { $0.key == "greeningRatio" })
    }

    @Test func migrateConvertsZonesToAreas() throws {
        let ctx = try newCtx()
        var z = ZoneSeed(
            id: UUID(), name: "第一学片", primaryDistrict: "和平区",
            geometry: #"{"type":"Polygon","coordinates":[[[117.1,39.1],[117.2,39.1],[117.2,39.2],[117.1,39.2],[117.1,39.1]]]}"#
        )
        z.tier = "重点"
        z.residencyYears = 3
        z.fillOpacity = 0.3
        z.textDescription = "包含...居委会"
        var b = SeedBundle()
        b.zones = [z]
        b.compounds = [CompoundSeed(id: UUID(), name: "dummy", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let areas = try ctx.fetch(FetchDescriptor<Area>())
        // 名称经 AreaNameFormatter 消歧:和平区 + 第一学片 → 和平一片
        let area = try #require(areas.first { $0.name == "和平一片" })
        #expect(area.geometryKind == "polygon")
        #expect(area.fillOpacity == 0.3)
        #expect(area.textDescription == "包含...居委会")
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
        #expect(defs.contains { $0.key == "residencyYears" })
        #expect(defs.contains { $0.key == "tier" })
    }

    @Test func migrateConvertsMatchToEdges() throws {
        let ctx = try newCtx()
        let cid = UUID()
        let sid = UUID()
        var sch = SchoolSeed(id: sid, name: "鞍山道小学", district: "和平区")
        sch.tier = "重点"
        sch.lat = 39.12
        sch.lon = 117.19
        var m = MatchSeed(id: UUID(), compoundId: cid, compoundName: "x", district: "和平区")
        m.primaryMatchesJSON = #"[{"school_id":"\#(sid.uuidString)","school_name":"鞍山道小学","match_kind":"name"}]"#
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: cid, name: "x", district: "和平区")]
        b.schools = [sch]
        b.matches = [m]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let primary = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "对口小学" }
        #expect(primary.count == 1)
        #expect(primary.first?.fromId == cid)
        #expect(primary.first?.toId == sid)
        #expect(primary.first?.directed == true)
    }

    @Test func migrateConvertsGroupToEdges() throws {
        let ctx = try newCtx()
        let leaderId = UUID()
        let memberId = UUID()
        var leader = SchoolSeed(id: leaderId, name: "实验中学", district: "和平区")
        leader.type = "初中"
        leader.lat = 39.1
        leader.lon = 117.2
        var member = SchoolSeed(id: memberId, name: "实验中学分校", district: "和平区")
        member.type = "初中"
        member.lat = 39.11
        member.lon = 117.21
        var g = GroupSeed(id: UUID(), name: "实验集团", district: "和平区")
        g.leadsJSON = #"[{"name":"实验中学","school_id":"\#(leaderId.uuidString)"}]"#
        g.membersJSON = #"[{"name":"实验中学分校","school_id":"\#(memberId.uuidString)"}]"#
        var b = SeedBundle()
        b.schools = [leader, member]
        b.groups = [g]
        b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let edges = try ctx.fetch(FetchDescriptor<Edge>())
        #expect(edges.contains { $0.label == "集团成员" && $0.fromId == leaderId && $0.toId == memberId })
    }

    @Test func migrateConvertsZonePoolToEdges() throws {
        let ctx = try newCtx()
        let mid = UUID()
        var middle = SchoolSeed(id: mid, name: "耀华中学", district: "和平区")
        middle.type = "初中"
        middle.tier = "重点"
        middle.lat = 39.12
        middle.lon = 117.19
        var z = ZoneSeed(
            id: UUID(), name: "第一学片", primaryDistrict: "和平区",
            geometry: #"{"type":"Polygon","coordinates":[[[117,39],[118,39],[118,40],[117,40],[117,39]]]}"#
        )
        z.tier = "重点"
        z.middleSchoolPoolJSON = #"["耀华中学"]"#
        var b = SeedBundle()
        b.schools = [middle]
        b.zones = [z]
        b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let pool = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "片内中学" && $0.fromType == "area" }
        #expect(pool.count == 1)
        #expect(pool.first?.toId == mid)
    }

    @Test func migratesPrimaryAreaToEdge() throws {
        let ctx = try newCtx()
        let zid = UUID()
        let cid = UUID()
        let sid = UUID()
        let z = ZoneSeed(id: zid, name: "和平一片区", primaryDistrict: "和平区", geometry: "")
        var c = CompoundSeed(id: cid, name: "测试小区", district: "和平区")
        c.zoneId = zid
        var s = SchoolSeed(id: sid, name: "测试小学", district: "和平区")
        s.zoneId = zid
        var b = SeedBundle()
        b.zones = [z]
        b.compounds = [c]
        b.schools = [s]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let edges = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "所属片区" }
        #expect(edges.contains { $0.fromId == cid && $0.toId == zid && $0.fromType == "compound" })
        #expect(edges.contains { $0.fromId == sid && $0.toId == zid && $0.fromType == "school" })
    }

    @Test func migrateSeedsDefaultEnumOptions() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
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

    @Test func migrateSeedsPalettesThemesAndLayer() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let names = try Set(ctx.fetch(FetchDescriptor<Palette>()).map(\.name))
        #expect(names.contains("default-rainbow"))
        #expect(names.contains("category-cool"))
        #expect(names.contains("category-warm"))
        #expect(names.contains("mono-blue"))
        let themes = try ctx.fetch(FetchDescriptor<Theme>())
        // 单活跃主题(逐图层 theme 延后):只 seed「字段总览」
        #expect(themes.contains { $0.name == "字段总览" })
        let layers = try ctx.fetch(FetchDescriptor<Layer>()).filter { !$0.deleted }
        #expect(Set(layers.map(\.name)) == ["楼盘", "学校", "POI", "行政区", "路网", "片区"])
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).first?.activeThemeId != nil)
    }

    @Test func migrateSeedsCameraPresets() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let presets = try ctx.fetch(FetchDescriptor<CameraPreset>())
        #expect(Set(presets.map(\.name)) == ["和平区", "河西区", "南开区", "河东区", "河北区", "红桥区"])
        let heping = try #require(presets.first { $0.name == "和平区" })
        #expect(heping.centerLat == 39.125)
        #expect(heping.distance == 12000)
    }

    @Test func datasetIdIsStableAcrossRuns() throws {
        func runOnce() throws -> UUID {
            let ctx = try newCtx()
            var b = SeedBundle()
            b.schools = [SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")]
            try LegacyMigrator.run(seeds: b, in: ctx)
            return try #require(try ctx.fetch(FetchDescriptor<Dataset>()).first).id
        }
        #expect(try runOnce() == runOnce())
    }

    @Test func seedsSchoolStyleRulesAndAttachesToThemes() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.schools = [SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let rules = try ctx.fetch(FetchDescriptor<StyleRule>()).filter { $0.entityType == "school" }
        #expect(rules.contains { $0.appliesGlyph == "重" })
        #expect(rules.contains { $0.appliesGlyph == "普" })
        let overview = try #require(try ctx.fetch(FetchDescriptor<Theme>()).first { $0.name == "字段总览" })
        #expect(!overview.styleRuleIds.isEmpty)
    }

    @Test func seedsSixDefaultLayers() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.schools = [SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let layers = try ctx.fetch(FetchDescriptor<Layer>()).filter { !$0.deleted }
        #expect(Set(layers.map(\.name)) == ["楼盘", "学校", "POI", "行政区", "路网", "片区"])
        // compound 图层带派生的普通过滤(图例 chip)。
        let compoundLayer = try #require(layers.first { $0.entityType == "compound" })
        let nfs = (try? JSONDecoder().decode([NormalFilter].self, from: Data(compoundLayer.normalFiltersJSON.utf8))) ?? []
        #expect(nfs.contains { $0.name == "精装类型" })
        // school 图层带「等级」chip。
        let schoolLayer = try #require(layers.first { $0.entityType == "school" })
        let schoolNfs = (try? JSONDecoder().decode([NormalFilter].self, from: Data(schoolLayer.normalFiltersJSON.utf8))) ?? []
        #expect(schoolNfs.contains { $0.name == "等级" })
    }
}
