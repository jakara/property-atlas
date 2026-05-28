import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct CustomFieldDefTests {
    @Test func customFieldDefPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, CustomFieldDef.self])
        let ctx = ModelContext(container)
        let def = CustomFieldDef(
            datasetId: UUID(),
            entityType: "compound",
            key: "sourceCode",
            label: "信源",
            type: "string",
            source: "migrated"
        )
        ctx.insert(def)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
        #expect(all.count == 1)
        #expect(all.first?.key == "sourceCode")
        #expect(all.first?.source == "migrated")
        #expect(all.first?.pinnedToCard == false)
    }
}
