import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct SchoolTests {
    @Test func schoolPersistsWithBaseFields() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, School.self])
        let ctx = ModelContext(container)
        let s = School(
            datasetId: UUID(),
            name: "鞍山道小学",
            latitude: 39.122413,
            longitude: 117.192636
        )
        s.category = "小学"
        s.grade = "重点"
        s.form = "普通"
        s.foundYear = 1954
        s.communitiesText = "静安社区, 庆有西里…"
        ctx.insert(s)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<School>())
        #expect(all.first?.name == "鞍山道小学")
        #expect(all.first?.category == "小学")
        #expect(all.first?.grade == "重点")
        #expect(all.first?.form == "普通")
        #expect(all.first?.foundYear == 1954)
    }
}
