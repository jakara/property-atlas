// PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerEvaluatorTests {
    private func cand(_ id: UUID, _ layerId: UUID?) -> LayerEvaluator.Candidate {
        LayerEvaluator.Candidate(id: id, layerId: layerId)
    }

    private func layer(_ id: UUID, enabled: Bool = true, min: Double? = nil, max: Double? = nil) -> LayerEvaluator.ActiveLayer {
        LayerEvaluator.ActiveLayer(id: id, enabled: enabled, minZoom: min, maxZoom: max)
    }

    @Test func noLayersDefinedShowsAll() {
        let def = UUID()
        let a = UUID()
        let b = UUID()
        let v = LayerEvaluator.visibleIds(
            layers: [],
            zoom: 10,
            candidates: [cand(a, nil), cand(b, def)],
            defaultLayerId: def
        )
        #expect(v == Set([a, b]))
    }

    @Test func allLayersDisabledHidesAll() {
        let def = UUID()
        let a = UUID()
        let v = LayerEvaluator.visibleIds(
            layers: [layer(def, enabled: false)],
            zoom: 10,
            candidates: [cand(a, def)],
            defaultLayerId: def
        )
        #expect(v.isEmpty)
    }

    @Test func onlyMembersOfEnabledLayersVisible() {
        let def = UUID()
        let other = UUID()
        let inDef = UUID()
        let inOther = UUID()
        let nilHome = UUID()
        let v = LayerEvaluator.visibleIds(
            layers: [layer(def, enabled: true), layer(other, enabled: false)],
            zoom: 10,
            candidates: [cand(inDef, def), cand(inOther, other), cand(nilHome, nil)],
            defaultLayerId: def
        )
        #expect(v == Set([inDef, nilHome]))
    }

    @Test func zoomOutOfRangeDeactivatesLayer() {
        let def = UUID()
        let a = UUID()
        let v = LayerEvaluator.visibleIds(
            layers: [layer(def, enabled: true, min: 12, max: 21)],
            zoom: 8, candidates: [cand(a, def)], defaultLayerId: def
        )
        #expect(v.isEmpty)
    }

    @Test func membershipMapsEntityToItsHomeLayerName() {
        let def = UUID()
        let other = UUID()
        let s = UUID()
        let named = [
            LayerEvaluator.NamedLayer(name: "默认", layer: layer(def, enabled: true)),
            LayerEvaluator.NamedLayer(name: "取景", layer: layer(other, enabled: true)),
        ]
        let m = LayerEvaluator.membership(
            layers: named,
            zoom: 12,
            candidates: [cand(s, other)],
            defaultLayerId: def
        )
        #expect(m[s] == ["取景"])
    }
}
