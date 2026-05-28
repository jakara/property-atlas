import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleRuleTests {
    @Test func styleRulePersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, StyleRule.self])
        let ctx = ModelContext(container)
        let rule = StyleRule(
            datasetId: UUID(),
            name: "重点小学 红方",
            entityType: "school"
        )
        rule.conditionsJSON = #"[{"field":"grade","op":"equals","value":"重点"}]"#
        rule.appliesShape = "square"
        rule.appliesFillMode = "fixed"
        rule.appliesFillHex = "#FF3B30"
        rule.appliesGlyph = "重"
        rule.priority = 10
        ctx.insert(rule)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<StyleRule>())
        #expect(all.first?.appliesShape == "square")
        #expect(all.first?.priority == 10)
        #expect(all.first?.enabled == true)
    }
}
