import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleResolverTests {
    @Test func pinFallsBackToBuiltinWhenNoThemeNoRules() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [],
            palettes: [:]
        )
        let builtin = StyleDefaults.builtinPin(for: "school")
        #expect(resolved == builtin)
    }

    @Test func themeDefaultOverridesBuiltin() {
        let theme = Theme(datasetId: UUID(), name: "test")
        theme.defaultStylesJSON = ##"{"school":{"fillHex":"#FF0000","shape":"hexagon"}}"##
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: theme,
            rules: [],
            palettes: [:]
        )
        #expect(resolved.fillHex == "#FF0000")
        #expect(resolved.shape == .hexagon)
    }

    @Test func matchingFixedRuleOverridesThemeDefault() {
        let theme = Theme(datasetId: UUID(), name: "test")
        theme.defaultStylesJSON = ##"{"school":{"fillHex":"#FF0000"}}"##
        let rule = StyleRule(datasetId: UUID(), name: "重点", entityType: "school")
        rule.conditionsJSON = #"[{"field":"grade","op":"equals","value":"重点"}]"#
        rule.appliesFillHex = "#00FF00"
        rule.appliesShape = "square"
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: theme,
            rules: [rule],
            palettes: [:]
        )
        #expect(resolved.fillHex == "#00FF00")
        #expect(resolved.shape == .square)
    }

    @Test func higherPriorityRuleWinsWhenBothMatch() {
        let r1 = StyleRule(datasetId: UUID(), name: "low", entityType: "school")
        r1.conditionsJSON = "[]"
        r1.priority = 5
        r1.appliesFillHex = "#000000"
        let r2 = StyleRule(datasetId: UUID(), name: "high", entityType: "school")
        r2.conditionsJSON = "[]"
        r2.priority = 10
        r2.appliesFillHex = "#FFFFFF"
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [r1, r2],
            palettes: [:]
        )
        #expect(resolved.fillHex == "#FFFFFF")
    }

    @Test func paletteRuleResolvesFillFromPalette() {
        let palette = Palette(name: "rainbow", colorsHex: ["#FF0000", "#00FF00", "#0000FF"])
        let rule = StyleRule(datasetId: UUID(), name: "palette", entityType: "school")
        rule.conditionsJSON = "[]"
        rule.appliesFillMode = "palette"
        rule.appliesPaletteId = palette.id
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [rule],
            palettes: [palette.id: palette]
        )
        #expect(palette.colorsHex.contains(resolved.fillHex))
    }

    @Test func entityOverrideAppliesLast() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.overrideStyleJSON = ##"{"fillHex":"#7C3AED","glyph":"★"}"##
        let rule = StyleRule(datasetId: UUID(), name: "x", entityType: "school")
        rule.conditionsJSON = "[]"
        rule.appliesFillHex = "#000000"
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [rule],
            palettes: [:]
        )
        #expect(resolved.fillHex == "#7C3AED")
        #expect(resolved.glyph == "★")
    }

    @Test func resolveAreaUsesAreaPartialAndPalette() {
        let palette = Palette(name: "areas", colorsHex: ["#FF0000", "#0000FF"])
        let rule = StyleRule(datasetId: UUID(), name: "area-palette", entityType: "area")
        rule.conditionsJSON = "[]"
        rule.appliesFillMode = "palette"
        rule.appliesPaletteId = palette.id
        rule.appliesFillOpacity = 0.35
        let a = Area(datasetId: UUID(), name: "片区1", geometryKind: "polygon", geometryJSON: "{}")
        let resolved = StyleResolver.resolveArea(
            entity: a.styleEntity,
            theme: nil,
            rules: [rule],
            palettes: [palette.id: palette]
        )
        #expect(palette.colorsHex.contains(resolved.fillHex))
        #expect(resolved.fillOpacity == 0.35)
    }
}
