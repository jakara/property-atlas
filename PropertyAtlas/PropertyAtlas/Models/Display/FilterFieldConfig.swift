import Foundation
import SwiftData

@Model
final class FilterFieldConfig {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var entityType: String = ""
    var fieldKey: String = ""
    var fieldSource: String = "base"
    var label: String = ""
    var slot: Int = 1
    var showInLegend: Bool = true
    var showSwatch: Bool = true
    var expandedByDefault: Bool = true
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        entityType: String,
        fieldKey: String,
        fieldSource: String = "base",
        label: String,
        slot: Int
    ) {
        self.id = id
        self.datasetId = datasetId
        self.entityType = entityType
        self.fieldKey = fieldKey
        self.fieldSource = fieldSource
        self.label = label
        self.slot = slot
    }
}
