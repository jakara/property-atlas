import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerResolverTests {
    private func makeContext() throws -> ModelContext {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        return ModelContext(container)
    }

    @discardableResult
    private func compound(_ ctx: ModelContext, name: String, finishType: String? = nil) -> Compound {
        let c = Compound(datasetId: UUID(), name: name, latitude: 0, longitude: 0)
        c.finishType = finishType
        ctx.insert(c)
        return c
    }

    private func layer(
        id: UUID = UUID(), type: String, zIndex: Int = 0, enabled: Bool = true,
        conditions: [FilterCondition] = [], normals: [NormalFilter] = [],
        groupBy: MapDimension? = nil, minZoom: Double? = nil, maxZoom: Double? = nil
    ) -> LayerResolver.ActiveLayer {
        LayerResolver.ActiveLayer(
            id: id, name: "L", entityType: type, zIndex: zIndex, enabled: enabled,
            minZoom: minZoom, maxZoom: maxZoom,
            primary: PrimaryFilter(conditions: conditions, groupBy: groupBy), normals: normals
        )
    }

    // MARK: - Existing tests (preserved)

    @Test func matchesByEntityTypeAndLayerId() throws {
        let ctx = try makeContext()
        let layerId = UUID()
        let c = compound(ctx, name: "A")
        c.layerId = layerId
        let layers = [layer(id: layerId, type: "compound"), layer(type: "school")]
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)], layers: layers, zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result[c.id] == layerId)
    }

    @Test func disabledLayerHidesEntity() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A")
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)],
            layers: [layer(type: "compound", enabled: false)], zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result.isEmpty)
    }

    @Test func primaryFilterGatesOwnedMembers() throws {
        let ctx = try makeContext()
        let layerId = UUID()
        let hardcover = compound(ctx, name: "精装盘", finishType: "精装")
        let bare = compound(ctx, name: "毛坯盘", finishType: "毛坯")
        // Both compounds belong to the same layer
        hardcover.layerId = layerId
        bare.layerId = layerId
        let cond = FilterCondition(
            dimension: MapDimension(kind: .field, fieldKey: "finishType", fieldSource: "base"),
            op: .equals, value: .string("精装")
        )
        let result = LayerResolver.resolve(
            candidates: [
                .init(id: hardcover.id, entity: hardcover.styleEntity),
                .init(id: bare.id, entity: bare.styleEntity),
            ],
            layers: [layer(id: layerId, type: "compound", conditions: [cond])], zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result[hardcover.id] == layerId)
        #expect(result[bare.id] == nil)
    }

    @Test func highestZIndexWinsOnOverlap() throws {
        let ctx = try makeContext()
        let high = UUID()
        let c = compound(ctx, name: "A")
        // Entity belongs to the high-zIndex layer; low layer doesn't own it
        c.layerId = high
        let low = UUID()
        let layers = [
            layer(id: low, type: "compound", zIndex: 1),
            layer(id: high, type: "compound", zIndex: 5),
        ]
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)], layers: layers, zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result[c.id] == high)
    }

    @Test func zoomOutOfRangeHides() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A")
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)],
            layers: [layer(type: "compound", minZoom: 14)], zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result.isEmpty)
    }

    @Test func hiddenChipNamespacedByLayer() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A", finishType: "精装")
        let layerId = UUID()
        let nf = NormalFilter(name: "精装类型", dimension: MapDimension(kind: .field, fieldKey: "finishType", fieldSource: "base"))
        let state = DimensionFilterState()
        state.toggle(dimensionKey: "\(layerId.uuidString)|field:finishType", value: "精装")
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)],
            layers: [layer(id: layerId, type: "compound", normals: [nf])], zoom: 12,
            filterState: state, context: ctx, datasetId: nil
        )
        #expect(result.isEmpty)
    }

    // MARK: - New tests: explicit layerId membership

    /// Helper: build a StyleEntity Candidate directly (no SwiftData model needed)
    private func se(_ id: UUID, type: String, layerId: UUID?, fields: [String: AnyJSON] = [:]) -> LayerResolver.Candidate {
        LayerResolver.Candidate(id: id, entity: StyleEntity(
            entityType: type, id: id, baseFields: fields, customFields: [:], layerId: layerId
        ))
    }

    /// Helper: build a simple ActiveLayer with a given id (used for layerId ownership tests)
    private func activeLayer(
        _ id: UUID, type: String, z: Int = 0,
        conditions: [FilterCondition] = []
    ) -> LayerResolver.ActiveLayer {
        LayerResolver.ActiveLayer(
            id: id, name: "L", entityType: type, zIndex: z, enabled: true,
            minZoom: nil, maxZoom: nil,
            primary: PrimaryFilter(conditions: conditions, groupBy: nil), normals: []
        )
    }

    /// Entity whose layerId matches the layer id is included; one with a different layerId is excluded.
    @Test func memberByLayerIdOnly() {
        let lid = UUID()
        let e1 = UUID()
        let e2 = UUID()
        let cands = [
            se(e1, type: "school", layerId: lid),
            se(e2, type: "school", layerId: UUID()), // different layerId
        ]
        let res = LayerResolver.resolve(
            candidates: cands, layers: [activeLayer(lid, type: "school")],
            zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil
        )
        #expect(res[e1] == lid)
        #expect(res[e2] == nil)
    }

    /// Even if the entity carries the layer's id, wrong entityType means no match.
    @Test func wrongTypeExcluded() {
        let lid = UUID()
        let e = UUID()
        let cands = [se(e, type: "compound", layerId: lid)]
        let res = LayerResolver.resolve(
            candidates: cands, layers: [activeLayer(lid, type: "school")],
            zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil
        )
        #expect(res[e] == nil)
    }

    /// primaryFilter acts as a display gate: owned entity matching the condition shows,
    /// owned entity NOT matching does not show.
    @Test func primaryFilterIsDisplayGate() {
        let lid = UUID()
        let e = UUID()
        let cond = FilterCondition(
            dimension: MapDimension(kind: .field, fieldKey: "grade", fieldSource: "base"),
            op: .equals, value: .string("重点")
        )
        let layerWithGate = activeLayer(lid, type: "school", conditions: [cond])
        let hit = [se(e, type: "school", layerId: lid, fields: ["grade": .string("重点")])]
        let miss = [se(e, type: "school", layerId: lid, fields: ["grade": .string("普通")])]
        let rHit = LayerResolver.resolve(
            candidates: hit, layers: [layerWithGate],
            zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil
        )
        let rMiss = LayerResolver.resolve(
            candidates: miss, layers: [layerWithGate],
            zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil
        )
        #expect(rHit[e] == lid)
        #expect(rMiss[e] == nil)
    }

    /// Entity with nil layerId never matches any layer.
    @Test func nilLayerIdNeverShows() {
        let lid = UUID()
        let e = UUID()
        let cands = [se(e, type: "school", layerId: nil)]
        let res = LayerResolver.resolve(
            candidates: cands, layers: [activeLayer(lid, type: "school")],
            zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil
        )
        #expect(res[e] == nil)
    }
}
