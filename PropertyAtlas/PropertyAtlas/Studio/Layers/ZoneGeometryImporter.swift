#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit
import UIKit

enum ZoneGeometryImporter {
    enum ImporterError: Error {
        case unsupportedStage(String)
        case imageMissing(String)
    }

    static func makeOverlay(
        for zone: Area,
        imageProvider: (String) -> UIImage?
    ) throws -> MKOverlay {
        switch zone.legacyGeometryStage {
        case "raster":
            let r = try Area.decodeRaster(zone.legacyGeometry)
            guard let img = imageProvider(r.image) else { throw ImporterError.imageMissing(r.image) }
            return CalibratedImageOverlay(image: img, corners: r.corners)
        case "hull", "geojson":
            let coords = try GeoJSONHelper.decodePolygon(zone.legacyGeometry)
            let poly = MKPolygon(coordinates: coords, count: coords.count)
            poly.title = ZoneColorPalette.hex(for: zone.name) // hex color → renderer
            poly.subtitle = zone.legacyTier // kept for reference
            return poly
        default:
            throw ImporterError.unsupportedStage(zone.legacyGeometryStage)
        }
    }

    static func bundledImage(named: String) -> UIImage? {
        let base = named.replacingOccurrences(of: ".png", with: "")
        guard let url = Bundle.main.url(forResource: base, withExtension: "png", subdirectory: "StudioRasters")
            ?? Bundle.main.url(forResource: base, withExtension: "png")
        else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
#endif
