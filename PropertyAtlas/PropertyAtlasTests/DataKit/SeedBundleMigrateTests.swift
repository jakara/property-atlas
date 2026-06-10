import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct SeedBundleMigrateTests {
    private func run(_ bundle: SeedBundle) throws -> ModelContext {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        try LegacyMigrator.run(seeds: bundle, in: ctx)
        return ctx
    }

    @Test("empty bundle creates no Dataset")
    func emptyNoOp() throws {
        let ctx = try run(SeedBundle())
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).isEmpty)
    }

    @Test("school seed → School + Dataset")
    func schoolMigrates() throws {
        var b = SeedBundle()
        var s = SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")
        s.type = "小学"
        s.tier = "重点"
        s.lat = 39.122
        s.lon = 117.193
        s.isMarketKey = true
        b.schools = [s]
        let ctx = try run(b)
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).count == 1)
        let schools = try ctx.fetch(FetchDescriptor<School>())
        #expect(schools.count == 1)
        #expect(schools.first?.grade == "重点")
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>()).filter { $0.entityType == "school" }
        #expect(defs.contains { $0.key == "isMarketKey" })
    }

    @Test("compound-school match seed → 对口小学 Edge")
    func matchMigrates() throws {
        var b = SeedBundle()
        let cid = UUID()
        let sid = UUID()
        b.compounds = [CompoundSeed(id: cid, name: "x", district: "和平区")]
        var sch = SchoolSeed(id: sid, name: "鞍山道小学", district: "和平区")
        sch.lat = 39.1
        sch.lon = 117.2
        b.schools = [sch]
        var m = MatchSeed(id: UUID(), compoundId: cid, compoundName: "x", district: "和平区")
        m.primaryMatchesJSON = #"[{"school_id":"\#(sid.uuidString)","school_name":"鞍山道小学"}]"#
        b.matches = [m]
        let ctx = try run(b)
        let primary = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "对口小学" }
        #expect(primary.count == 1)
        #expect(primary.first?.fromId == cid)
        #expect(primary.first?.toId == sid)
    }

    @Test("seeds 6 default Layers by name")
    func seedsLayers() throws {
        var b = SeedBundle()
        b.schools = [SchoolSeed(id: UUID(), name: "x", district: "和平区")]
        let ctx = try run(b)
        let layers = try ctx.fetch(FetchDescriptor<Layer>()).filter { !$0.deleted }
        let names = Set(layers.map(\.name))
        #expect(names == ["楼盘", "学校", "POI", "行政区", "路网", "片区"])
    }
}
