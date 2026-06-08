#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

/// 截屏:抓取当前 MKMapView(含 overlay/pin 渲染)为图片,放入系统剪贴板。
/// MapKitView 在 make/update 时登记 weak 引用。
enum MapSnapshot {
    weak static var mapView: MKMapView?

    @discardableResult
    @MainActor
    static func copyToClipboard() -> Bool {
        guard let v = mapView, v.bounds.width > 0, v.bounds.height > 0 else { return false }
        let renderer = UIGraphicsImageRenderer(bounds: v.bounds)
        let image = renderer.image { _ in
            v.drawHierarchy(in: v.bounds, afterScreenUpdates: true)
        }
        UIPasteboard.general.image = image
        return true
    }
}
#endif
