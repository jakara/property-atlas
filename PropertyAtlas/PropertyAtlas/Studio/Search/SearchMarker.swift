#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit

/// 外部搜索选中后的临时地图标记(非 @Model,运行时态)。
struct SearchMarker: Equatable {
    let coordinate: CLLocationCoordinate2D
    let name: String

    static func == (lhs: SearchMarker, rhs: SearchMarker) -> Bool {
        lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

enum SearchMarkerFactory {
    /// 区别于实体 pin 的哨兵类型/ID。onSchoolSelect 命中此 ID 时不做 select。
    static let markerType = "__searchMarker"
    static let markerId = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF))

    static func annotation(for marker: SearchMarker) -> PinAnnotation {
        let style = PinStyle(
            shape: .circle, fillHex: "#D9965A", strokeHex: "#FFFFFF",
            glyph: nil, glyphHex: "#FFFFFF", size: 18, labelVisible: true
        )
        return PinAnnotation(
            entityId: markerId, entityType: markerType, name: marker.name,
            coordinate: marker.coordinate, style: style
        )
    }
}
#endif
