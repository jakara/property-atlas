import Testing
import Foundation
import SwiftData
@testable import PropertyAtlas

@MainActor
struct MapViewContextTests {
    @Test func activeViewAndDecodedFiltersAndThemeFallback() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let ds = Dataset(name: "T"); ctx.insert(ds)
        let theme = Theme(datasetId: ds.id, name: "基础"); ctx.insert(theme)
        ds.activeThemeId = theme.id
        let v = MapView(datasetId: ds.id, name: "学区视图")
        v.isActive = true
        v.primaryFilterJSON = #"{"conditions":[],"groupBy":{"kind":"field","fieldKey":"grade","fieldSource":"base"}}"#
        v.normalFiltersJSON = "[]"
        ctx.insert(v); try ctx.save()

        let mvc = MapViewContext(dataset: ds, modelContext: ctx)
        #expect(mvc.activeMapView?.name == "学区视图")
        #expect(mvc.primaryFilter.groupBy?.fieldKey == "grade")
        #expect(mvc.normalFilters.isEmpty)
        #expect(mvc.activeTheme?.id == theme.id)   // no layer themeId → dataset.activeThemeId
        #expect(mvc.visibility["school"] == true)
    }

    @Test func switchViewSetsActive() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let ds = Dataset(name: "T"); ctx.insert(ds)
        let v1 = MapView(datasetId: ds.id, name: "A"); v1.isActive = true; v1.sortOrder = 0
        let v2 = MapView(datasetId: ds.id, name: "B"); v2.isActive = false; v2.sortOrder = 1
        ctx.insert(v1); ctx.insert(v2); try ctx.save()
        let mvc = MapViewContext(dataset: ds, modelContext: ctx)
        mvc.switchView(to: v2)
        #expect(mvc.activeMapView?.name == "B")
        #expect(v1.isActive == false)
    }
}
