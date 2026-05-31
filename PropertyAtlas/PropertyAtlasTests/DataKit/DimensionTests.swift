import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct DimensionTests {
    private func entity(type: String, fields: [String: AnyJSON]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: fields, customFields: [:])
    }

    @Test func fieldDimensionResolvesValue() {
        let e = entity(type: "compound", fields: ["finishType": .string("精装")])
        let d = Dimension(kind: .field, fieldKey: "finishType")
        #expect(d.resolve(.init(entity: e, layerNames: [], context: nil, datasetId: nil)) == ["精装"])
    }

    @Test func entityTypeDimensionResolvesType() {
        let e = entity(type: "school", fields: [:])
        let d = Dimension(kind: .entityType)
        #expect(d.resolve(.init(entity: e, layerNames: [], context: nil, datasetId: nil)) == ["school"])
    }

    @Test func layerDimensionUsesProvidedNames() {
        let e = entity(type: "poi", fields: [:])
        let d = Dimension(kind: .layer)
        #expect(d.resolve(.init(entity: e, layerNames: ["商业", "教育"], context: nil, datasetId: nil)) == ["商业", "教育"])
    }

    @Test func fieldDimensionEmptyWhenMissing() {
        let e = entity(type: "compound", fields: [:])
        let d = Dimension(kind: .field, fieldKey: "finishType")
        #expect(d.resolve(.init(entity: e, layerNames: [], context: nil, datasetId: nil)).isEmpty)
    }
}
