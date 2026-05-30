#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

final class AreaOverlayRenderer: MKPolygonRenderer {
    init(polygon: MKPolygon, style: AreaStyle) {
        super.init(polygon: polygon)
        let fill = HexColor.parse(style.fillHex) ?? .purple
        let stroke = HexColor.parse(style.strokeHex) ?? .white
        fillColor = fill.withAlphaComponent(CGFloat(style.fillOpacity))
        strokeColor = stroke
        lineWidth = CGFloat(style.strokeWidth)
    }
}
#endif
