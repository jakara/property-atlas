import CoreLocation
import Foundation
import Testing
@testable import PropertyAtlas

@Suite("LegacySchoolZone geometry stage")
struct LegacySchoolZoneGeometryStageTests {
    @Test("default stage is hull")
    func defaultStage() {
        let z = LegacySchoolZone(name: "test", primaryDistrict: "和平区", geometry: "{}")
        #expect(z.geometryStage == "hull")
    }

    @Test("decodeRasterGeometry parses image+corners")
    func decodeRaster() throws {
        let json = #"{"image":"和平区学片.png","corners":[[39.13,117.20],[39.13,117.22],[39.12,117.22],[39.12,117.20]]}"#
        let r = try LegacySchoolZone.decodeRaster(json)
        #expect(r.image == "和平区学片.png")
        #expect(r.corners.count == 4)
        #expect(r.corners[0].latitude == 39.13)
        #expect(r.corners[0].longitude == 117.20)
    }
}
