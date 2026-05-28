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
}
