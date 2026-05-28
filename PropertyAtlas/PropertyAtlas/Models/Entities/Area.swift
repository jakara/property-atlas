import Foundation
import SwiftData

@Model
final class Area {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()

    var name: String = ""
    var aliases: [String] = []
    var notes: String?
    var privateNotes: String?
    var customFieldsJSON: String?
    var overrideStyleJSON: String?
    var photoIds: [UUID] = []
    var sourceUrl: String?

    var geometryKind: String = "polygon"
    var geometryJSON: String = ""
    var rasterImageRef: String?

    var category: String?
    var strokeHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        geometryKind: String = "polygon",
        geometryJSON: String = ""
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.geometryKind = geometryKind
        self.geometryJSON = geometryJSON
    }
}
