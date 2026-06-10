// PropertyAtlas/PropertyAtlasTests/Models/DatasetTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct DatasetTests {
    @Test func datasetPersistsAndFetches() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self])
        let ctx = ModelContext(container)
        let ds = Dataset(name: "天津 demo")
        ctx.insert(ds)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(all.count == 1)
        #expect(all.first?.name == "天津 demo")
        #expect(all.first?.deleted == false)
        #expect(all.first?.version == 1)
    }

    @Test func datasetActiveCameraPresetIdDefaultsNil() {
        let ds = Dataset(name: "x")
        #expect(ds.activeCameraPresetId == nil)
    }
}
