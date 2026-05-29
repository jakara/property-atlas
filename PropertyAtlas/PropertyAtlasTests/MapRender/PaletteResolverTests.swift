import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct PaletteResolverTests {
    @Test func paletteByIdYieldsColorFromList() throws {
        let palette = Palette(name: "rainbow", colorsHex: ["#FF0000", "#00FF00", "#0000FF"])
        let e1 = try StyleEntity(
            entityType: "area",
            id: #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111")),
            baseFields: [:],
            customFields: [:]
        )
        let c1 = PaletteResolver.resolve(palette: palette, entity: e1, keyField: nil)
        #expect(palette.colorsHex.contains(c1))
    }

    @Test func sameKeyAlwaysYieldsSameColor() {
        let palette = Palette(name: "rainbow", colorsHex: ["#FF0000", "#00FF00", "#0000FF"])
        let e = StyleEntity(
            entityType: "area",
            id: UUID(),
            baseFields: ["name": .string("第一学片")],
            customFields: [:]
        )
        let a = PaletteResolver.resolve(palette: palette, entity: e, keyField: "name")
        let b = PaletteResolver.resolve(palette: palette, entity: e, keyField: "name")
        #expect(a == b)
    }

    @Test func missingKeyFallsBackToIdHash() {
        let palette = Palette(name: "rainbow", colorsHex: ["#FF0000"])
        let e = StyleEntity(
            entityType: "area",
            id: UUID(),
            baseFields: [:],
            customFields: [:]
        )
        let c = PaletteResolver.resolve(palette: palette, entity: e, keyField: "nonexistent")
        #expect(c == "#FF0000")
    }

    @Test func emptyPaletteReturnsFallbackHex() {
        let palette = Palette(name: "empty", colorsHex: [])
        let e = StyleEntity(
            entityType: "area",
            id: UUID(),
            baseFields: [:],
            customFields: [:]
        )
        let c = PaletteResolver.resolve(palette: palette, entity: e, keyField: nil)
        #expect(c == PaletteResolver.fallbackHex)
    }
}
