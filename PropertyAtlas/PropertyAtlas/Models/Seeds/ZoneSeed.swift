import CoreLocation
import Foundation

/// JSON 输入 DTO(对应 zones.json,原 LegacySchoolZone)。不进 SwiftData。
struct ZoneSeed: Codable {
    var id: UUID
    var name: String
    var tier: String = "普通" // aggregateZoneTier 会覆盖
    var primaryDistrict: String
    var geometry: String
    var geometryStage: String = "hull"
    var residencyYears: Int?
    var strokeColorHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String?
    var note: String?
    var structureJSON: String?
    var middleSchoolPoolJSON: String?
    var sensitiveHighlight: String?
    var sensitiveSource: String?
    var sensitiveNote: String?

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
