import Foundation

/// StyleRule.conditionsJSON ⇄ [StyleCondition]。坏/空 JSON → []。
enum StyleConditionCodec {
    static func decode(_ json: String) -> [StyleCondition] {
        let result: [StyleCondition]? = try? JSONHelpers.decode(json)
        return result ?? []
    }

    static func encode(_ conditions: [StyleCondition]) -> String {
        (try? JSONHelpers.encode(conditions)) ?? "[]"
    }
}
