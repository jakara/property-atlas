import Foundation
import SwiftData

/// 维度编辑器的数据源:可选字段(base+custom)、枚举值、edge 标签。
@MainActor
enum FieldKeyCatalog {
    struct FieldItem: Hashable {
        let key: String
        let label: String
        let source: String // "base" | "custom"
        let enumScope: String?
    }

    static func fields(entityType: String, datasetId: UUID, context: ModelContext?) -> [FieldItem] {
        guard let kind = EntityKind(rawValue: entityType) else { return [] }
        // 通用标识字段:名字 / ID(分组染色「一实体一色」常用;名字重复时用 ID 保唯一)
        var out: [FieldItem] = [
            FieldItem(key: "name", label: "名字", source: "base", enumScope: nil),
            FieldItem(key: "id", label: "ID", source: "base", enumScope: nil),
        ]
        out += EntityFieldSchema.fields(for: kind).map {
            FieldItem(key: $0.key, label: $0.label, source: "base", enumScope: $0.enumScope)
        }
        if let ctx = context {
            let fd = FetchDescriptor<CustomFieldDef>(
                predicate: #Predicate { $0.datasetId == datasetId && $0.entityType == entityType && !$0.deleted },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            for c in (try? ctx.fetch(fd)) ?? [] {
                out.append(FieldItem(key: c.key, label: c.label, source: "custom", enumScope: "\(entityType).\(c.key)"))
            }
        }
        return out
    }

    static func enumLabels(scope: String, datasetId: UUID, context: ModelContext?) -> [String] {
        guard let ctx = context else { return [] }
        let fd = FetchDescriptor<EnumOption>(
            predicate: #Predicate { $0.datasetId == datasetId && $0.scope == scope && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return ((try? ctx.fetch(fd)) ?? []).map(\.label)
    }

    static func edgeLabels(datasetId: UUID, context: ModelContext?) -> [String] {
        enumLabels(scope: "edge.label", datasetId: datasetId, context: context)
    }
}
