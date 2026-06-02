import Foundation
import Testing
@testable import PropertyAtlas

@Suite("SchoolSeed geocode fields")
struct SchoolSeedGeocodeTests {
    @Test("accepts lat/lon/geocodeSource/geocodeConfidence")
    func acceptsGeocode() {
        var s = SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")
        s.lat = 39.1234
        s.lon = 117.1234
        s.geocodeSource = "CLGeocoder"
        s.geocodeConfidence = "address"
        #expect(s.lat == 39.1234)
        #expect(s.geocodeConfidence == "address")
    }

    @Test("default lat/lon nil")
    func defaultsNil() {
        let s = SchoolSeed(id: UUID(), name: "Test", district: "和平区")
        #expect(s.lat == nil)
        #expect(s.lon == nil)
    }
}
