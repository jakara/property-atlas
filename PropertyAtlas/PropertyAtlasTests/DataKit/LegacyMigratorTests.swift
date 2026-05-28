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
}
