import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleConsolidationMigratorTests {
    private func makeContext() throws -> ModelContext {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        return ModelContext(container)
    }

    @Test func seedsViewStyleRowFromTheme() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "test-ds")
        ctx.insert(dataset)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.defaultStylesJSON = ##"{"compound":{"fillHex":"#123456","size":28}}"##
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let layer = Layer(datasetId: dataset.id, name: "楼盘", entityType: "compound")
        ctx.insert(layer)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let styles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        // 一个 compound 图层 → 恰好一行 compound 样式,从主题默认填充。
        #expect(styles.count == 1)
        let compound = try #require(styles.first { $0.entityType == "compound" })
        #expect(compound.layerId == layer.id)
        #expect(compound.fillHex == "#123456")
        #expect(compound.size == 28)
    }

    @Test func idempotentDoesNotClobberUserEdits() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds2")
        ctx.insert(dataset)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.defaultStylesJSON = ##"{"compound":{"fillHex":"#123456"}}"##
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let layer = Layer(datasetId: dataset.id, name: "楼盘", entityType: "compound")
        ctx.insert(layer)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)
        let firstStyles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        #expect(firstStyles.count == 1)
        let style = firstStyles.first { $0.entityType == "compound" }
        style?.fillHex = "#999999"
        try ctx.save()
        StyleConsolidationMigrator.run(in: ctx)
        let afterStyles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        #expect(afterStyles.count == 1)
        let afterStyle = afterStyles.first { $0.entityType == "compound" }
        #expect(afterStyle?.fillHex == "#999999")
    }

    @Test func migratesEntityOverrideJSONToColumns() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds3")
        ctx.insert(dataset)
        let compound = Compound(datasetId: dataset.id, name: "x", latitude: 1, longitude: 1)
        compound.overrideStyleJSON = ##"{"fillHex":"#ABCABC","size":40}"##
        ctx.insert(compound)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let refreshed = try ctx.fetch(FetchDescriptor<Compound>()).first
        #expect(refreshed?.styleFillHex == "#ABCABC")
        #expect(refreshed?.styleSize == 40)
        let refreshedDatasets = try ctx.fetch(FetchDescriptor<Dataset>())
        let refreshedDs = refreshedDatasets.first
        #expect(refreshedDs?.stylesMigratedV2 == true)
    }

    /// seed 的 theme.defaultStylesJSON 是空 "{}" —— 单图层应得一行全 nil(渲染回退 builtin),不崩。
    @Test func emptyThemeJSONProducesNilRow() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds5")
        ctx.insert(dataset)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.defaultStylesJSON = "{}"
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let layer = Layer(datasetId: dataset.id, name: "楼盘", entityType: "compound")
        ctx.insert(layer)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let styles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        #expect(styles.count == 1)
        let row = try #require(styles.first)
        #expect(row.entityType == "compound")
        #expect(row.fillHex == nil && row.shape == nil && row.labelVisible == nil)
    }
}
