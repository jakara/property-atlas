import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleConsolidationMigratorRuleTests {
    private func makeContext() throws -> ModelContext {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        return ModelContext(container)
    }

    @Test func migratesStyleRuleAndConditions() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds")
        ctx.insert(dataset)
        let old = StyleRule(datasetId: dataset.id, name: "学校-重点", entityType: "school")
        old.priority = 10
        old.appliesGlyph = "重"
        old.appliesFillHex = "#FF3B30"
        old.appliesLabelVisible = true
        old.conditionsJSON = ##"[{"field":"grade","op":"equals","value":"重点"}]"##
        ctx.insert(old)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.styleRuleIds = [old.id]
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let view = MapView(datasetId: dataset.id, name: "v")
        view.isActive = true
        ctx.insert(view)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let rules = try ctx.fetch(FetchDescriptor<ViewStyleRule>())
        #expect(rules.count == 1)
        let rule = try #require(rules.first)
        #expect(rule.entityType == "school")
        #expect(rule.glyph == "重")
        #expect(rule.fillHex == "#FF3B30")
        #expect(rule.priority == 10)
        let conds = try ctx.fetch(FetchDescriptor<ViewStyleCondition>())
        #expect(conds.count == 1)
        #expect(conds.first?.field == "grade")
        #expect(conds.first?.op == "equals")
        #expect(conds.first?.valueString == "重点")
    }

    @Test func idempotentSkipsViewWithRules() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds2")
        ctx.insert(dataset)
        let old = StyleRule(datasetId: dataset.id, name: "r", entityType: "school")
        old.appliesGlyph = "重"
        old.conditionsJSON = "[]"
        ctx.insert(old)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.styleRuleIds = [old.id]
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let view = MapView(datasetId: dataset.id, name: "v")
        view.isActive = true
        ctx.insert(view)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)
        StyleConsolidationMigrator.run(in: ctx)

        let rules = try ctx.fetch(FetchDescriptor<ViewStyleRule>())
        #expect(rules.count == 1)
    }
}
