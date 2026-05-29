import Foundation
import Testing
@testable import PropertyAtlas

struct PinStyleTests {
    @Test func partialMergeKeepsNewerNonNilValue() {
        var partial = PartialPinStyle()
        partial.fillHex = "#FF0000"
        partial.shape = .circle
        let later = PartialPinStyle(fillHex: "#00FF00")
        partial.merge(later)
        #expect(partial.fillHex == "#00FF00")
        #expect(partial.shape == .circle)
    }

    @Test func partialFinalizeFallsBackToDefault() {
        var partial = PartialPinStyle()
        partial.fillHex = "#ABCDEF"
        let def = PinStyle(
            shape: .square,
            fillHex: "#000000",
            strokeHex: "#FFFFFF",
            glyph: nil,
            glyphHex: "#FFFFFF",
            size: 22,
            labelVisible: false
        )
        let final = partial.finalize(default: def)
        #expect(final.fillHex == "#ABCDEF")
        #expect(final.shape == .square)
        #expect(final.size == 22)
    }

    @Test func pinShapeRawValuesMatchSpec() {
        #expect(PinShape.circle.rawValue == "circle")
        #expect(PinShape.square.rawValue == "square")
        #expect(PinShape.hexagon.rawValue == "hexagon")
        #expect(PinShape.diamond.rawValue == "diamond")
        #expect(PinShape.triangle.rawValue == "triangle")
        #expect(PinShape.star.rawValue == "star")
        #expect(PinShape(rawValue: "circle") == .circle)
    }
}
