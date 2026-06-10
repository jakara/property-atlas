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
        let layer = Layer(datasetId: dataset.id, name: "学校", entityType: "school")
        ctx.insert(layer)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let rules = try ctx.fetch(FetchDescriptor<ViewStyleRule>())
        #expect(rules.count == 1)
        let rule = try #require(rules.first)
        #expect(rule.layerId == layer.id)
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

    @Test func idempotentSkipsLayerWithRules() throws {
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
        let layer = Layer(datasetId: dataset.id, name: "学校", entityType: "school")
        ctx.insert(layer)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)
        StyleConsolidationMigrator.run(in: ctx)

        let rules = try ctx.fetch(FetchDescriptor<ViewStyleRule>())
        #expect(rules.count == 1)
    }

    @Test func paletteModeFillHexIsNil() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds-pal")
        ctx.insert(dataset)
        let old = StyleRule(datasetId: dataset.id, name: "r", entityType: "school")
        old.appliesFillMode = "palette"
        old.appliesFillHex = "#FF0000"
        old.conditionsJSON = "[]"
        ctx.insert(old)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.styleRuleIds = [old.id]
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let layer = Layer(datasetId: dataset.id, name: "学校", entityType: "school")
        ctx.insert(layer)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let rule = try #require(try ctx.fetch(FetchDescriptor<ViewStyleRule>()).first)
        #expect(rule.fillHex == nil)
    }

    @Test func multiConditionSortOrder() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds-multi")
        ctx.insert(dataset)
        let old = StyleRule(datasetId: dataset.id, name: "r", entityType: "school")
        old.conditionsJSON = ##"[{"field":"grade","op":"equals","value":"重点"},{"field":"form","op":"equals","value":"九年制"}]"##
        ctx.insert(old)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.styleRuleIds = [old.id]
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let layer = Layer(datasetId: dataset.id, name: "学校", entityType: "school")
        ctx.insert(layer)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let conds = try ctx.fetch(FetchDescriptor<ViewStyleCondition>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(conds.count == 2)
        #expect(conds[0].field == "grade")
        #expect(conds[0].sortOrder == 0)
        #expect(conds[1].field == "form")
        #expect(conds[1].sortOrder == 1)
    }
}
