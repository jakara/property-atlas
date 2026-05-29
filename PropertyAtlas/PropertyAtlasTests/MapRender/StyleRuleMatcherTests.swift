import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleRuleMatcherTests {
    @Test func ruleMatchesWhenEntityTypeAndConditionsPass() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        s.category = "小学"
        let rule = StyleRule(datasetId: UUID(), name: "test", entityType: "school")
        rule.conditionsJSON = #"[{"field":"grade","op":"equals","value":"重点"},{"field":"category","op":"equals","value":"小学"}]"#
        #expect(StyleRuleMatcher.matches(rule: rule, entity: s.styleEntity))
    }

    @Test func ruleSkippedWhenEntityTypeDiffers() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let rule = StyleRule(datasetId: UUID(), name: "test", entityType: "compound")
        rule.conditionsJSON = "[]"
        #expect(!StyleRuleMatcher.matches(rule: rule, entity: s.styleEntity))
    }

    @Test func ruleSkippedWhenAnyConditionFails() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        s.category = "初中"
        let rule = StyleRule(datasetId: UUID(), name: "test", entityType: "school")
        rule.conditionsJSON = #"[{"field":"grade","op":"equals","value":"重点"},{"field":"category","op":"equals","value":"小学"}]"#
        #expect(!StyleRuleMatcher.matches(rule: rule, entity: s.styleEntity))
    }

    @Test func ruleSkippedWhenDisabled() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let rule = StyleRule(datasetId: UUID(), name: "test", entityType: "school")
        rule.conditionsJSON = "[]"
        rule.enabled = false
        #expect(!StyleRuleMatcher.matches(rule: rule, entity: s.styleEntity))
    }

    @Test func sortByPriorityDescending() {
        let r1 = StyleRule(datasetId: UUID(), name: "a", entityType: "school")
        r1.priority = 5
        let r2 = StyleRule(datasetId: UUID(), name: "b", entityType: "school")
        r2.priority = 10
        let r3 = StyleRule(datasetId: UUID(), name: "c", entityType: "school")
        r3.priority = 0
        let sorted = StyleRuleMatcher.sortByPriority([r1, r2, r3])
        #expect(sorted.map(\.name) == ["b", "a", "c"])
    }
}
