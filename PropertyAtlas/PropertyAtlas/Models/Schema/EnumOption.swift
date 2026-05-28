import Foundation
import SwiftData

@Model
final class EnumOption {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var scope: String = ""
    var label: String = ""
    var sortOrder: Int = 0
    var colorHex: String?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        scope: String,
        label: String,
        sortOrder: Int = 0,
        colorHex: String? = nil
    ) {
        self.id = id
        self.datasetId = datasetId
        self.scope = scope
        self.label = label
        self.sortOrder = sortOrder
        self.colorHex = colorHex
    }
}
