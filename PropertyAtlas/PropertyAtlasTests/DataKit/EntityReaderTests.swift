// PropertyAtlasTests/DataKit/EntityReaderTests.swift
import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EntityReaderTests {
    private func ctx() throws -> ModelContext {
        let c = try TestContainer.makeInMemory(for: [Compound.self, School.self, POI.self, Area.self])
        return ModelContext(c)
    }

    @Test func readsNameAndCoordinate() throws {
        let context = try ctx()
        let s = School(datasetId: UUID(), name: "鞍山道小学", latitude: 39.12, longitude: 117.19)
        context.insert(s)
        let ref = EntityRef(id: s.id, kind: .school)
        #expect(EntityReader.name(ref, in: context) == "鞍山道小学")
        let coord = EntityReader.coordinate(ref, in: context)
        #expect(coord?.latitude == 39.12)
    }

    @Test func readsBaseFieldValue() throws {
        let context = try ctx()
        let c = Compound(datasetId: UUID(), name: "X", latitude: 1, longitude: 2)
        c.finishType = "精装"
        c.isNewHouse = false
        context.insert(c)
        let ref = EntityRef(id: c.id, kind: .compound)
        #expect(EntityReader.value(ref, key: "finishType", in: context) == .string("精装"))
        #expect(EntityReader.value(ref, key: "isNewHouse", in: context) == .bool(false))
    }

    @Test func missingEntityReturnsNil() throws {
        let context = try ctx()
        let ref = EntityRef(id: UUID(), kind: .poi)
        #expect(EntityReader.name(ref, in: context) == nil)
    }
}
