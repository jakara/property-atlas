import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct MapViewTests {
    @Test func persistsAndReadsBack() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let dsId = UUID()
        let v = MapView(datasetId: dsId, name: "学区视图")
        v.enabledLayerIds = [UUID()]
        v.primaryFilterJSON = #"{"conditions":[],"groupBy":null}"#
        v.normalFiltersJSON = "[]"
        v.isActive = true
        ctx.insert(v)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<MapView>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "学区视图")
        #expect(fetched.first?.enabledLayerIds.count == 1)
    }
}
