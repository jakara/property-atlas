// PropertyAtlasTests/DataKit/EntityWriterTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EntityWriterTests {
    private func ctx() throws -> ModelContext {
        let c = try TestContainer.makeInMemory(for: [Compound.self, School.self, POI.self, Area.self])
        return ModelContext(c)
    }

    @Test func createsPinReturnsRef() throws {
        let context = try ctx()
        let ds = UUID()
        let ref = EntityWriter.createPin(
            kind: .compound,
            datasetId: ds,
            name: "新盘",
            latitude: 39.1,
            longitude: 117.2,
            layerId: nil,
            in: context
        )
        #expect(ref.kind == .compound)
        #expect(EntityReader.name(ref, in: context) == "新盘")
    }

    @Test func setsBaseFieldValue() throws {
        let context = try ctx()
        let ref = EntityWriter.createPin(
            kind: .school,
            datasetId: UUID(),
            name: "S",
            latitude: 1,
            longitude: 2,
            layerId: nil,
            in: context
        )
        EntityWriter.setValue(ref, key: "category", value: .string("小学"), in: context)
        #expect(EntityReader.value(ref, key: "category", in: context) == .string("小学"))
    }

    @Test func setsNameAndNotes() throws {
        let context = try ctx()
        let ref = EntityWriter.createPin(
            kind: .poi,
            datasetId: UUID(),
            name: "A",
            latitude: 1,
            longitude: 2,
            layerId: nil,
            in: context
        )
        EntityWriter.setName(ref, "B", in: context)
        EntityWriter.setPrivateNotes(ref, "内部备注", in: context)
        #expect(EntityReader.name(ref, in: context) == "B")
        #expect(EntityReader.notes(ref, in: context).privateNotes == "内部备注")
    }

    @Test func softDeleteMarksDeleted() throws {
        let context = try ctx()
        let ref = EntityWriter.createPin(
            kind: .poi,
            datasetId: UUID(),
            name: "A",
            latitude: 1,
            longitude: 2,
            layerId: nil,
            in: context
        )
        EntityWriter.softDelete(ref, in: context)
        let p = EntityReader.fetch(POI.self, ref.id, context)
        #expect(p?.deleted == true)
    }
}
