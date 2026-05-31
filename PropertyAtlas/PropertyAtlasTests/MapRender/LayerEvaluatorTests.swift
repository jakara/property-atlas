// PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerEvaluatorTests {
    private func cand(_ id: UUID, _ type: String, _ fields: [String: AnyJSON] = [:]) -> LayerEvaluator.Candidate {
        LayerEvaluator.Candidate(
            id: id,
            type: type,
            entity: StyleEntity(entityType: type, id: id, baseFields: fields, customFields: [:])
        )
    }

    @Test func noActiveLayersShowsAll() {
        let a = UUID()
        let b = UUID()
        let visible = LayerEvaluator.visibleIds(
            layers: [],
            zoom: 10,
            candidates: [cand(a, "school"), cand(b, "compound")]
        )
        #expect(visible == Set([a, b]))
    }

    @Test func matchAllLayerShowsAll() {
        let a = UUID()
        let l = LayerEvaluator.ActiveLayer(
            query: LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: nil),
            enabled: true,
            minZoom: nil,
            maxZoom: nil
        )
        let visible = LayerEvaluator.visibleIds(layers: [l], zoom: 10, candidates: [cand(a, "school")])
        #expect(visible == Set([a]))
    }

    @Test func dynamicLayerConstrainsItsTypeOnly() {
        let keptSchool = UUID()
        let droppedSchool = UUID()
        let compound = UUID()
        let json = ##"{"entityType":"school","conditions":[{"field":"grade","op":"equals","value":"重点"}]}"##
        let l = LayerEvaluator.ActiveLayer(
            query: LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: json),
            enabled: true,
            minZoom: nil,
            maxZoom: nil
        )
        let visible = LayerEvaluator.visibleIds(layers: [l], zoom: 10, candidates: [
            cand(keptSchool, "school", ["grade": .string("重点")]),
            cand(droppedSchool, "school", ["grade": .string("普通")]),
            cand(compound, "compound"),
        ])
        #expect(visible == Set([keptSchool, compound]))
    }

    @Test func zoomOutOfRangeDeactivatesLayer() {
        let a = UUID()
        let json = ##"{"entityType":"school","conditions":[]}"##
        let l = LayerEvaluator.ActiveLayer(
            query: LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: json),
            enabled: true,
            minZoom: 12,
            maxZoom: 21
        )
        let visible = LayerEvaluator.visibleIds(
            layers: [l],
            zoom: 8,
            candidates: [cand(a, "school", ["grade": .string("普通")])]
        )
        #expect(visible == Set([a]))
    }
}
