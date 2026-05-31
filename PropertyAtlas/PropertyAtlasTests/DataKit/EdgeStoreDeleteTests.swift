// PropertyAtlasTests/DataKit/EdgeStoreDeleteTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EdgeStoreDeleteTests {
    private func ctx() throws -> ModelContext {
        try ModelContext(TestContainer.makeInMemory(for: [Edge.self]))
    }

    @Test func removeEdgeSoftDeletes() throws {
        let context = try ctx()
        let ds = UUID()
        let a = EntityRef(id: UUID(), kind: .school)
        let b = EntityRef(id: UUID(), kind: .compound)
        _ = EdgeStore.add(datasetId: ds, from: a, to: b, label: "L", in: context)
        let group = try #require(EdgeStore.relations(of: a, datasetId: ds, in: context).first)
        EdgeStore.removeEdge(group.items[0].edgeId, in: context)
        #expect(EdgeStore.relations(of: a, datasetId: ds, in: context).isEmpty)
    }

    @Test func cascadeSoftDeleteForEntity() throws {
        let context = try ctx()
        let ds = UUID()
        let hub = EntityRef(id: UUID(), kind: .school)
        _ = EdgeStore.add(datasetId: ds, from: hub, to: EntityRef(id: UUID(), kind: .compound), label: "L1", in: context)
        _ = EdgeStore.add(datasetId: ds, from: EntityRef(id: UUID(), kind: .area), to: hub, label: "L2", in: context)
        EdgeStore.cascadeSoftDelete(entityId: hub.id, datasetId: ds, in: context)
        #expect(EdgeStore.relations(of: hub, datasetId: ds, in: context).isEmpty)
    }
}
