import CoreGraphics
import Foundation

struct AreaStyle: Equatable {
    var fillHex: String
    var fillOpacity: Double
    var strokeHex: String
    var strokeWidth: Double
    var labelVisible: Bool
}

struct PartialAreaStyle: Equatable {
    var fillHex: String?
    var fillOpacity: Double?
    var strokeHex: String?
    var strokeWidth: Double?
    var labelVisible: Bool?

    init(
        fillHex: String? = nil,
        fillOpacity: Double? = nil,
        strokeHex: String? = nil,
        strokeWidth: Double? = nil,
        labelVisible: Bool? = nil
    ) {
        self.fillHex = fillHex
        self.fillOpacity = fillOpacity
        self.strokeHex = strokeHex
        self.strokeWidth = strokeWidth
        self.labelVisible = labelVisible
    }

    mutating func merge(_ other: PartialAreaStyle) {
        if let value = other.fillHex { fillHex = value }
        if let value = other.fillOpacity { fillOpacity = value }
        if let value = other.strokeHex { strokeHex = value }
        if let value = other.strokeWidth { strokeWidth = value }
        if let value = other.labelVisible { labelVisible = value }
    }

    func finalize(default base: AreaStyle) -> AreaStyle {
        AreaStyle(
            fillHex: fillHex ?? base.fillHex,
            fillOpacity: fillOpacity ?? base.fillOpacity,
            strokeHex: strokeHex ?? base.strokeHex,
            strokeWidth: strokeWidth ?? base.strokeWidth,
            labelVisible: labelVisible ?? base.labelVisible
        )
    }
}
