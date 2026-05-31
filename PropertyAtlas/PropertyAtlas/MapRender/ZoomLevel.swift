// PropertyAtlas/PropertyAtlas/MapRender/ZoomLevel.swift
import Foundation
import MapKit

enum ZoomLevel {
    /// 由经度跨度估算 zoom level [0..21]。lonDelta 越小 zoom 越高。
    static func from(region: MKCoordinateRegion) -> Double {
        let lonDelta = max(region.span.longitudeDelta, 1e-6)
        let z = log2(360.0 / lonDelta)
        return min(max(z, 0), 21)
    }
}
