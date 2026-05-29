import Foundation

@MainActor
enum StyleRuleMatcher {
    static func matches(rule: StyleRule, entity: StyleEntity) -> Bool {
        guard rule.enabled else { return false }
        guard rule.entityType == entity.entityType else { return false }
        let conditions = parseConditions(rule.conditionsJSON)
        for c in conditions {
            if !ConditionEvaluator.matches(entity: entity, condition: c) { return false }
        }
        return true
    }

    static func sortByPriority(_ rules: [StyleRule]) -> [StyleRule] {
        rules.sorted { $0.priority > $1.priority }
    }

    private static func parseConditions(_ json: String) -> [StyleCondition] {
        guard !json.isEmpty, json != "[]" else { return [] }
        do {
            return try JSONHelpers.decode(json)
        } catch {
            return []
        }
    }
}
