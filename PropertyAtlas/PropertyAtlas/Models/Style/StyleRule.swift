import Foundation
import SwiftData

@Model
final class StyleRule {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var entityType: String = ""
    var conditionsJSON: String = "[]"
    var priority: Int = 0
    var appliesShape: String?
    var appliesFillMode: String = "fixed"
    var appliesFillHex: String?
    var appliesPaletteId: UUID?
    var appliesPaletteKeyField: String?
    var appliesStrokeHex: String?
    var appliesGlyph: String?
    var appliesGlyphHex: String?
    var appliesSize: Int?
    var appliesLabelVisible: Bool?
    var appliesFillOpacity: Double?
    var appliesStrokeWidth: Double?
    var enabled: Bool = true
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        entityType: String
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.entityType = entityType
    }
}
