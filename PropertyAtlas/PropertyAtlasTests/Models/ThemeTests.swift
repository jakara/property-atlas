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
        t.visibilityJSON = #"{"compound":true,"school":true,"poi":false,"area":true}"#
        t.styleRuleIds = [UUID(), UUID()]
        t.defaultEnabledLayerIds = [UUID()]
        t.copyTitle = "和平区学区分布图"
        t.bgMapStyle = "satellite"
        ctx.insert(t)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Theme>())
        #expect(all.first?.name == "学区视图")
        #expect(all.first?.styleRuleIds.count == 2)
        #expect(all.first?.defaultEnabledLayerIds.count == 1)
        #expect(all.first?.spotlightOnSelect == true)
        #expect(all.first?.bgMapStyle == "satellite")
    }
}
