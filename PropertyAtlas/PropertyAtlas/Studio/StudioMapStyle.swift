import MapKit
import UIKit

/// 底图样式预设。全局选择,经 @AppStorage 持久。
/// 「卫星」用 Hybrid(影像+标注+POI);纯影像无 POI 已弃用。
enum StudioMapStyle: String, CaseIterable, Identifiable {
    case mutedLight, mutedDark, standardFull, hybrid

    var id: String {
        rawValue
    }

    /// 容错旧值:已删的 "satellite" → 卫星(hybrid)。
    static func resolve(_ raw: String) -> StudioMapStyle {
        if raw == "satellite" { return .hybrid }
        return StudioMapStyle(rawValue: raw) ?? .mutedLight
    }

    var label: String {
        switch self {
        case .mutedLight: "静音·浅"
        case .mutedDark: "静音·深"
        case .standardFull: "标准"
        case .hybrid: "卫星"
        }
    }

    var icon: String {
        switch self {
        case .mutedLight: "sun.max"
        case .mutedDark: "moon"
        case .standardFull: "map"
        case .hybrid: "globe.americas.fill"
        }
    }

    /// 现代 MKMapConfiguration(iOS 17)。POI 由 poiFilter 控制(默认 .excludingAll 不显示)。
    func configuration(poiFilter: MKPointOfInterestFilter = .excludingAll) -> MKMapConfiguration {
        switch self {
        case .mutedLight, .mutedDark:
            let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            config.pointOfInterestFilter = poiFilter
            return config
        case .standardFull:
            let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
            config.pointOfInterestFilter = poiFilter
            return config
        case .hybrid:
            let config = MKHybridMapConfiguration(elevationStyle: .flat)
            config.pointOfInterestFilter = poiFilter
            return config
        }
    }

    /// 日夜外观(仅影响标准矢量底图;影像底图不受影响)。
    var interfaceStyle: UIUserInterfaceStyle {
        self == .mutedDark ? .dark : .light
    }
}
