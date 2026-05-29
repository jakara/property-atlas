import CoreGraphics
import Foundation

enum PinShape: String, Codable, Equatable, CaseIterable {
    case circle, square, hexagon, diamond, triangle, star
}

struct PinStyle: Equatable {
    var shape: PinShape
    var fillHex: String
    var strokeHex: String
    var glyph: String?
    var glyphHex: String
    var size: CGFloat
    var labelVisible: Bool
}

struct PartialPinStyle: Equatable {
    var shape: PinShape?
    var fillHex: String?
    var strokeHex: String?
    var glyph: String?
    var glyphHex: String?
    var size: CGFloat?
    var labelVisible: Bool?

    init(
        shape: PinShape? = nil,
        fillHex: String? = nil,
        strokeHex: String? = nil,
        glyph: String? = nil,
        glyphHex: String? = nil,
        size: CGFloat? = nil,
        labelVisible: Bool? = nil
    ) {
        self.shape = shape
        self.fillHex = fillHex
        self.strokeHex = strokeHex
        self.glyph = glyph
        self.glyphHex = glyphHex
        self.size = size
        self.labelVisible = labelVisible
    }

    mutating func merge(_ other: PartialPinStyle) {
        if let shape = other.shape { self.shape = shape }
        if let fillHex = other.fillHex { self.fillHex = fillHex }
        if let strokeHex = other.strokeHex { self.strokeHex = strokeHex }
        if let glyph = other.glyph { self.glyph = glyph }
        if let glyphHex = other.glyphHex { self.glyphHex = glyphHex }
        if let size = other.size { self.size = size }
        if let labelVisible = other.labelVisible { self.labelVisible = labelVisible }
    }

    func finalize(default base: PinStyle) -> PinStyle {
        PinStyle(
            shape: shape ?? base.shape,
            fillHex: fillHex ?? base.fillHex,
            strokeHex: strokeHex ?? base.strokeHex,
            glyph: glyph ?? base.glyph,
            glyphHex: glyphHex ?? base.glyphHex,
            size: size ?? base.size,
            labelVisible: labelVisible ?? base.labelVisible
        )
    }
}
