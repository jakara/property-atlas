import Foundation
import Testing
@testable import PropertyAtlas

struct StyleDefaultsTests {
    @Test func builtinPinFallbacksAreSensible() {
        let defaults = StyleDefaults.builtinPin(for: "compound")
        #expect(defaults.shape == .circle)
        #expect(defaults.size == 22)
        #expect(defaults.labelVisible == false)
    }

    @Test func parseThemeDefaultsReturnsPerTypePartials() throws {
        let json = "{\"compound\":{\"fillHex\":\"#FF3B30\",\"shape\":\"circle\"},\"school\":{\"fillHex\":\"#34C759\"}}"
        let parsed = try StyleDefaults.parseThemeDefaults(json)
        #expect(parsed.pin["compound"]?.fillHex == "#FF3B30")
        #expect(parsed.pin["compound"]?.shape == .circle)
        #expect(parsed.pin["school"]?.fillHex == "#34C759")
        #expect(parsed.pin["poi"] == nil)
    }

    @Test func parseThemeDefaultsEmptyJSONReturnsEmptyMaps() throws {
        let parsed = try StyleDefaults.parseThemeDefaults("{}")
        #expect(parsed.pin.isEmpty)
        #expect(parsed.area.isEmpty)
    }

    @Test func parseThemeDefaultsAreaSection() throws {
        let json = "{\"area\":{\"fillOpacity\":0.35,\"strokeHex\":\"#000000\"}}"
        let parsed = try StyleDefaults.parseThemeDefaults(json)
        #expect(parsed.area["area"]?.fillOpacity == 0.35)
        #expect(parsed.area["area"]?.strokeHex == "#000000")
    }
}
