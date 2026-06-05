import CoreGraphics
import Foundation

@MainActor
enum StyleResolver {
    static func resolvePin(
        entity: StyleEntity,
        viewStyle: ViewEntityStyle?,
        groupFillHex: String? = nil
    ) -> PinStyle {
        let base = StyleDefaults.builtinPin(for: entity.entityType)
        var partial = PartialPinStyle()
        if let viewStyle {
            partial.merge(StyleFieldConvert.pinPartial(
                shape: viewStyle.shape, fillHex: viewStyle.fillHex, strokeHex: viewStyle.strokeHex,
                glyph: viewStyle.glyph, glyphHex: viewStyle.glyphHex,
                size: viewStyle.size, labelVisible: viewStyle.labelVisible
            ))
        }
        if let groupFillHex { partial.fillHex = groupFillHex }
        partial.merge(entity.overridePin)
        return partial.finalize(default: base)
    }

    static func resolveArea(
        entity: StyleEntity,
        viewStyle: ViewEntityStyle?
    ) -> AreaStyle {
        let base = StyleDefaults.builtinArea()
        var partial = PartialAreaStyle()
        if let viewStyle {
            partial.merge(StyleFieldConvert.areaPartial(
                fillHex: viewStyle.fillHex, fillOpacity: viewStyle.fillOpacity,
                strokeHex: viewStyle.strokeHex, strokeWidth: viewStyle.strokeWidth,
                labelVisible: viewStyle.labelVisible
            ))
        }
        partial.merge(entity.overrideArea)
        return partial.finalize(default: base)
    }
}
