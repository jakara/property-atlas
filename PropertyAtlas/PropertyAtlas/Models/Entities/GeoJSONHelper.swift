import CoreLocation
import Foundation

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

    static func decodeLine(_ geojson: String) throws -> [CLLocationCoordinate2D] {
        guard let data = geojson.data(using: .utf8) else {
            throw GeoJSONError.invalidUTF8
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let coords = dict["coordinates"] as? [[Double]]
        else {
            throw GeoJSONError.invalidStructure
        }
        return coords.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }

    static func encodeLine(_ coords: [CLLocationCoordinate2D]) throws -> String {
        let line = coords.map { [$0.longitude, $0.latitude] }
        let dict: [String: Any] = ["type": "LineString", "coordinates": line]
        let data = try JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8)!
    }

    enum GeoJSONError: Error {
        case invalidUTF8, invalidStructure
    }
}
