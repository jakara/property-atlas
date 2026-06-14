import Foundation

/// ViewStyleCondition の typed 列 ⇄ StyleCondition / AnyJSON。
/// 求值: styleCondition(...) 喂 ConditionEvaluator。
/// 迁移: columns(from:op:) 从旧 AnyJSON 取列。
enum ViewStyleConditionCodec {
    static func styleCondition(
        field: String,
        op: StyleConditionOp,
        valueString: String?,
        valueList: [String]
    ) -> StyleCondition {
        let value: AnyJSON = switch op {
        case .inOp:
            .array(valueList.map { .string($0) })
        case .exists:
            .null
        case .gte, .lte:
            if let number = Double(valueString ?? "") {
                .double(number)
            } else {
                .string(valueString ?? "")
            }
        case .equals, .notEquals:
            switch valueString {
            case "true": .bool(true)
            case "false": .bool(false)
            default: .string(valueString ?? "")
            }
        default:
            .string(valueString ?? "")
        }
        return StyleCondition(field: field, op: op, value: value)
    }

    static func columns(
        from value: AnyJSON,
        op: StyleConditionOp // swiftlint:disable:this unused_parameter
    ) -> (valueString: String?, valueList: [String]) {
        switch value {
        case let .string(text):
            (text, [])
        case let .int(number):
            (String(number), [])
        case let .double(number):
            (String(number), [])
        case let .bool(flag):
            (String(flag), [])
        case let .array(items):
            (nil, items.map { stringify($0) })
        case .null, .object:
            (nil, [])
        }
    }

    private static func stringify(_ value: AnyJSON) -> String {
        switch value {
        case let .string(text): text
        case let .int(number): String(number)
        case let .double(number): String(number)
        case let .bool(flag): String(flag)
        default: ""
        }
    }
}
