import Testing
import Foundation
import SwiftData
@testable import PropertyAtlas

@MainActor
struct FieldKeyCatalogTests {
    @Test func baseFieldsForSchool() {
        let fields = FieldKeyCatalog.fields(entityType: "school", datasetId: UUID(), context: nil)
        #expect(fields.contains { $0.key == "category" })
    }
    @Test func enumValuesByScope() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let dsId = UUID()
        let o = EnumOption(datasetId: dsId, scope: "edge.label", label: "所属片区")
        ctx.insert(o); try ctx.save()
        let labels = FieldKeyCatalog.enumLabels(scope: "edge.label", datasetId: dsId, context: ctx)
        #expect(labels.contains("所属片区"))
    }
    @Test func unknownEntityTypeYieldsEmptyBase() {
        let fields = FieldKeyCatalog.fields(entityType: "bogus", datasetId: UUID(), context: nil)
        #expect(fields.isEmpty)
    }
}
