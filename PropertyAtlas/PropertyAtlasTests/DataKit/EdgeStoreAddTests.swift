// PropertyAtlasTests/DataKit/EdgeStoreAddTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EdgeStoreAddTests {
    private func ctx() throws -> ModelContext {
        try ModelContext(TestContainer.makeInMemory(for: [Edge.self]))
    }

    @Test func addCreatesEdge() throws {
        let context = try ctx()
        let ds = UUID()
        let r = EdgeStore.add(
            datasetId: ds,
            from: EntityRef(id: UUID(), kind: .school),
            to: EntityRef(id: UUID(), kind: .compound),
            label: "周边",
            in: context
        )
        #expect(r == .added)
    }

    @Test func selfLinkRejected() throws {
        let context = try ctx()
        let x = UUID()
        let r = EdgeStore.add(
            datasetId: UUID(),
            from: EntityRef(id: x, kind: .school),
            to: EntityRef(id: x, kind: .school),
            label: "L",
            in: context
        )
        #expect(r == .rejectedSelfLink)
    }

    @Test func duplicateSkipped() throws {
        let context = try ctx()
        let ds = UUID()
        let a = EntityRef(id: UUID(), kind: .school)
        let b = EntityRef(id: UUID(), kind: .compound)
        _ = EdgeStore.add(datasetId: ds, from: a, to: b, label: "L", in: context)
        let second = EdgeStore.add(datasetId: ds, from: a, to: b, label: "L", in: context)
        #expect(second == .skippedDuplicate)
    }

    @Test func reverseDuplicateSkipped() throws {
        let context = try ctx()
        let ds = UUID()
        let a = EntityRef(id: UUID(), kind: .school)
        let b = EntityRef(id: UUID(), kind: .compound)
        _ = EdgeStore.add(datasetId: ds, from: a, to: b, label: "L", in: context)
        let rev = EdgeStore.add(datasetId: ds, from: b, to: a, label: "L", in: context)
        #expect(rev == .skippedDuplicate)
    }
}
