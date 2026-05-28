import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct AreaTests {
    @Test func areaPersistsWithGeometry() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Area.self])
        let ctx = ModelContext(container)
        let a = Area(
            datasetId: UUID(),
            name: "第一学片",
            geometryKind: "polygon",
            geometryJSON: #"{"type":"Polygon","coordinates":[[[117.1,39.1],[117.2,39.1],[117.2,39.2],[117.1,39.2],[117.1,39.1]]]}"#
        )
        a.category = "片区"
        a.strokeHex = "#FF3B30"
        a.fillOpacity = 0.2
        ctx.insert(a)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Area>())
        #expect(all.first?.name == "第一学片")
        #expect(all.first?.geometryKind == "polygon")
        #expect(all.first?.fillOpacity == 0.2)
    }
}
