import Foundation

/// 决定地图文字标签是否放行。纯逻辑(无 MapKit),便于单测;Coordinator 在 region settle 时消费。
/// 规则:视口内可见 pin 少于 threshold → 无视 zoom 强制显示(稀疏时密度不成问题);
///       否则按 zoom 是否到 minZoom 门控(密集城市概览隐藏,放大街区显示)。
enum LabelGate {
    static func allowed(visiblePinCount: Int, zoom: Double, minZoom: Double, threshold: Int = 10) -> Bool {
        visiblePinCount < threshold || zoom >= minZoom
    }
}
