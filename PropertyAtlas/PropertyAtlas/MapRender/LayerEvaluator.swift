// PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift
import Foundation

@MainActor
enum LayerEvaluator {
    struct Candidate {
        let id: UUID
        let layerId: UUID?
    }

    struct ActiveLayer {
        let id: UUID
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

    struct NamedLayer {
        let name: String
        let layer: ActiveLayer
    }

    /// 单归属:实体可见 ⟺ 其所属图层(layerId,nil 兜底到 defaultLayerId)启用且在 zoom 范围内。
    /// 未定义任何图层 → 无约束显示全部;定义了但无启用 → 全隐藏。
    static func visibleIds(
        layers: [ActiveLayer], zoom: Double, candidates: [Candidate], defaultLayerId: UUID
    ) -> Set<UUID> {
        guard !layers.isEmpty else { return Set(candidates.map(\.id)) }
        let activeIds = Set(layers.filter { $0.isActive(at: zoom) }.map(\.id))
        guard !activeIds.isEmpty else { return [] }
        var visible = Set<UUID>()
        for c in candidates {
            let home = c.layerId ?? defaultLayerId
            if activeIds.contains(home) { visible.insert(c.id) }
        }
        return visible
    }

    /// 每个实体 → 其所属启用图层名(单元素)。供 MapDimension.layer 投影 + 可见集 layerNames。
    static func membership(
        layers: [NamedLayer], zoom: Double, candidates: [Candidate], defaultLayerId: UUID
    ) -> [UUID: [String]] {
        var nameById: [UUID: String] = [:]
        for nl in layers where nl.layer.isActive(at: zoom) {
            nameById[nl.layer.id] = nl.name
        }
        var out: [UUID: [String]] = [:]
        for c in candidates {
            let home = c.layerId ?? defaultLayerId
            if let name = nameById[home] { out[c.id] = [name] }
        }
        return out
    }
}
