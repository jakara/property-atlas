import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct DocumentTests {
    @Test func documentPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Document.self])
        let ctx = ModelContext(container)
        let d = Document(
            ownerEntityId: UUID(),
            ownerEntityType: "area",
            kind: "pdf",
            title: "2024 招生简章",
            url: "file:///tmp/test.pdf"
        )
        d.ocrText = "和平区..."
        ctx.insert(d)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Document>())
        #expect(all.first?.title == "2024 招生简章")
        #expect(all.first?.kind == "pdf")
    }
}
