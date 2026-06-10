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

    @Test func matchesByEntityTypeOnly() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A")
        let layers = [layer(type: "compound"), layer(type: "school")]
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)], layers: layers, zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result[c.id] != nil)
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

    @Test func andFilterNarrowsMembership() throws {
        let ctx = try makeContext()
        let hardcover = compound(ctx, name: "精装盘", finishType: "精装")
        let bare = compound(ctx, name: "毛坯盘", finishType: "毛坯")
        let cond = FilterCondition(
            dimension: MapDimension(kind: .field, fieldKey: "finishType", fieldSource: "base"),
            op: .equals, value: .string("精装")
        )
        let result = LayerResolver.resolve(
            candidates: [
                .init(id: hardcover.id, entity: hardcover.styleEntity),
                .init(id: bare.id, entity: bare.styleEntity),
            ],
            layers: [layer(type: "compound", conditions: [cond])], zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result[hardcover.id] != nil)
        #expect(result[bare.id] == nil)
    }

    @Test func highestZIndexWinsOnOverlap() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A")
        let low = UUID(), high = UUID()
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
}
