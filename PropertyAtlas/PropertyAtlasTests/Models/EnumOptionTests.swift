import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EnumOptionTests {
    @Test func enumOptionPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, EnumOption.self])
        let ctx = ModelContext(container)
        let opt = EnumOption(
            datasetId: UUID(),
            scope: "school.category",
            label: "小学",
            sortOrder: 0,
            colorHex: "#FF3B30"
        )
        ctx.insert(opt)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<EnumOption>())
        #expect(all.first?.label == "小学")
        #expect(all.first?.colorHex == "#FF3B30")
    }
}
