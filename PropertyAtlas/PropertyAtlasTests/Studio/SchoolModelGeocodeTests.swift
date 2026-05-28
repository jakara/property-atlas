import Foundation
import Testing
@testable import PropertyAtlas

@Suite("School geocode fields")
struct SchoolGeocodeTests {
    @Test("school accepts lat/lon/geocodeSource/geocodeConfidence")
    func acceptsGeocode() {
        let s = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区")
        s.lat = 39.1234
        s.lon = 117.1234
        s.geocodeSource = "CLGeocoder"
        s.geocodeConfidence = "address"
        #expect(s.lat == 39.1234)
        #expect(s.geocodeConfidence == "address")
    }

    @Test("default lat/lon nil")
    func defaultsNil() {
        let s = LegacySchool(name: "Test", type: "小学", district: "和平区")
        #expect(s.lat == nil)
        #expect(s.lon == nil)
    }
}
