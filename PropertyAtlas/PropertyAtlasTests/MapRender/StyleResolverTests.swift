import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleResolverTests {
    @Test func pinFallsBackToBuiltinWhenNoViewStyle() {
        let school = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(entity: school.styleEntity, viewStyle: nil)
        let builtin = StyleDefaults.builtinPin(for: "school")
        #expect(resolved == builtin)
    }

    @Test func viewStyleOverridesBuiltin() {
        let viewStyle = ViewEntityStyle(datasetId: UUID(), layerId: UUID(), entityType: "school")
        viewStyle.fillHex = "#FF0000"
        viewStyle.shape = "hexagon"
        let school = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(entity: school.styleEntity, viewStyle: viewStyle)
        #expect(resolved.fillHex == "#FF0000")
        #expect(resolved.shape == .hexagon)
    }

    @Test func entityOverrideAppliesLast() {
        let viewStyle = ViewEntityStyle(datasetId: UUID(), layerId: UUID(), entityType: "school")
        viewStyle.fillHex = "#000000"
        let school = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        school.styleFillHex = "#7C3AED"
        school.styleGlyph = "★"
        let resolved = StyleResolver.resolvePin(entity: school.styleEntity, viewStyle: viewStyle)
        #expect(resolved.fillHex == "#7C3AED")
        #expect(resolved.glyph == "★")
    }

    @Test func resolveAreaUsesViewStyle() {
        let viewStyle = ViewEntityStyle(datasetId: UUID(), layerId: UUID(), entityType: "area")
        viewStyle.fillHex = "#FF0000"
        viewStyle.fillOpacity = 0.35
        let area = Area(datasetId: UUID(), name: "片区1", geometryKind: "polygon", geometryJSON: "{}")
        let resolved = StyleResolver.resolveArea(entity: area.styleEntity, viewStyle: viewStyle)
        #expect(resolved.fillHex == "#FF0000")
        #expect(resolved.fillOpacity == 0.35)
    }

    @Test func areaEntityOverrideBeatsViewStyle() {
        let viewStyle = ViewEntityStyle(datasetId: UUID(), layerId: UUID(), entityType: "area")
        viewStyle.fillHex = "#FF0000"
        let area = Area(datasetId: UUID(), name: "片区1", geometryKind: "polygon", geometryJSON: "{}")
        area.styleFillHex = "#00FF00"
        let resolved = StyleResolver.resolveArea(entity: area.styleEntity, viewStyle: viewStyle)
        #expect(resolved.fillHex == "#00FF00")
    }
}
