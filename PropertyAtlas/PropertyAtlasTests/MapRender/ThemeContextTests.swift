import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct ThemeContextTests {
    @Test func initialActiveThemeReadsFromDataset() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Theme.self])
        let ctx = ModelContext(container)
        let ds = Dataset(name: "test")
        let theme = Theme(datasetId: ds.id, name: "学区视图")
        ds.activeThemeId = theme.id
        ctx.insert(ds)
        ctx.insert(theme)
        try ctx.save()

        let themeCtx = ThemeContext(dataset: ds, modelContext: ctx)
        #expect(themeCtx.activeTheme?.name == "学区视图")
    }

    @Test func switchThemeUpdatesActiveThemeId() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Theme.self])
        let ctx = ModelContext(container)
        let ds = Dataset(name: "test")
        let t1 = Theme(datasetId: ds.id, name: "字段总览")
        let t2 = Theme(datasetId: ds.id, name: "学区视图")
        ds.activeThemeId = t1.id
        ctx.insert(ds)
        ctx.insert(t1)
        ctx.insert(t2)
        try ctx.save()

        let themeCtx = ThemeContext(dataset: ds, modelContext: ctx)
        themeCtx.switchTheme(to: t2)
        try ctx.save()

        #expect(ds.activeThemeId == t2.id)
        #expect(themeCtx.activeTheme?.id == t2.id)
    }

    @Test func allThemesReturnsDatasetThemesSorted() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Theme.self])
        let ctx = ModelContext(container)
        let ds = Dataset(name: "test")
        let t1 = Theme(datasetId: ds.id, name: "b")
        t1.sortOrder = 1
        let t2 = Theme(datasetId: ds.id, name: "a")
        t2.sortOrder = 0
        ctx.insert(ds)
        ctx.insert(t1)
        ctx.insert(t2)
        try ctx.save()
        let themeCtx = ThemeContext(dataset: ds, modelContext: ctx)
        let names = themeCtx.allThemes.map(\.name)
        #expect(names == ["a", "b"])
    }
}
