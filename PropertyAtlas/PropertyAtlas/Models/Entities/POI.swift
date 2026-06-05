import CoreLocation
import Foundation
import SwiftData

@Model
final class POI {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var layerId: UUID?

    var name: String = ""
    var aliases: [String] = []
    var address: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var notes: String?
    var privateNotes: String?
    var customFieldsJSON: String?
    var overrideStyleJSON: String?
    // 强类型 override(nil = 继承视图默认)。取代 overrideStyleJSON(后续阶段删旧列)。
    var styleShape: String?
    var styleFillHex: String?
    var styleStrokeHex: String?
    var styleGlyph: String?
    var styleGlyphHex: String?
    var styleSize: Int?
    var styleLabelVisible: Bool?
    var photoIds: [UUID] = []
    var contactPhone: String?
    var contactWechat: String?
    var contactName: String?
    var sourceUrl: String?

    var category: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
