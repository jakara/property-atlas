import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct TagTests {
    @Test func tagPersists() throws {
        let container = try TestContainer.makeInMemory(for: [PropertyAtlas.Dataset.self, PropertyAtlas.Tag.self])
        let ctx = ModelContext(container)
        let dsId = UUID()
        let tag = PropertyAtlas.Tag(datasetId: dsId, category: "感受", label: "通风良好", polarity: "positive")
        ctx.insert(tag)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<PropertyAtlas.Tag>())
        #expect(all.count == 1)
        #expect(all.first?.category == "感受")
        #expect(all.first?.polarity == "positive")
    }
}
