// PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift
import Foundation

@MainActor
enum LayerEvaluator {
    struct Candidate {
        let id: UUID
        let type: String
        let entity: StyleEntity
    }

    struct ActiveLayer {
        let query: LayerQuery
        let enabled: Bool
        let minZoom: Double?
        let maxZoom: Double?

        func isActive(at zoom: Double) -> Bool {
            guard enabled else { return false }
            if let minZoom, zoom < minZoom { return false }
            if let maxZoom, zoom > maxZoom { return false }
            return true
        }
    }

    static func visibleIds(layers: [ActiveLayer], zoom: Double, candidates: [Candidate]) -> Set<UUID> {
        let active = layers.filter { $0.isActive(at: zoom) }
        guard !active.isEmpty else { return Set(candidates.map(\.id)) }

        if active.contains(where: \.query.isMatchAll) {
            return Set(candidates.map(\.id))
        }

        var constrainedTypes = Set<String>()
        for l in active {
            constrainedTypes.formUnion(l.query.coveredTypes)
        }

        var memberIds = Set<UUID>()
        for l in active {
            for ref in l.query.staticRefs {
                memberIds.insert(ref.id)
            }
            if let dType = l.query.dynamicType {
                for c in candidates where c.type == dType {
                    if matchesAll(c.entity, l.query.dynamicConditions) { memberIds.insert(c.id) }
                }
            }
        }

        var visible = Set<UUID>()
        for c in candidates {
            if !constrainedTypes.contains(c.type) || memberIds.contains(c.id) {
                visible.insert(c.id)
            }
        }
        return visible
    }

    private static func matchesAll(_ entity: StyleEntity, _ conditions: [StyleCondition]) -> Bool {
        for c in conditions where !ConditionEvaluator.matches(entity: entity, condition: c) {
            return false
        }
        return true
    }
}
