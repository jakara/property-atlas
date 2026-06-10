import Foundation
import SwiftData

/// 图层显式归属赋值逻辑。写 entity.layerId；维持默认层不变式。
@MainActor
enum LayerAssign {
    /// 某 entityType 的默认图层（isDefault=true，未删）。
    static func defaultLayer(entityType: String, datasetId: UUID, in ctx: ModelContext) -> Layer? {
        let all = (try? ctx.fetch(FetchDescriptor<Layer>())) ?? []
        return all.first {
            $0.datasetId == datasetId &&
                $0.entityType == entityType &&
                $0.isDefault &&
                !$0.deleted
        }
    }

    /// 把命中 conditions（AND）的某类型实体移动到 toLayerId。返回移动数。
    @discardableResult
    static func bulkAssign(
        entityType: String,
        conditions: [StyleCondition],
        toLayerId: UUID,
        datasetId: UUID,
        in ctx: ModelContext
    ) -> Int {
        var count = 0
        for (se, set) in styleEntities(entityType: entityType, datasetId: datasetId, in: ctx) {
            guard conditions.allSatisfy({ ConditionEvaluator.matches(entity: se, condition: $0) }) else { continue }
            set(toLayerId)
            count += 1
        }
        // layerId/updatedAt 是普通列，显式 save 正常持久（实测 store 落库），与 deleteLayer
        // 的 `deleted` 保留列冲突无关。
        if count > 0 { try? ctx.save() }
        return count
    }

    /// 预览：命中数（不改库）。
    static func previewCount(
        entityType: String,
        conditions: [StyleCondition],
        datasetId: UUID,
        in ctx: ModelContext
    ) -> Int {
        styleEntities(entityType: entityType, datasetId: datasetId, in: ctx)
            .filter { se, _ in conditions.allSatisfy { ConditionEvaluator.matches(entity: se, condition: $0) } }
            .count
    }

    /// 删图层：默认层禁删（返回 false）；否则成员回落默认层后软删（返回 true）。
    ///
    /// 注意：本方法**不调用** `ctx.save()`。SwiftData 在 `save()` flush 时会丢弃对
    /// `deleted` 列的写入（CoreData 保留 `deleted`/`isDeleted` 语义，实测同对象再读回
    /// `deleted=false`，而同一 save 中的 `name`/`updatedAt` 等其它列正常持久）。项目既有
    /// 软删路径 `EntityWriter.softDelete` 同样靠 context 自动保存落库、不显式 save。这里
    /// 沿用该惯例：所有写入（成员回落 layerId + 本层 deleted/updatedAt）由 autosave 落库。
    @discardableResult
    static func deleteLayer(_ layer: Layer, in ctx: ModelContext) -> Bool {
        guard !layer.isDefault else { return false }
        guard let def = defaultLayer(entityType: layer.entityType, datasetId: layer.datasetId, in: ctx) else {
            return false
        }
        reassignMembers(
            from: layer.id, to: def.id,
            entityType: layer.entityType, datasetId: layer.datasetId, in: ctx
        )
        layer.deleted = true
        layer.updatedAt = Date()
        return true
    }

    // MARK: - Helpers

    /// 取某类型全实体的 (StyleEntity, 写 layerId 闭包)。统一 4 类分发。
    private static func styleEntities(
        entityType: String,
        datasetId: UUID,
        in ctx: ModelContext
    ) -> [(StyleEntity, (UUID) -> Void)] {
        switch entityType {
        case "compound":
            let xs = (try? ctx.fetch(FetchDescriptor<Compound>(
                predicate: #Predicate { $0.datasetId == datasetId && $0.deleted == false }
            ))) ?? []
            return xs.map { e in (e.styleEntity, { e.layerId = $0
                e.updatedAt = Date() }) }
        case "school":
            let xs = (try? ctx.fetch(FetchDescriptor<School>(
                predicate: #Predicate { $0.datasetId == datasetId && $0.deleted == false }
            ))) ?? []
            return xs.map { e in (e.styleEntity, { e.layerId = $0
                e.updatedAt = Date() }) }
        case "poi":
            let xs = (try? ctx.fetch(FetchDescriptor<POI>(
                predicate: #Predicate { $0.datasetId == datasetId && $0.deleted == false }
            ))) ?? []
            return xs.map { e in (e.styleEntity, { e.layerId = $0
                e.updatedAt = Date() }) }
        case "area":
            let xs = (try? ctx.fetch(FetchDescriptor<Area>(
                predicate: #Predicate { $0.datasetId == datasetId && $0.deleted == false }
            ))) ?? []
            return xs.map { e in (e.styleEntity, { e.layerId = $0
                e.updatedAt = Date() }) }
        default:
            return []
        }
    }

    private static func reassignMembers(
        from old: UUID, to new: UUID,
        entityType: String, datasetId: UUID,
        in ctx: ModelContext
    ) {
        for (se, set) in styleEntities(entityType: entityType, datasetId: datasetId, in: ctx) where se.layerId == old {
            set(new)
        }
    }
}
