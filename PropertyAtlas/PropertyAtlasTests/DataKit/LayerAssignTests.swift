import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerAssignTests {
    private func ctx() throws -> ModelContext {
        try ModelContext(TestContainer.makeInMemory(for: ModelSchema.allTypes))
    }

    private func mkLayer(_ c: ModelContext, _ ds: UUID, _ name: String, _ type: String, def: Bool, z: Int) -> Layer {
        let l = Layer(datasetId: ds, name: name, entityType: type)
        l.isDefault = def
        l.zIndex = z
        c.insert(l)
        return l
    }

    private func mkSchool(_ c: ModelContext, _ ds: UUID, _ name: String, grade: String?, layerId: UUID) -> School {
        let s = School(datasetId: ds, name: name, latitude: 0, longitude: 0)
        s.grade = grade
        s.layerId = layerId
        c.insert(s)
        return s
    }

    @Test func defaultLayerLookup() throws {
        let c = try ctx()
        let ds = UUID()
        _ = mkLayer(c, ds, "副", "school", def: false, z: 1)
        let d = mkLayer(c, ds, "默认", "school", def: true, z: 0)
        try c.save()
        #expect(LayerAssign.defaultLayer(entityType: "school", datasetId: ds, in: c)?.id == d.id)
        #expect(LayerAssign.defaultLayer(entityType: "poi", datasetId: ds, in: c) == nil)
    }

    @Test func bulkAssignByConditionMoves() throws {
        let c = try ctx()
        let ds = UUID()
        let def = mkLayer(c, ds, "学校", "school", def: true, z: 0)
        let key = mkLayer(c, ds, "重点", "school", def: false, z: 1)
        let s1 = mkSchool(c, ds, "A", grade: "重点", layerId: def.id)
        let s2 = mkSchool(c, ds, "B", grade: "普通", layerId: def.id)
        try c.save()
        let n = LayerAssign.bulkAssign(
            entityType: "school",
            conditions: [StyleCondition(field: "grade", op: .equals, value: .string("重点"))],
            toLayerId: key.id, datasetId: ds, in: c
        )
        #expect(n == 1)
        #expect(s1.layerId == key.id)
        #expect(s2.layerId == def.id)
    }

    @Test func previewCountNoMutate() throws {
        let c = try ctx()
        let ds = UUID()
        let def = mkLayer(c, ds, "学校", "school", def: true, z: 0)
        let s1 = mkSchool(c, ds, "A", grade: "重点", layerId: def.id)
        _ = mkSchool(c, ds, "B", grade: "普通", layerId: def.id)
        try c.save()
        let n = LayerAssign.previewCount(
            entityType: "school",
            conditions: [StyleCondition(field: "grade", op: .equals, value: .string("重点"))],
            datasetId: ds,
            in: c
        )
        #expect(n == 1)
        #expect(s1.layerId == def.id) // 未改
    }

    @Test func deleteLayerFallsBackToDefault() throws {
        let c = try ctx()
        let ds = UUID()
        let def = mkLayer(c, ds, "学校", "school", def: true, z: 0)
        let extra = mkLayer(c, ds, "重点", "school", def: false, z: 1)
        let s = mkSchool(c, ds, "A", grade: nil, layerId: extra.id)
        try c.save()
        let ok = LayerAssign.deleteLayer(extra, in: c)
        #expect(ok == true)
        #expect(extra.deleted == true)
        #expect(s.layerId == def.id)
    }

    @Test func cannotDeleteDefault() throws {
        let c = try ctx()
        let ds = UUID()
        let def = mkLayer(c, ds, "学校", "school", def: true, z: 0)
        try c.save()
        #expect(LayerAssign.deleteLayer(def, in: c) == false)
        #expect(def.deleted == false)
    }
}
