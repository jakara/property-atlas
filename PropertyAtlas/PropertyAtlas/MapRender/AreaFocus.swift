import CoreLocation
import Foundation

/// 片区聚焦:多边形顶点 → 包围盒中心 + 合适的相机视距(fromDistance),用于选中片区时自动 focus。
enum AreaFocus {
    struct Fit {
        let center: CLLocationCoordinate2D
        let distance: CLLocationDistance
    }

    /// 纯几何:无 polygon 顶点 → nil。距离按包围盒对角的较大边 ×1.4,下限 800m。
    static func fit(coordinates: [CLLocationCoordinate2D]) -> Fit? {
        guard !coordinates.isEmpty else { return nil }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let latMeters = (maxLat - minLat) * 111_000
        let lonMeters = (maxLon - minLon) * 111_000 * cos(center.latitude * .pi / 180)
        let span = max(latMeters, lonMeters)
        return Fit(center: center, distance: max(800, span * 1.4))
    }
}
