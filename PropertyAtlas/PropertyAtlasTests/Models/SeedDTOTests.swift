import CoreLocation
import Foundation
import Testing
@testable import PropertyAtlas

@Suite("Seed DTOs")
struct SeedDTOTests {
    @Test("ZoneSeed default geometryStage is hull")
    func zoneDefaultStage() {
        let z = ZoneSeed(id: UUID(), name: "t", primaryDistrict: "和平区", geometry: "{}")
        #expect(z.geometryStage == "hull")
        #expect(z.tier == "普通")
        #expect(z.fillOpacity == 0.2)
    }

    @Test("ZoneSeed.decodeRaster parses image+corners")
    func zoneDecodeRaster() throws {
        let json = #"{"image":"和平区学片.png","corners":[[39.13,117.20],[39.13,117.22],[39.12,117.22],[39.12,117.20]]}"#
        let r = try ZoneSeed.decodeRaster(json)
        #expect(r.image == "和平区学片.png")
        #expect(r.corners.count == 4)
        #expect(r.corners[0].latitude == 39.13)
        #expect(r.corners[0].longitude == 117.20)
    }

    @Test("SchoolSeed defaults: lat/lon nil, public true")
    func schoolDefaults() {
        let s = SchoolSeed(id: UUID(), name: "Test", district: "和平区")
        #expect(s.lat == nil)
        #expect(s.lon == nil)
        #expect(s.isPublicSchool == true)
        #expect(s.type == "小学")
    }

    @Test("Seed structs are Codable round-trip")
    func codableRoundTrip() throws {
        var c = CompoundSeed(id: UUID(), name: "中海", district: "河北区")
        c.finishType = "精装"
        c.isNewHouse = false
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(CompoundSeed.self, from: data)
        #expect(back.name == "中海")
        #expect(back.finishType == "精装")
        #expect(back.isNewHouse == false)
    }
}
