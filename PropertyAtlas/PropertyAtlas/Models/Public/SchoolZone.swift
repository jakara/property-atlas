import CoreLocation
import Foundation
import SwiftData

@Model
final class SchoolZone {
    var id: UUID = UUID()
    var name: String = "" // zone_name
    var tier: String = "普通" // 聚合 (max coarse tier of members)
    var primaryDistrict: String = ""
    var geometry: String = "" // GeoJSON polygon or raster JSON, 编码 string
    var geometryStage: String = "hull"
    var geometrySimplified: String?
    var residencyYears: Int?
    var strokeColorHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String? // areas_text
    var note: String?
    var structureJSON: String? // 完整 structure (JSON-encoded)
    var middleSchoolPoolJSON: String? // 原始 name list (JSON-encoded for verbatim)

    // sensitive subobject
    var sensitiveHighlight: String?
    var sensitiveSource: String?
    var sensitiveNote: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        tier: String = "普通",
        primaryDistrict: String,
        geometry: String,
        geometryStage: String = "hull"
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.primaryDistrict = primaryDistrict
        self.geometry = geometry
        self.geometryStage = geometryStage
    }

    var decodedCoordinates: [CLLocationCoordinate2D] {
        (try? GeoJSONHelper.decodePolygon(geometry)) ?? []
    }

    struct RasterGeometry {
        let image: String
        let corners: [CLLocationCoordinate2D]
    }

    static func decodeRaster(_ json: String) throws -> RasterGeometry {
        guard let data = json.data(using: .utf8) else {
            throw GeoJSONHelper.GeoJSONError.invalidUTF8
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let image = dict["image"] as? String,
              let corners = dict["corners"] as? [[Double]],
              corners.count == 4
        else {
            throw GeoJSONHelper.GeoJSONError.invalidStructure
        }
        return RasterGeometry(
            image: image,
            corners: corners.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
        )
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
