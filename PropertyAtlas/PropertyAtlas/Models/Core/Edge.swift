import Foundation
import SwiftData

@Model
final class Edge {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var fromId: UUID = UUID()
    var fromType: String = ""
    var toId: UUID = UUID()
    var toType: String = ""
    var label: String = ""
    var directed: Bool = false
    var note: String?
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        fromId: UUID, fromType: String,
        toId: UUID, toType: String,
        label: String,
        directed: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.datasetId = datasetId
        self.fromId = fromId
        self.fromType = fromType
        self.toId = toId
        self.toType = toType
        self.label = label
        self.directed = directed
        self.note = note
    }
}
