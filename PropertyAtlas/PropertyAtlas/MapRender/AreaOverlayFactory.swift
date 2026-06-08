#if targetEnvironment(macCatalyst)
import Foundation
import MapKit

enum AreaOverlayFactory {
    struct Result {
        let overlay: MKOverlay
        let style: AreaStyle
        let areaId: UUID
    }

    static func makeOverlay(for area: Area, style: AreaStyle) -> Result? {
        switch area.geometryKind {
        case "polygon":
            guard let coords = decodePolygon(area.geometryJSON) else { return nil }
            let polygon = MKPolygon(coordinates: coords, count: coords.count)
            polygon.title = area.name
            return Result(overlay: polygon, style: style, areaId: area.id)
        case "line":
            guard let lines = try? GeoJSONHelper.decodeLines(area.geometryJSON) else { return nil }
            let polys = lines.filter { $0.count >= 2 }.map { MKPolyline(coordinates: $0, count: $0.count) }
            guard !polys.isEmpty else { return nil }
            if polys.count == 1 {
                polys[0].title = area.name
                return Result(overlay: polys[0], style: style, areaId: area.id)
            }
            // 多段(MultiLineString):各 OSM way 各自成线,不缝合 → 无假连线。
            return Result(overlay: MKMultiPolyline(polys), style: style, areaId: area.id)
        case "raster":
            return nil
        default:
            return nil
        }
    }

    private static func decodePolygon(_ json: String) -> [CLLocationCoordinate2D]? {
        guard let data = json.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any],
              let coords = dict["coordinates"] as? [[[Double]]],
              let ring = coords.first
        else { return nil }
        return ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }
}
#endif
