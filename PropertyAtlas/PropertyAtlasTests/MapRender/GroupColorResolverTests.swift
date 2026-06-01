import Testing
import Foundation
import SwiftData
@testable import PropertyAtlas

@MainActor
struct GroupColorResolverTests {
    private func item(_ id: UUID, grade: String) -> GroupColorResolver.Item {
        GroupColorResolver.Item(
            id: id,
            entity: StyleEntity(entityType: "school", id: id, baseFields: ["grade": .string(grade)], customFields: [:]),
            layerNames: []
        )
    }

    @Test func nilGroupByYieldsEmpty() {
        let m = GroupColorResolver.colors(items: [item(UUID(), grade: "重点")], groupBy: nil,
            palette: ["#111111"], context: nil, datasetId: nil)
        #expect(m.isEmpty)
    }

    @Test func distinctGroupValuesGetDistinctColors() {
        let a = UUID(); let b = UUID()
        let dim = MapDimension(kind: .field, fieldKey: "grade", fieldSource: "base")
        let m = GroupColorResolver.colors(
            items: [item(a, grade: "重点"), item(b, grade: "普通")],
            groupBy: dim, palette: ["#E41A1C", "#377EB8"], context: nil, datasetId: nil)
        #expect(m[a] != nil && m[b] != nil)
        #expect(m[a] != m[b])
    }

    @Test func emptyPaletteYieldsEmpty() {
        let dim = MapDimension(kind: .field, fieldKey: "grade", fieldSource: "base")
        let m = GroupColorResolver.colors(items: [item(UUID(), grade: "重点")], groupBy: dim,
            palette: [], context: nil, datasetId: nil)
        #expect(m.isEmpty)
    }
}
