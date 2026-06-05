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

    @Test func seedsViewStylesAndPaletteFromTheme() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "test-ds")
        ctx.insert(dataset)
        let palette = Palette(name: "p", colorsHex: ["#AAA111", "#BBB222"])
        ctx.insert(palette)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.defaultStylesJSON = ##"{"compound":{"fillHex":"#123456","size":28}}"##
        theme.showLegend = false
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let view = MapView(datasetId: dataset.id, name: "v")
        view.paletteId = palette.id
        view.isActive = true
        ctx.insert(view)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let styles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        #expect(styles.count == 4)
        let compound = styles.first { $0.entityType == "compound" }
        #expect(compound?.fillHex == "#123456")
        #expect(compound?.size == 28)
        let refreshedViews = try ctx.fetch(FetchDescriptor<MapView>())
        let refreshedView = refreshedViews.first
        #expect(refreshedView?.paletteHex == ["#AAA111", "#BBB222"])
        #expect(refreshedView?.showLegend == false)
    }

    @Test func idempotentDoesNotClobberUserEdits() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds2")
        ctx.insert(dataset)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.defaultStylesJSON = ##"{"compound":{"fillHex":"#123456"}}"##
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let view = MapView(datasetId: dataset.id, name: "v")
        view.isActive = true
        ctx.insert(view)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)
        let firstStyles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        let style = firstStyles.first { $0.entityType == "compound" }
        style?.fillHex = "#999999"
        try ctx.save()
        StyleConsolidationMigrator.run(in: ctx)
        let afterStyles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        #expect(afterStyles.count == 4)
        let afterStyle = afterStyles.first { $0.entityType == "compound" }
        #expect(afterStyle?.fillHex == "#999999")
    }

    @Test func resolvesThemeFromTopEnabledLayer() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds4")
        ctx.insert(dataset)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.defaultStylesJSON = ##"{"compound":{"fillHex":"#ABCDEF"}}"##
        ctx.insert(theme)
        let layer = Layer(datasetId: dataset.id, name: "L")
        layer.themeId = theme.id
        layer.zIndex = 10
        ctx.insert(layer)
        let view = MapView(datasetId: dataset.id, name: "v")
        view.enabledLayerIds = [layer.id]
        view.isActive = true
        ctx.insert(view)
        // dataset.activeThemeId 故意留 nil:验证经 layer.themeId 解析
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let styles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        let compound = styles.first { $0.entityType == "compound" }
        #expect(compound?.fillHex == "#ABCDEF")
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
}
