import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct CompoundTests {
    @Test func compoundPersistsWithBaseFields() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Compound.self])
        let ctx = ModelContext(container)
        let c = Compound(
            datasetId: UUID(),
            name: "中海西派国印",
            latitude: 39.155,
            longitude: 117.180
        )
        c.buildYear = 2022
        c.developer = "中海"
        c.propertyFeeCents = 580
        c.customFieldsJSON = #"{"sourceCode":"YH-XLSX"}"#
        ctx.insert(c)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Compound>())
        #expect(all.first?.name == "中海西派国印")
        #expect(all.first?.buildYear == 2022)
        #expect(all.first?.propertyFeeCents == 580)
        #expect(all.first?.customFieldsJSON == #"{"sourceCode":"YH-XLSX"}"#)
        #expect(all.first?.deleted == false)
    }
}
