// PropertyAtlasTests/DataKit/EdgeStoreQueryTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EdgeStoreQueryTests {
    private func ctx() throws -> ModelContext {
        let c = try TestContainer.makeInMemory(for: [Edge.self])
        return ModelContext(c)
    }

    @Test func collectsBothDirectionsGroupedByLabel() throws {
        let context = try ctx()
        let ds = UUID()
        let school = UUID()
        let c1 = UUID()
        let c2 = UUID()
        context.insert(Edge(datasetId: ds, fromId: school, fromType: "school", toId: c1, toType: "compound", label: "周边小区"))
        context.insert(Edge(datasetId: ds, fromId: c2, fromType: "compound", toId: school, toType: "school", label: "周边小区"))
        let ref = EntityRef(id: school, kind: .school)
        let groups = EdgeStore.relations(of: ref, datasetId: ds, in: context)
        #expect(groups.count == 1)
        #expect(groups[0].label == "周边小区")
        #expect(groups[0].items.count == 2)
        let otherIds = Set(groups[0].items.map(\.other.id))
        #expect(otherIds == Set([c1, c2]))
    }

    @Test func skipsDeletedEdges() throws {
        let context = try ctx()
        let ds = UUID()
        let a = UUID()
        let b = UUID()
        let e = Edge(datasetId: ds, fromId: a, fromType: "school", toId: b, toType: "compound", label: "L")
        e.deleted = true
        context.insert(e)
        let groups = EdgeStore.relations(of: EntityRef(id: a, kind: .school), datasetId: ds, in: context)
        #expect(groups.isEmpty)
    }
}
