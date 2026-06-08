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

/// 折线区域(geometryKind="line")渲染:用 AreaStyle 描边,无填充。
/// 描边色优先用 strokeHex;若仍是默认白,退用 fillHex(线通常只设主色)。
final class AreaLineRenderer: MKPolylineRenderer {
    init(polyline: MKPolyline, style: AreaStyle) {
        super.init(polyline: polyline)
        let stroke = HexColor.parse(style.strokeHex) ?? HexColor.parse(style.fillHex) ?? .systemTeal
        strokeColor = stroke
        lineWidth = max(CGFloat(style.strokeWidth), 3)
        lineCap = .round
        lineJoin = .round
    }
}
#endif
