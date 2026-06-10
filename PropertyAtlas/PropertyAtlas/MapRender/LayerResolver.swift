import Foundation
import SwiftData

/// 图层中心化可见性:每个候选实体落到「类型匹配 + 层内 AND 过滤通过 + chip 未隐藏」的
/// 启用图层中 zIndex 最高者。返回 entityId → 命中图层 id。多图层之间天然 OR(并集 = 映射 keys)。
@MainActor
enum LayerResolver {
    struct Candidate {
        let id: UUID
        let entity: StyleEntity
    }

    struct ActiveLayer {
        let id: UUID
        let name: String
        let entityType: String
        let zIndex: Int
        let enabled: Bool
        let minZoom: Double?
        let maxZoom: Double?
        let primary: PrimaryFilter
        let normals: [NormalFilter]

        func isActive(at zoom: Double) -> Bool {
            guard enabled else { return false }
            if let minZoom, zoom < minZoom { return false }
            if let maxZoom, zoom > maxZoom { return false }
            return true
        }
    }

    /// entityId → 命中图层 id(zIndex 最高)。未命中任何图层的实体不在结果里(= 不可见)。
    static func resolve(
        candidates: [Candidate],
        layers: [ActiveLayer],
        zoom: Double,
        filterState: DimensionFilterState,
        context: ModelContext?,
        datasetId: UUID?,
        edgeProjection: EdgeProjection? = nil,
        cache: DimResolveCache? = nil
    ) -> [UUID: UUID] {
        let active = layers.filter { $0.isActive(at: zoom) }
        guard !active.isEmpty else { return [:] }
        var winner: [UUID: (layerId: UUID, zIndex: Int)] = [:]
        for c in candidates {
            let type = c.entity.entityType
            for layer in active where layer.entityType == type {
                let input = MapDimension.Input(
                    entity: c.entity, layerNames: [layer.name], context: context, datasetId: datasetId,
                    edgeProjection: edgeProjection, cache: cache
                )
                guard layer.primary.matches(input) else { continue }
                if isHidden(input: input, layer: layer, filterState: filterState) { continue }
                if let existing = winner[c.id], existing.zIndex >= layer.zIndex { continue }
                winner[c.id] = (layer.id, layer.zIndex)
            }
        }
        return winner.mapValues { $0.layerId }
    }

    /// chip 隐藏:命名空间键 "\(layerId)|\(dimKey)"(多图层各自独立)。
    private static func isHidden(
        input: MapDimension.Input, layer: ActiveLayer, filterState: DimensionFilterState
    ) -> Bool {
        if let gb = layer.primary.groupBy {
            let key = "\(layer.id.uuidString)|\(gb.key)"
            for v in gb.resolve(input) where filterState.isHidden(dimensionKey: key, value: v) {
                return true
            }
        }
        for nf in layer.normals {
            let key = "\(layer.id.uuidString)|\(nf.dimension.key)"
            for v in nf.dimension.resolve(input) where filterState.isHidden(dimensionKey: key, value: v) {
                return true
            }
        }
        return false
    }
}
