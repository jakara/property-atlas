import CoreLocation
import Foundation
import SwiftData

@Model final class UserArea {
    var id: UUID = UUID()
    var name: String = ""
    var kind: String = "custom"
    var geometry: String = ""
    var strokeColorHex: String = "#007AFF"
    var fillColorHex: String = "#007AFF"
    var fillOpacity: Double = 0.15
    var referenceZoneId: UUID?
    var areaDescription: String?
    var isVisible: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String, kind: String = "custom", geometry: String) {
        self.name = name
        self.kind = kind
        self.geometry = geometry
    }

    var decodedCoordinates: [CLLocationCoordinate2D] {
        (try? GeoJSONHelper.decodePolygon(geometry)) ?? []
    }
}
