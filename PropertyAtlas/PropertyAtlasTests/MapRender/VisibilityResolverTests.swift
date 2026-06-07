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
        let pf = PrimaryFilter(
            conditions: [], groupBy: MapDimension(kind: .field, fieldKey: "grade"), entityType: "school"
        )
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

    /// 跨实体 OR:主过滤器条件只约束所选实体类型,其他类型不受影响、照常显示。
    @Test func primaryConditionScopedToItsEntityType() {
        let school1 = UUID(), school2 = UUID(), compound = UUID()
        let cands = [
            item(school1, "school", ["grade": .string("重点")]),
            item(school2, "school", ["grade": .string("普通")]),
            item(compound, "compound", ["finishType": .string("精装")]),
        ]
        let pf = PrimaryFilter(
            conditions: [FilterCondition(
                dimension: MapDimension(kind: .field, fieldKey: "grade"), op: .equals, value: .string("重点")
            )],
            groupBy: nil, entityType: "school"
        )
        let visible = VisibilityResolver.visibleIds(
            candidates: cands, layerVisible: Set([school1, school2, compound]),
            primary: pf, normals: [], filterState: DimensionFilterState(), context: nil, datasetId: nil
        )
        // school2 fails 重点 → hidden;school1 passes;compound 不受 school 过滤约束 → visible
        #expect(visible == Set([school1, compound]))
    }

    /// 普通过滤器 chip 隐藏只作用于其绑定的实体类型。
    @Test func normalChipScopedToEntityType() {
        let school = UUID(), compound = UUID()
        let cands = [
            item(school, "school", ["grade": .string("普通")]),
            item(compound, "compound", ["grade": .string("普通")]),
        ]
        let gradeDim = MapDimension(kind: .field, fieldKey: "grade")
        let nf = NormalFilter(name: "等级", dimension: gradeDim, entityType: "school")
        let fs = DimensionFilterState()
        fs.toggle(dimensionKey: gradeDim.key, value: "普通")
        let visible = VisibilityResolver.visibleIds(
            candidates: cands, layerVisible: Set([school, compound]),
            primary: PrimaryFilter(conditions: [], groupBy: nil), normals: [nf],
            filterState: fs, context: nil, datasetId: nil
        )
        // school 被自己的 chip 隐藏;compound 同样 grade=普通 但该 normal 是 school-scoped → visible
        #expect(visible == Set([compound]))
    }
}
