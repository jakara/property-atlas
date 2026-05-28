import Foundation
import SwiftData
import Testing

@testable import PropertyAtlas

@MainActor
struct PaletteTests {
    @Test func palettePersists() throws {
        let container = try TestContainer.makeInMemory(for: [Palette.self])
        let ctx = ModelContext(container)
        let palette = Palette(
            name: "default-rainbow",
            colorsHex: [
                "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#5AC8FA",
                "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E"
            ],
            builtIn: true
        )
        ctx.insert(palette)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Palette>())
        #expect(all.first?.colorsHex.count == 10)
        #expect(all.first?.builtIn == true)
    }
}
