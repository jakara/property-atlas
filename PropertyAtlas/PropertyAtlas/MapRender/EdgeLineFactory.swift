// PropertyAtlas/PropertyAtlas/MapRender/EdgeLineFactory.swift
import CoreLocation
import MapKit

enum EdgeLineFactory {
    static func polylines(from segments: [(CLLocationCoordinate2D, CLLocationCoordinate2D)]) -> [MKPolyline] {
        segments.map { seg in
            var coords = [seg.0, seg.1]
            return MKPolyline(coordinates: &coords, count: 2)
        }
    }
}
