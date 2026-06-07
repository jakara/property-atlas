import MapKit
import UIKit

/// 底图样式预设(类型 × 日夜)。全局选择,经 @AppStorage 持久。
enum StudioMapStyle: String, CaseIterable, Identifiable {
    case mutedLight, mutedDark, standardFull, satellite, hybrid

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .mutedLight: "静音·浅"
        case .mutedDark: "静音·深"
        case .standardFull: "标准"
        case .satellite: "卫星"
        case .hybrid: "混合"
        }
    }

    var icon: String {
        switch self {
        case .mutedLight: "sun.max"
        case .mutedDark: "moon"
        case .standardFull: "map"
        case .satellite: "globe.americas"
        case .hybrid: "globe.americas.fill"
        }
    }

    /// 现代 MKMapConfiguration(iOS 17)。POI 由 poiFilter 控制(默认 .excludingAll 不显示,
    /// 与自家数据叠加不打架)。纯影像(卫星)不接受 POI filter。
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
        case .satellite:
            return MKImageryMapConfiguration(elevationStyle: .flat)
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
