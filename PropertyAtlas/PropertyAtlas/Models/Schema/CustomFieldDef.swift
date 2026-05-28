import Foundation
import SwiftData

@Model
final class CustomFieldDef {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var entityType: String = ""
    var key: String = ""
    var label: String = ""
    var type: String = "string"
    var enumOptionsJSON: String?
    var unit: String?
    var defaultValueJSON: String?
    var pinnedToCard: Bool = false
    var showInLegendChip: Bool = false
    var sortOrder: Int = 0
    var source: String = "user"
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        entityType: String,
        key: String,
        label: String,
        type: String = "string",
        source: String = "user"
    ) {
        self.id = id
        self.datasetId = datasetId
        self.entityType = entityType
        self.key = key
        self.label = label
        self.type = type
        self.source = source
    }
}
