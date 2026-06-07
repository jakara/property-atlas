import Foundation
import SwiftData

@MainActor
enum VisibilityResolver {
    struct Candidate {
        let id: UUID
        let entity: StyleEntity
        let layerNames: [String]
    }

    static func visibleIds(
        candidates: [Candidate],
        layerVisible: Set<UUID>,
        primary: PrimaryFilter,
        normals: [NormalFilter],
        filterState: DimensionFilterState,
        context: ModelContext?,
        datasetId: UUID?,
        edgeProjection: EdgeProjection? = nil,
        cache: DimResolveCache? = nil
    ) -> Set<UUID> {
        var out = Set<UUID>()
        for c in candidates {
            guard layerVisible.contains(c.id) else { continue }
            let t = c.entity.entityType
            let input = MapDimension.Input(
                entity: c.entity, layerNames: c.layerNames, context: context, datasetId: datasetId,
                edgeProjection: edgeProjection, cache: cache
            )
            // 主过滤器仅约束它绑定的实体类型;其他类型不受其条件影响(跨实体 OR)。
            if primary.entityType == t, !primary.matches(input) { continue }
            if isHiddenByAnyChip(input: input, t: t, primary: primary, normals: normals, filterState: filterState) { continue }
            out.insert(c.id)
        }
        return out
    }

    private static func isHiddenByAnyChip(
        input: MapDimension.Input, t: String,
        primary: PrimaryFilter, normals: [NormalFilter], filterState: DimensionFilterState
    ) -> Bool {
        // groupBy chip 仅作用于主过滤器绑定的实体类型
        if primary.entityType == t, let gb = primary.groupBy {
            for v in gb.resolve(input) where filterState.isHidden(dimensionKey: gb.key, value: v) {
                return true
            }
        }
        // 普通过滤器 chip 仅作用于各自绑定的实体类型
        for nf in normals where nf.entityType == t {
            for v in nf.dimension.resolve(input) where filterState.isHidden(dimensionKey: nf.dimension.key, value: v) {
                return true
            }
        }
        return false
    }
}
