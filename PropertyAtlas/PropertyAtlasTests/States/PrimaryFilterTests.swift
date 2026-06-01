import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct PrimaryFilterTests {
    private func e(_ type: String, _ f: [String: AnyJSON] = [:]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: f, customFields: [:])
    }

    private func inp(_ s: StyleEntity, _ layers: [String] = []) -> MapDimension.Input {
        .init(entity: s, layerNames: layers, context: nil, datasetId: nil)
    }

    @Test func matchesAndsAllConditions() {
        let pf = PrimaryFilter(
            conditions: [
                FilterCondition(dimension: MapDimension(kind: .entityType), op: .inOp, value: .array([.string("school")])),
                FilterCondition(dimension: MapDimension(kind: .field, fieldKey: "grade"), op: .equals, value: .string("重点")),
            ],
            groupBy: MapDimension(kind: .field, fieldKey: "grade")
        )
        #expect(pf.matches(inp(e("school", ["grade": .string("重点")]))))
        #expect(!pf.matches(inp(e("school", ["grade": .string("普通")]))))
        #expect(!pf.matches(inp(e("compound", ["grade": .string("重点")]))))
    }

    @Test func groupValueFromGroupBy() {
        let pf = PrimaryFilter(conditions: [], groupBy: MapDimension(kind: .field, fieldKey: "grade"))
        #expect(pf.groupValues(inp(e("school", ["grade": .string("区重点")]))) == ["区重点"])
    }

    @Test func noGroupByYieldsEmpty() {
        let pf = PrimaryFilter(conditions: [], groupBy: nil)
        #expect(pf.groupValues(inp(e("school", ["grade": .string("重点")]))).isEmpty)
    }
}
