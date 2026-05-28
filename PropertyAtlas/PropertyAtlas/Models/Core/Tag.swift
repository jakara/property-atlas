import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var category: String = ""
    var label: String = ""
    var polarity: String = "neutral"
    var colorHex: String?
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        category: String,
        label: String,
        polarity: String = "neutral"
    ) {
        self.id = id
        self.datasetId = datasetId
        self.category = category
        self.label = label
        self.polarity = polarity
    }
}
