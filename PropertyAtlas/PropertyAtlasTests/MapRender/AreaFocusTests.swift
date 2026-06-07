import CoreLocation
import Testing
@testable import PropertyAtlas

struct AreaFocusTests {
    @Test func emptyReturnsNil() {
        #expect(AreaFocus.fit(coordinates: []) == nil)
    }

    @Test func centerIsBboxMidpoint() {
        let coords = [
            CLLocationCoordinate2D(latitude: 39.0, longitude: 117.0),
            CLLocationCoordinate2D(latitude: 39.2, longitude: 117.4),
        ]
        let fit = AreaFocus.fit(coordinates: coords)
        #expect(fit != nil)
        #expect(abs((fit?.center.latitude ?? 0) - 39.1) < 1e-9)
        #expect(abs((fit?.center.longitude ?? 0) - 117.2) < 1e-9)
    }

    @Test func tinyAreaClampsToMinDistance() {
        let coords = [
            CLLocationCoordinate2D(latitude: 39.0, longitude: 117.0),
            CLLocationCoordinate2D(latitude: 39.0001, longitude: 117.0001),
        ]
        #expect(AreaFocus.fit(coordinates: coords)?.distance == 800)
    }

    @Test func largeAreaScalesBySpan() {
        let coords = [
            CLLocationCoordinate2D(latitude: 39.0, longitude: 117.0),
            CLLocationCoordinate2D(latitude: 39.1, longitude: 117.0),
        ]
        // latΔ 0.1 * 111000 ≈ 11100m, ×1.4 ≈ 15540m
        let d = AreaFocus.fit(coordinates: coords)?.distance ?? 0
        #expect(d > 15000 && d < 16000)
    }
}
