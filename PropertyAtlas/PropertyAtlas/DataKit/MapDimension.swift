import Foundation
import SwiftData

enum DimensionKind: String, Codable, CaseIterable {
    case layer, entityType, field, edgeField
}

struct MapDimension: Codable, Hashable {
    var kind: DimensionKind
    var fieldKey: String?
    var fieldSource: String?
    var edgeLabel: String?
    var edgeDirection: String?
    var edgeTargetField: String?

    init(
        kind: DimensionKind,
        fieldKey: String? = nil,
        fieldSource: String? = nil,
        edgeLabel: String? = nil,
        edgeDirection: String? = nil,
        edgeTargetField: String? = nil
    ) {
        self.kind = kind
        self.fieldKey = fieldKey
        self.fieldSource = fieldSource
        self.edgeLabel = edgeLabel
        self.edgeDirection = edgeDirection
        self.edgeTargetField = edgeTargetField
    }

    var key: String {
        switch kind {
        case .layer: "layer"
        case .entityType: "entityType"
        case .field: "field:\(fieldKey ?? "")"
        case .edgeField: "edge:\(edgeLabel ?? ""):\(edgeDirection ?? "downstream"):\(edgeTargetField ?? "name")"
        }
    }

    struct Input {
        let entity: StyleEntity
        let layerNames: [String]
        let context: ModelContext?
        let datasetId: UUID?
        /// 批量 edge 索引(内存)。提供则 edgeField 走内存投影,免 per-entity DB fetch。
        var edgeProjection: EdgeProjection?
        /// per-rebuild 解析缓存(引用类型,跨 stage 共享)。命中则跳过重算 —— 同一维度同一实体
        /// 在 visibility/groupColors/legend 间被调多次,缓存把 N×4 次塌成 N 次。
        var cache: DimResolveCache?
    }

    @MainActor
    func resolve(_ input: Input) -> [String] {
        if let cache = input.cache, let hit = cache.value(dimKey: key, entityId: input.entity.id) {
            return hit
        }
        let result = compute(input)
        input.cache?.set(dimKey: key, entityId: input.entity.id, value: result)
        return result
    }

    @MainActor
    private func compute(_ input: Input) -> [String] {
        switch kind {
        case .layer:
            return input.layerNames.filter { !$0.isEmpty }
        case .entityType:
            return [input.entity.entityType]
        case .field:
            guard let fk = fieldKey else { return [] }
            // 多值字段(如 tags):数组元素各自成一个维度值。
            if case let .array(items)? = input.entity.field(fk) {
                return items.compactMap { item in
                    let s = ValueFormat.display(item)
                    return s.isEmpty ? nil : s
                }
            }
            let s = ValueFormat.display(input.entity.field(fk))
            return s.isEmpty ? [] : [s]
        case .edgeField:
            guard let label = edgeLabel, let entKind = EntityKind(rawValue: input.entity.entityType) else { return [] }
            let dir: EdgeDirection = switch edgeDirection {
            case "upstream": .upstream
            case "either": .either
            default: .downstream
            }
            // 优先内存投影;无则回退 DB(测试/旧路径)。
            if let proj = input.edgeProjection {
                return proj.relatedFieldValues(
                    of: input.entity.id, edgeLabel: label, direction: dir, targetField: edgeTargetField
                )
            }
            guard let ctx = input.context, let dsId = input.datasetId else { return [] }
            return EdgeStore.relatedFieldValues(
                of: EntityRef(id: input.entity.id, kind: entKind),
                edgeLabel: label, direction: dir, targetField: edgeTargetField,
                datasetId: dsId, in: ctx
            )
        }
    }
}

/// per-rebuild 维度解析缓存。key = "\(dimKey)#\(entityId)"。引用类型,跨 stage 共享同一实例。
final class DimResolveCache {
    private var store: [String: [String]] = [:]

    func value(dimKey: String, entityId: UUID) -> [String]? {
        store["\(dimKey)#\(entityId.uuidString)"]
    }

    func set(dimKey: String, entityId: UUID, value: [String]) {
        store["\(dimKey)#\(entityId.uuidString)"] = value
    }
}

/// edge 投影内存索引。一次性从 dataset 全部 Edge + 全部实体构建,之后 edgeField 解析纯内存。
/// 取代 `EdgeStore.relatedFieldValues` 的 per-entity `FetchDescriptor<Edge>` + per-edge 实体 fetch。
struct EdgeProjection {
    struct E {
        let fromId: UUID
        let toId: UUID
        let label: String
    }

    /// entityId → 与之相连的边(from 或 to 命中),已按 sortOrder/createdAt 排好。
    let edgesByEntity: [UUID: [E]]
    /// entityId → StyleEntity,用于取对端 targetField / name。
    let entityById: [UUID: StyleEntity]

    func relatedFieldValues(
        of id: UUID, edgeLabel: String, direction: EdgeDirection, targetField: String?
    ) -> [String] {
        guard let edges = edgesByEntity[id] else { return [] }
        var out: [String] = []
        for edge in edges where edge.label == edgeLabel {
            let otherId: UUID
            if edge.fromId == id {
                if direction == .upstream { continue }
                otherId = edge.toId
            } else {
                if direction == .downstream { continue }
                otherId = edge.fromId
            }
            guard let other = entityById[otherId] else { continue }
            let value: String? = if let targetField {
                Self.stringify(other.field(targetField))
            } else {
                Self.stringify(other.field("name"))
            }
            if let value, !value.isEmpty { out.append(value) }
        }
        return out
    }

    private static func stringify(_ value: AnyJSON?) -> String? {
        switch value {
        case let .string(str): str.isEmpty ? nil : str
        case let .int(num): String(num)
        case let .double(dbl): String(dbl)
        case let .bool(flag): String(flag)
        default: nil
        }
    }
}
