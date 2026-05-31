// PropertyAtlas/PropertyAtlas/States/FilterPredicate.swift
import Foundation

struct FilterPredicate {
    /// key = "\(entityType).\(fieldKey)" → 被隐藏的 value 显示串集合
    let hidden: [String: Set<String>]

    static func key(_ entityType: String, _ fieldKey: String) -> String {
        "\(entityType).\(fieldKey)"
    }

    static func display(_ v: AnyJSON?) -> String {
        switch v {
        case let .string(s): s
        case let .int(i): String(i)
        case let .double(d): String(d)
        case let .bool(b): b ? "true" : "false"
        default: ""
        }
    }

    /// fieldKeys = 该 entityType 配置的 filter 字段。AND 跨字段：任一字段值被隐 → 不通过。
    /// excludeFieldKey: 计数自身 chip 时排除该字段的 filter（§5.7）。
    func passes(_ entity: StyleEntity, fieldKeys: [String], excludeFieldKey: String? = nil) -> Bool {
        for fk in fieldKeys where fk != excludeFieldKey {
            let value = Self.display(entity.field(fk))
            if hidden[Self.key(entity.entityType, fk)]?.contains(value) == true { return false }
        }
        return true
    }
}
