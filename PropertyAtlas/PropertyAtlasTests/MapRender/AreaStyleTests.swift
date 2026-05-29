import Foundation
import Testing
@testable import PropertyAtlas

struct AreaStyleTests {
    @Test func partialAreaMergeKeepsNewerNonNil() {
        var partial = PartialAreaStyle()
        partial.fillHex = "#FF0000"
        partial.fillOpacity = 0.2
        let later = PartialAreaStyle(fillOpacity: 0.5)
        partial.merge(later)
        #expect(partial.fillHex == "#FF0000")
        #expect(partial.fillOpacity == 0.5)
    }

    @Test func partialAreaFinalizeFallsBackToDefault() {
        var partial = PartialAreaStyle()
        partial.fillOpacity = 0.4
        let baseStyle = AreaStyle(
            fillHex: "#7C3AED",
            fillOpacity: 0.2,
            strokeHex: "#FFFFFF",
            strokeWidth: 1.0,
            labelVisible: true
        )
        let final = partial.finalize(default: baseStyle)
        #expect(final.fillOpacity == 0.4)
        #expect(final.fillHex == "#7C3AED")
        #expect(final.strokeWidth == 1.0)
    }
}
