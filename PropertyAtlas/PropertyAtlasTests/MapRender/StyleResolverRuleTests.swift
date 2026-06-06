import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleResolverRuleTests {
    private func school(grade: String) -> StyleEntity {
        StyleEntity(
            entityType: "school",
            id: UUID(),
            baseFields: ["grade": .string(grade)],
            customFields: [:]
        )
    }

    private func rule(grade: String, fill: String, priority: Int = 10, enabled: Bool = true) -> ResolvedStyleRule {
        ResolvedStyleRule(
            pinPartial: PartialPinStyle(fillHex: fill),
            areaPartial: PartialAreaStyle(),
            priority: priority, enabled: enabled,
            conditions: [StyleCondition(field: "grade", op: .equals, value: .string(grade))]
        )
    }

    @Test func matchingRuleApplies() {
        let style = StyleResolver.resolvePin(
            entity: school(grade: "重点"), viewStyle: nil,
            rules: [rule(grade: "重点", fill: "#FF0000")], groupFillHex: nil
        )
        #expect(style.fillHex == "#FF0000")
    }

    @Test func nonMatchingRuleSkipped() {
        let style = StyleResolver.resolvePin(
            entity: school(grade: "普通"), viewStyle: nil,
            rules: [rule(grade: "重点", fill: "#FF0000")], groupFillHex: nil
        )
        #expect(style.fillHex == "#A8A8A8")
    }

    @Test func disabledRuleSkipped() {
        let style = StyleResolver.resolvePin(
            entity: school(grade: "重点"), viewStyle: nil,
            rules: [rule(grade: "重点", fill: "#FF0000", enabled: false)], groupFillHex: nil
        )
        #expect(style.fillHex == "#A8A8A8")
    }

    @Test func higherPriorityWinsWhenBothMatch() {
        let low = ResolvedStyleRule(
            pinPartial: PartialPinStyle(fillHex: "#111111"),
            areaPartial: PartialAreaStyle(),
            priority: 1,
            enabled: true,
            conditions: []
        )
        let high = ResolvedStyleRule(
            pinPartial: PartialPinStyle(fillHex: "#222222"),
            areaPartial: PartialAreaStyle(),
            priority: 9,
            enabled: true,
            conditions: []
        )
        let style = StyleResolver.resolvePin(
            entity: school(grade: "x"), viewStyle: nil, rules: [low, high], groupFillHex: nil
        )
        #expect(style.fillHex == "#222222")
    }

    @Test func ruleBeatsViewStyleButGroupFillBeatsRule() {
        let viewStyle = ViewEntityStyle(datasetId: UUID(), viewId: UUID(), entityType: "school")
        viewStyle.fillHex = "#000000"
        let style = StyleResolver.resolvePin(
            entity: school(grade: "重点"), viewStyle: viewStyle,
            rules: [rule(grade: "重点", fill: "#FF0000")], groupFillHex: "#00FF00"
        )
        #expect(style.fillHex == "#00FF00")
    }

    @Test func areaRuleApplies() {
        let area = StyleEntity(
            entityType: "area",
            id: UUID(),
            baseFields: ["category": .string("学区")],
            customFields: [:]
        )
        let rule = ResolvedStyleRule(
            pinPartial: PartialPinStyle(),
            areaPartial: PartialAreaStyle(fillHex: "#ABCDEF"),
            priority: 5, enabled: true,
            conditions: [StyleCondition(field: "category", op: .equals, value: .string("学区"))]
        )
        let style = StyleResolver.resolveArea(entity: area, viewStyle: nil, rules: [rule])
        #expect(style.fillHex == "#ABCDEF")
    }

    @Test func emptyConditionsAlwaysMatch() {
        let always = ResolvedStyleRule(
            pinPartial: PartialPinStyle(glyph: "★"),
            areaPartial: PartialAreaStyle(),
            priority: 0,
            enabled: true,
            conditions: []
        )
        let style = StyleResolver.resolvePin(
            entity: school(grade: "any"), viewStyle: nil, rules: [always], groupFillHex: nil
        )
        #expect(style.glyph == "★")
    }
}
