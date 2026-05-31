// PropertyAtlasTests/MapRender/EdgeLineFactoryTests.swift
import CoreLocation
import MapKit
import Testing
@testable import PropertyAtlas

struct EdgeLineFactoryTests {
    @Test func buildsPolylinePerSegment() {
        let segs = [
            (
                CLLocationCoordinate2D(latitude: 39.1, longitude: 117.1),
                CLLocationCoordinate2D(latitude: 39.2, longitude: 117.2)
            ),
            (
                CLLocationCoordinate2D(latitude: 39.0, longitude: 117.0),
                CLLocationCoordinate2D(latitude: 39.3, longitude: 117.3)
            ),
        ]
        let lines = EdgeLineFactory.polylines(from: segs)
        #expect(lines.count == 2)
        #expect(lines[0].pointCount == 2)
    }

    @Test func emptyInputEmptyOutput() {
        #expect(EdgeLineFactory.polylines(from: []).isEmpty)
    }
}
