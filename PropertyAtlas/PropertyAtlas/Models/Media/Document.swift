import Foundation
import SwiftData

@Model
final class Document {
    var id: UUID = UUID()
    var ownerEntityId: UUID = UUID()
    var ownerEntityType: String = ""
    var kind: String = "pdf"
    var title: String = ""
    var url: String = ""
    @Attribute(.externalStorage) var data: Data?
    var ocrText: String?
    var mimeType: String?
    var pageCount: Int?
    var order: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        ownerEntityId: UUID,
        ownerEntityType: String,
        kind: String,
        title: String,
        url: String = ""
    ) {
        self.id = id
        self.ownerEntityId = ownerEntityId
        self.ownerEntityType = ownerEntityType
        self.kind = kind
        self.title = title
        self.url = url
    }
}
