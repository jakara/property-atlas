import CoreGraphics
import Foundation

enum StyleDefaults {
    static func builtinPin(for entityType: String) -> PinStyle {
        PinStyle(
            shape: defaultShape(for: entityType),
            fillHex: "#A8A8A8",
            strokeHex: "#FFFFFF",
            glyph: nil,
            glyphHex: "#FFFFFF",
            size: 22,
            labelVisible: false
        )
    }

    static func builtinArea() -> AreaStyle {
        AreaStyle(
            fillHex: "#7C3AED",
            fillOpacity: 0.2,
            strokeHex: "#FFFFFF",
            strokeWidth: 1.0,
            labelVisible: false
        )
    }

    private static func defaultShape(for entityType: String) -> PinShape {
        switch entityType {
        case "compound": .circle
        case "school": .square
        case "poi": .triangle
        default: .circle
        }
    }
}
