import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct ThemeTests {
    @Test func themePersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Theme.self])
        let ctx = ModelContext(container)
        let t = Theme(
            datasetId: UUID(),
            name: "学区视图"
        )
        // P8b: 9 global fields (visibility/copy*/camera/bg/drawEdge/spotlight/
        // defaultEnabledLayerIds) moved off Theme onto MapView. Theme now keeps
        // only styling identity fields.
        t.styleRuleIds = [UUID(), UUID()]
        t.showLegend = true
        ctx.insert(t)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Theme>())
        #expect(all.first?.name == "学区视图")
        #expect(all.first?.styleRuleIds.count == 2)
        #expect(all.first?.showLegend == true)
    }
}
