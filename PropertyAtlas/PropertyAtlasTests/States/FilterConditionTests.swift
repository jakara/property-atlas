import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct FilterConditionTests {
    private func entity(type: String, fields: [String: AnyJSON] = [:]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: fields, customFields: [:])
    }

    private func input(_ e: StyleEntity, layers: [String] = []) -> PropertyAtlas.Dimension.Input {
        .init(entity: e, layerNames: layers, context: nil, datasetId: nil)
    }

    @Test func equalsOnField() {
        let c = FilterCondition(dimension: Dimension(kind: .field, fieldKey: "grade"), op: .equals, value: .string("重点"))
        #expect(c.evaluate(input(entity(type: "school", fields: ["grade": .string("重点")]))))
        #expect(!c.evaluate(input(entity(type: "school", fields: ["grade": .string("普通")]))))
    }

    @Test func inOnEntityType() {
        let c = FilterCondition(dimension: Dimension(kind: .entityType), op: .inOp, value: .array([.string("school"), .string("poi")]))
        #expect(c.evaluate(input(entity(type: "poi"))))
        #expect(!c.evaluate(input(entity(type: "compound"))))
    }

    @Test func inOnLayerMultiValue() {
        let c = FilterCondition(dimension: Dimension(kind: .layer), op: .inOp, value: .array([.string("教育")]))
        #expect(c.evaluate(input(entity(type: "school"), layers: ["商业", "教育"])))
        #expect(!c.evaluate(input(entity(type: "school"), layers: ["商业"])))
    }
}
