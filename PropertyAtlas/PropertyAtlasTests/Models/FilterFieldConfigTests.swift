import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct FilterFieldConfigTests {
    @Test func filterFieldConfigPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, FilterFieldConfig.self])
        let ctx = ModelContext(container)
        let f = FilterFieldConfig(
            datasetId: UUID(),
            entityType: "school",
            fieldKey: "grade",
            fieldSource: "base",
            label: "等级",
            slot: 2
        )
        ctx.insert(f)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<FilterFieldConfig>())
        #expect(all.first?.fieldKey == "grade")
        #expect(all.first?.slot == 2)
        #expect(all.first?.showInLegend == true)
    }
}
