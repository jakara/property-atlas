import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct PhotoTests {
    @Test func photoPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Photo.self])
        let ctx = ModelContext(container)
        let p = Photo(
            ownerEntityId: UUID(),
            ownerEntityType: "compound",
            url: "file:///tmp/test.heic"
        )
        p.caption = "正门"
        p.order = 1
        ctx.insert(p)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Photo>())
        #expect(all.first?.ownerEntityType == "compound")
        #expect(all.first?.caption == "正门")
        #expect(all.first?.order == 1)
    }
}
