import CoreGraphics
import Foundation

enum StyleDefaults {
    struct ParsedDefaults {
        let pin: [String: PartialPinStyle]
        let area: [String: PartialAreaStyle]
    }

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

    static func parseThemeDefaults(_ json: String) throws -> ParsedDefaults {
        let decoded: [String: AnyJSON] = (try? JSONHelpers.decode(json)) ?? [:]
        var pin: [String: PartialPinStyle] = [:]
        var area: [String: PartialAreaStyle] = [:]
        for (key, value) in decoded {
            guard case let .object(dict) = value else { continue }
            switch key {
            case "compound", "school", "poi":
                pin[key] = makePinPartial(from: dict)
            case "area":
                area[key] = makeAreaPartial(from: dict)
            default:
                continue
            }
        }
        return ParsedDefaults(pin: pin, area: area)
    }

    private static func makePinPartial(from dict: [String: AnyJSON]) -> PartialPinStyle {
        var partial = PartialPinStyle()
        if case let .string(value) = dict["shape"] { partial.shape = PinShape(rawValue: value) }
        if case let .string(value) = dict["fillHex"] { partial.fillHex = value }
        if case let .string(value) = dict["strokeHex"] { partial.strokeHex = value }
        if case let .string(value) = dict["glyph"] { partial.glyph = value }
        if case let .string(value) = dict["glyphHex"] { partial.glyphHex = value }
        if case let .int(value) = dict["size"] { partial.size = CGFloat(value) }
        if case let .double(value) = dict["size"] { partial.size = CGFloat(value) }
        if case let .bool(value) = dict["labelVisible"] { partial.labelVisible = value }
        return partial
    }

    private static func makeAreaPartial(from dict: [String: AnyJSON]) -> PartialAreaStyle {
        var partial = PartialAreaStyle()
        if case let .string(value) = dict["fillHex"] { partial.fillHex = value }
        if case let .double(value) = dict["fillOpacity"] { partial.fillOpacity = value }
        if case let .int(value) = dict["fillOpacity"] { partial.fillOpacity = Double(value) }
        if case let .string(value) = dict["strokeHex"] { partial.strokeHex = value }
        if case let .double(value) = dict["strokeWidth"] { partial.strokeWidth = value }
        if case let .int(value) = dict["strokeWidth"] { partial.strokeWidth = Double(value) }
        if case let .bool(value) = dict["labelVisible"] { partial.labelVisible = value }
        return partial
    }
}
