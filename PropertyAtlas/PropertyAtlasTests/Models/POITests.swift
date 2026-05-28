import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct POITests {
    @Test func poiPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, POI.self])
        let ctx = ModelContext(container)
        let poi = POI(
            datasetId: UUID(),
            name: "营口道地铁站",
            latitude: 39.1234,
            longitude: 117.2010
        )
        poi.category = "地铁站"
        ctx.insert(poi)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<POI>())
        #expect(all.first?.name == "营口道地铁站")
        #expect(all.first?.category == "地铁站")
    }
}
