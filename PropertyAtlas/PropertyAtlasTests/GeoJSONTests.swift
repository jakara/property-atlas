import CoreLocation
import Testing
@testable import PropertyAtlas

struct GeoJSONTests {
    @Test func polygonCoordinatesRoundtrip() throws {
        let geojson = """
        {"type":"Polygon","coordinates":[[[117.15,39.10],[117.16,39.10],[117.16,39.11],[117.15,39.10]]]}
        """
        let coords = try GeoJSONHelper.decodePolygon(geojson)
        #expect(coords.count == 4)
        #expect(abs(coords[0].longitude - 117.15) < 0.0001)
        #expect(abs(coords[0].latitude - 39.10) < 0.0001)
    }
}
