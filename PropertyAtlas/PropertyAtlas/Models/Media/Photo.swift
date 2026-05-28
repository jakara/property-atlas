import Foundation
import SwiftData

@Model
final class Photo {
    var id: UUID = UUID()
    var ownerEntityId: UUID = UUID()
    var ownerEntityType: String = ""
    var url: String = ""
    @Attribute(.externalStorage) var heicData: Data?
    var caption: String?
    var takenAt: Date?
    var width: Int?
    var height: Int?
    var order: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        ownerEntityId: UUID,
        ownerEntityType: String,
        url: String
    ) {
        self.id = id
        self.ownerEntityId = ownerEntityId
        self.ownerEntityType = ownerEntityType
        self.url = url
    }
}
