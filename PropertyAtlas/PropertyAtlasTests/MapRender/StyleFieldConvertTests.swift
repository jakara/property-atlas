import CoreGraphics
import Foundation
import Testing
@testable import PropertyAtlas

struct StyleFieldConvertTests {
    @Test func viewStyleToPinPartialMapsFields() {
        let style = ViewEntityStyle(datasetId: UUID(), layerId: UUID(), entityType: "compound")
        style.shape = "square"
        style.fillHex = "#FF0000"
        style.size = 30
        style.labelVisible = true
        let partial = StyleFieldConvert.pinPartial(
            shape: style.shape, fillHex: style.fillHex, strokeHex: style.strokeHex,
            glyph: style.glyph, glyphHex: style.glyphHex, size: style.size, labelVisible: style.labelVisible
        )
        #expect(partial.shape == PinShape.square)
        #expect(partial.fillHex == "#FF0000")
        #expect(partial.size == CGFloat(30))
        #expect(partial.labelVisible == true)
        #expect(partial.glyph == nil)
    }

    @Test func badShapeStringBecomesNil() {
        let partial = StyleFieldConvert.pinPartial(
            shape: "not-a-shape", fillHex: nil, strokeHex: nil,
            glyph: nil, glyphHex: nil, size: nil, labelVisible: nil
        )
        #expect(partial.shape == nil)
    }

    @Test func areaPartialMapsFields() {
        let partial = StyleFieldConvert.areaPartial(
            fillHex: "#00FF00", fillOpacity: 0.5, strokeHex: nil, strokeWidth: 2.0, labelVisible: false
        )
        #expect(partial.fillHex == "#00FF00")
        #expect(partial.fillOpacity == 0.5)
        #expect(partial.strokeWidth == 2.0)
        #expect(partial.labelVisible == false)
        #expect(partial.strokeHex == nil)
    }
}
