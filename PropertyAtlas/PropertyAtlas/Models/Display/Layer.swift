import Foundation
import SwiftData

@Model
final class Layer {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var iconSF: String?
    var colorHex: String?
    var staticRefsJSON: String?
    var dynamicQueryJSON: String?
    var minZoom: Double?
    var maxZoom: Double?
    var isDefault: Bool = false
    var enabled: Bool = true
    var sortOrder: Int = 0
    var zIndex: Int = 0
    var themeId: UUID?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
    }
}
