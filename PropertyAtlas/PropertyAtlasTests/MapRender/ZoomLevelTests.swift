// PropertyAtlasTests/MapRender/ZoomLevelTests.swift
import MapKit
import Testing
@testable import PropertyAtlas

struct ZoomLevelTests {
    @Test func wholeWorldIsZoomZeroish() {
        let r = MKCoordinateRegion(
            center: .init(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        )
        #expect(ZoomLevel.from(region: r) <= 1.0)
    }

    @Test func smallSpanIsHighZoom() {
        let r = MKCoordinateRegion(
            center: .init(latitude: 39.1, longitude: 117.2),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        #expect(ZoomLevel.from(region: r) > 14)
    }

    @Test func clampsTo21() {
        let r = MKCoordinateRegion(
            center: .init(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.00001, longitudeDelta: 0.00001)
        )
        #expect(ZoomLevel.from(region: r) <= 21)
    }
}
