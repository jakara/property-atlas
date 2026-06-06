import CoreGraphics
import Foundation

@MainActor
enum StyleResolver {
    static func resolvePin(
        entity: StyleEntity,
        viewStyle: ViewEntityStyle?,
        rules: [ResolvedStyleRule] = [],
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
        for rule in rules where rule.enabled && matches(rule, entity) {
            partial.merge(rule.pinPartial)
        }
        if let groupFillHex { partial.fillHex = groupFillHex }
        partial.merge(entity.overridePin)
        return partial.finalize(default: base)
    }

    static func resolveArea(
        entity: StyleEntity,
        viewStyle: ViewEntityStyle?,
        rules: [ResolvedStyleRule] = []
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
        for rule in rules where rule.enabled && matches(rule, entity) {
            partial.merge(rule.areaPartial)
        }
        partial.merge(entity.overrideArea)
        return partial.finalize(default: base)
    }

    /// 规则全部条件 AND 命中(空条件 → true)。rules 由调用方按 priority 升序传入。
    private static func matches(_ rule: ResolvedStyleRule, _ entity: StyleEntity) -> Bool {
        rule.conditions.allSatisfy { ConditionEvaluator.matches(entity: entity, condition: $0) }
    }
}
