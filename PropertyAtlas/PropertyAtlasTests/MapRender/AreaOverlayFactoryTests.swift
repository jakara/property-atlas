#if targetEnvironment(macCatalyst)
import Foundation
import MapKit
import Testing
@testable import PropertyAtlas

@MainActor
struct AreaOverlayFactoryTests {
    @Test func polygonAreaProducesMKPolygonWithStyle() {
        let a = Area(
            datasetId: UUID(),
            name: "片区1",
            geometryKind: "polygon",
            geometryJSON: ##"{"type":"Polygon","coordinates":[[[117.1,39.1],[117.2,39.1],[117.2,39.2],[117.1,39.2],[117.1,39.1]]]}"##
        )
        let style = AreaStyle(
            fillHex: "#FF0000",
            fillOpacity: 0.3,
            strokeHex: "#000000",
            strokeWidth: 1,
            labelVisible: false
        )
        let result = AreaOverlayFactory.makeOverlay(for: a, style: style)
        let polygon = result?.overlay as? MKPolygon
        #expect(polygon != nil)
        #expect(polygon?.pointCount == 5)
        #expect(result?.style.fillHex == "#FF0000")
    }

    @Test func invalidGeometryReturnsNil() {
        let a = Area(
            datasetId: UUID(),
            name: "broken",
            geometryKind: "polygon",
            geometryJSON: "{broken json"
        )
        let style = AreaStyle(
            fillHex: "#FFF",
            fillOpacity: 0.2,
            strokeHex: "#000",
            strokeWidth: 1,
            labelVisible: false
        )
        #expect(AreaOverlayFactory.makeOverlay(for: a, style: style) == nil)
    }
}
#endif
