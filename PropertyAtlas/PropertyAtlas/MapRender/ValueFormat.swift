import Foundation

/// 标量 → 显示串 / 复合键。原 FilterPredicate 的纯静态工具迁移至此(FilterPredicate 将删除)。
enum ValueFormat {
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
}
