// PropertyAtlasTests/DataKit/EdgeStoreTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EdgeStoreTests {
    @Test func relatedFieldValuesProjectsAcrossEdge() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let dsId = UUID()
        let area = Area(datasetId: dsId, name: "和平一片区", geometryKind: "polygon", geometryJSON: "")
        ctx.insert(area)
        let c = Compound(datasetId: dsId, name: "测试小区", latitude: 39.1, longitude: 117.2)
        ctx.insert(c)
        ctx.insert(Edge(
            datasetId: dsId,
            fromId: c.id,
            fromType: "compound",
            toId: area.id,
            toType: "area",
            label: "所属片区",
            directed: true
        ))
        try ctx.save()

        let ref = EntityRef(id: c.id, kind: .compound)
        let names = EdgeStore.relatedFieldValues(of: ref, edgeLabel: "所属片区", direction: .downstream, targetField: nil, datasetId: dsId, in: ctx)
        #expect(names == ["和平一片区"])
        let none = EdgeStore.relatedFieldValues(of: ref, edgeLabel: "对口小学", direction: .downstream, targetField: nil, datasetId: dsId, in: ctx)
        #expect(none.isEmpty)
        // upstream from the area side gets the compound back
        let areaRef = EntityRef(id: area.id, kind: .area)
        let up = EdgeStore.relatedFieldValues(of: areaRef, edgeLabel: "所属片区", direction: .upstream, targetField: nil, datasetId: dsId, in: ctx)
        #expect(up == ["测试小区"])
    }
}
