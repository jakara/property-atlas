import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct OrphanCleanupTests {
    @Test func deletesEntitiesWithNoOwningDataset() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let live = Dataset(name: "live")
        ctx.insert(live)
        let orphanDsId = UUID()
        let good = School(datasetId: live.id, name: "好中学", latitude: 39.1, longitude: 117.2)
        let bad = School(datasetId: orphanDsId, name: "孤儿中学", latitude: 39.1, longitude: 117.2)
        ctx.insert(good)
        ctx.insert(bad)
        try ctx.save()

        LegacyMigrator.cleanupOrphans(in: ctx)
        try ctx.save()

        let schools = try ctx.fetch(FetchDescriptor<School>())
        #expect(schools.count == 1)
        #expect(schools.first?.name == "好中学")
    }
}
