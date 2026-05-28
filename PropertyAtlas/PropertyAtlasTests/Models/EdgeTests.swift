import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EdgeTests {
    @Test func edgePersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Edge.self])
        let ctx = ModelContext(container)
        let dsId = UUID()
        let edge = Edge(
            datasetId: dsId,
            fromId: UUID(), fromType: "compound",
            toId: UUID(), toType: "school",
            label: "对口小学",
            directed: true,
            note: "跨马路"
        )
        ctx.insert(edge)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Edge>())
        #expect(all.count == 1)
        #expect(all.first?.label == "对口小学")
        #expect(all.first?.directed == true)
        #expect(all.first?.note == "跨马路")
    }
}
