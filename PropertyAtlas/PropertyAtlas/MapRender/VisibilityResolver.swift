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
        datasetId: UUID?
    ) -> Set<UUID> {
        var out = Set<UUID>()
        for c in candidates {
            guard layerVisible.contains(c.id) else { continue }
            let input = MapDimension.Input(entity: c.entity, layerNames: c.layerNames, context: context, datasetId: datasetId)
            guard primary.matches(input) else { continue }
            if isHiddenByAnyChip(input: input, primary: primary, normals: normals, filterState: filterState) { continue }
            out.insert(c.id)
        }
        return out
    }

    private static func isHiddenByAnyChip(
        input: MapDimension.Input, primary: PrimaryFilter, normals: [NormalFilter], filterState: DimensionFilterState
    ) -> Bool {
        if let gb = primary.groupBy {
            for v in gb.resolve(input) where filterState.isHidden(dimensionKey: gb.key, value: v) {
                return true
            }
        }
        for nf in normals {
            for v in nf.dimension.resolve(input) where filterState.isHidden(dimensionKey: nf.dimension.key, value: v) {
                return true
            }
        }
        return false
    }
}
