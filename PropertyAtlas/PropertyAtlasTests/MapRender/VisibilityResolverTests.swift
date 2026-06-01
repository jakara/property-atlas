import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct VisibilityResolverTests {
    private func item(_ id: UUID, _ type: String, _ f: [String: AnyJSON] = [:]) -> VisibilityResolver.Candidate {
        .init(id: id, entity: StyleEntity(entityType: type, id: id, baseFields: f, customFields: [:]), layerNames: [])
    }

    @Test func filtersByPrimaryConditionAndHidden() {
        let a = UUID(), b = UUID()
        let cands = [
            item(a, "school", ["grade": .string("重点")]),
            item(b, "school", ["grade": .string("普通")]),
        ]
        let pf = PrimaryFilter(conditions: [], groupBy: MapDimension(kind: .field, fieldKey: "grade"))
        let fs = DimensionFilterState()
        fs.toggle(dimensionKey: MapDimension(kind: .field, fieldKey: "grade").key, value: "普通")
        let visible = VisibilityResolver.visibleIds(
            candidates: cands, layerVisible: Set([a, b]),
            primary: pf, normals: [], filterState: fs, context: nil, datasetId: nil
        )
        #expect(visible == Set([a]))
    }

    @Test func excludedByLayerVisible() {
        let a = UUID()
        let cands = [item(a, "school")]
        let visible = VisibilityResolver.visibleIds(
            candidates: cands, layerVisible: Set(),
            primary: PrimaryFilter(conditions: [], groupBy: nil), normals: [],
            filterState: DimensionFilterState(), context: nil, datasetId: nil
        )
        #expect(visible.isEmpty)
    }
}
