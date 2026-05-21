import CoreLocation
import SwiftData

@Model
final class SchoolZone {
    var id: UUID = UUID()
    var name: String = ""
    var tier: String = "普通"
    var primaryDistrict: String = ""
    var geometry: String = ""
    var geometrySimplified: String?
    var residencyYears: Int?
    var strokeColorHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        tier: String = "普通",
        primaryDistrict: String,
        geometry: String
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.primaryDistrict = primaryDistrict
        self.geometry = geometry
    }

    var decodedCoordinates: [CLLocationCoordinate2D] {
        (try? GeoJSONHelper.decodePolygon(geometry)) ?? []
    }
}

enum GeoJSONHelper {
    static func decodePolygon(_ geojson: String) throws -> [CLLocationCoordinate2D] {
        guard let data = geojson.data(using: .utf8) else {
            throw GeoJSONError.invalidUTF8
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let coords = dict["coordinates"] as? [[[Double]]],
              let ring = coords.first
        else {
            throw GeoJSONError.invalidStructure
        }
        return ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }

    static func encodePolygon(_ coords: [CLLocationCoordinate2D]) throws -> String {
        let ring = coords.map { [$0.longitude, $0.latitude] }
        let dict: [String: Any] = ["type": "Polygon", "coordinates": [ring]]
        let data = try JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8)!
    }

    enum GeoJSONError: Error {
        case invalidUTF8, invalidStructure
    }
}
