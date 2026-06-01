import Testing
import Foundation
@testable import PropertyAtlas

struct ViewConfigCodecTests {
    @Test func primaryRoundTrips() {
        let dim = MapDimension(kind: .field, fieldKey: "grade", fieldSource: "base")
        let pf = PrimaryFilter(conditions: [], groupBy: dim)
        let json = ViewConfigCodec.encodePrimary(pf)
        let back = ViewConfigCodec.decodePrimary(json)
        #expect(back.groupBy?.fieldKey == "grade")
    }
    @Test func decodeBadPrimaryYieldsEmpty() {
        let pf = ViewConfigCodec.decodePrimary("not json")
        #expect(pf.conditions.isEmpty)
        #expect(pf.groupBy == nil)
    }
    @Test func normalsRoundTrip() {
        let nf = NormalFilter(name: "学段", dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base"))
        let json = ViewConfigCodec.encodeNormals([nf])
        let back = ViewConfigCodec.decodeNormals(json)
        #expect(back.count == 1)
        #expect(back.first?.name == "学段")
    }
    @Test func decodeBadNormalsYieldsEmpty() {
        #expect(ViewConfigCodec.decodeNormals("garbage").isEmpty)
    }
}
