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

    struct NamedLayer {
        let name: String
        let layer: ActiveLayer
    }

    /// 每个 candidate → 命中的启用图层名集合。match-all 层使全员归属;受约束层仅列真实成员
    /// (static ref 命中 或 dynamicType 命中且条件全过)。语义供 MapDimension.layer 投影 + 可见集 layerNames。
    static func membership(layers: [NamedLayer], zoom: Double, candidates: [Candidate]) -> [UUID: [String]] {
        let active = layers.filter { $0.layer.isActive(at: zoom) }
        var out: [UUID: [String]] = [:]
        for nl in active {
            let q = nl.layer.query
            if q.isMatchAll {
                for c in candidates { out[c.id, default: []].append(nl.name) }
                continue
            }
            let staticIds = Set(q.staticRefs.map(\.id))
            for c in candidates {
                let isMember: Bool
                if staticIds.contains(c.id) {
                    isMember = true
                } else if let dType = q.dynamicType, c.type == dType {
                    isMember = matchesAll(c.entity, q.dynamicConditions)
                } else {
                    isMember = false
                }
                if isMember { out[c.id, default: []].append(nl.name) }
            }
        }
        return out
    }

    private static func matchesAll(_ entity: StyleEntity, _ conditions: [StyleCondition]) -> Bool {
        for c in conditions where !ConditionEvaluator.matches(entity: entity, condition: c) {
            return false
        }
        return true
    }
}
