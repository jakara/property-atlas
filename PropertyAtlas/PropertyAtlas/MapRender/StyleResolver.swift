import CoreGraphics
import Foundation

@MainActor
enum StyleResolver {
    /// 单 theme 的 defaultStylesJSON 解析一次,复用于全部 pin/area。批量渲染时由调用方
    /// 预解析传入(`themeDefaults`),避免每 pin 重复 JSON 解码(N pin = N 次 → 1 次)。
    static func parseDefaults(_ theme: Theme?) -> StyleDefaults.ParsedDefaults {
        guard let theme else { return .init(pin: [:], area: [:]) }
        return (try? StyleDefaults.parseThemeDefaults(theme.defaultStylesJSON))
            ?? .init(pin: [:], area: [:])
    }

    static func resolvePin(
        entity: StyleEntity,
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette],
        groupFillHex: String? = nil,
        themeDefaults: StyleDefaults.ParsedDefaults? = nil
    ) -> PinStyle {
        let base = StyleDefaults.builtinPin(for: entity.entityType)
        var partial = PartialPinStyle()

        let parsed = themeDefaults ?? parseDefaults(theme)
        if let themeDefault = parsed.pin[entity.entityType] {
            partial.merge(themeDefault)
        }

        let matching = rules.filter { StyleRuleMatcher.matches(rule: $0, entity: entity) }
        let ascending = matching.sorted { $0.priority < $1.priority }
        for rule in ascending {
            partial.merge(pinPartialFromRule(rule, entity: entity, palettes: palettes))
        }

        if let groupFillHex {
            partial.fillHex = groupFillHex
        }

        if let overrideJSON = entity.overrideJSON {
            partial.merge(pinOverridePartial(overrideJSON))
        }

        return partial.finalize(default: base)
    }

    static func resolveArea(
        entity: StyleEntity,
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette],
        themeDefaults: StyleDefaults.ParsedDefaults? = nil
    ) -> AreaStyle {
        let base = StyleDefaults.builtinArea()
        var partial = PartialAreaStyle()

        let parsed = themeDefaults ?? parseDefaults(theme)
        if let themeDefault = parsed.area["area"] {
            partial.merge(themeDefault)
        }

        let matching = rules.filter { StyleRuleMatcher.matches(rule: $0, entity: entity) }
        let ascending = matching.sorted { $0.priority < $1.priority }
        for rule in ascending {
            partial.merge(areaPartialFromRule(rule, entity: entity, palettes: palettes))
        }

        if let overrideJSON = entity.overrideJSON {
            partial.merge(areaOverridePartial(overrideJSON))
        }

        return partial.finalize(default: base)
    }

    private static func pinPartialFromRule(
        _ rule: StyleRule,
        entity: StyleEntity,
        palettes: [UUID: Palette]
    ) -> PartialPinStyle {
        var p = PartialPinStyle()
        if let s = rule.appliesShape { p.shape = PinShape(rawValue: s) }
        if rule.appliesFillMode == "palette" {
            if let pid = rule.appliesPaletteId, let palette = palettes[pid] {
                p.fillHex = PaletteResolver.resolve(
                    palette: palette, entity: entity, keyField: rule.appliesPaletteKeyField
                )
            }
        } else if let hex = rule.appliesFillHex {
            p.fillHex = hex
        }
        if let v = rule.appliesStrokeHex { p.strokeHex = v }
        if let v = rule.appliesGlyph { p.glyph = v }
        if let v = rule.appliesGlyphHex { p.glyphHex = v }
        if let v = rule.appliesSize { p.size = CGFloat(v) }
        if let v = rule.appliesLabelVisible { p.labelVisible = v }
        return p
    }

    private static func areaPartialFromRule(
        _ rule: StyleRule,
        entity: StyleEntity,
        palettes: [UUID: Palette]
    ) -> PartialAreaStyle {
        var a = PartialAreaStyle()
        if rule.appliesFillMode == "palette" {
            if let pid = rule.appliesPaletteId, let palette = palettes[pid] {
                a.fillHex = PaletteResolver.resolve(
                    palette: palette, entity: entity, keyField: rule.appliesPaletteKeyField
                )
            }
        } else if let hex = rule.appliesFillHex {
            a.fillHex = hex
        }
        if let v = rule.appliesFillOpacity { a.fillOpacity = v }
        if let v = rule.appliesStrokeHex { a.strokeHex = v }
        if let v = rule.appliesStrokeWidth { a.strokeWidth = v }
        if let v = rule.appliesLabelVisible { a.labelVisible = v }
        return a
    }

    private static func pinOverridePartial(_ json: String) -> PartialPinStyle {
        guard let decoded: [String: AnyJSON] = try? JSONHelpers.decode(json) else {
            return PartialPinStyle()
        }
        var p = PartialPinStyle()
        if case let .string(v) = decoded["shape"] { p.shape = PinShape(rawValue: v) }
        if case let .string(v) = decoded["fillHex"] { p.fillHex = v }
        if case let .string(v) = decoded["strokeHex"] { p.strokeHex = v }
        if case let .string(v) = decoded["glyph"] { p.glyph = v }
        if case let .string(v) = decoded["glyphHex"] { p.glyphHex = v }
        if case let .int(v) = decoded["size"] { p.size = CGFloat(v) }
        if case let .double(v) = decoded["size"] { p.size = CGFloat(v) }
        if case let .bool(v) = decoded["labelVisible"] { p.labelVisible = v }
        return p
    }

    private static func areaOverridePartial(_ json: String) -> PartialAreaStyle {
        guard let decoded: [String: AnyJSON] = try? JSONHelpers.decode(json) else {
            return PartialAreaStyle()
        }
        var a = PartialAreaStyle()
        if case let .string(v) = decoded["fillHex"] { a.fillHex = v }
        if case let .double(v) = decoded["fillOpacity"] { a.fillOpacity = v }
        if case let .int(v) = decoded["fillOpacity"] { a.fillOpacity = Double(v) }
        if case let .string(v) = decoded["strokeHex"] { a.strokeHex = v }
        if case let .double(v) = decoded["strokeWidth"] { a.strokeWidth = v }
        if case let .int(v) = decoded["strokeWidth"] { a.strokeWidth = Double(v) }
        if case let .bool(v) = decoded["labelVisible"] { a.labelVisible = v }
        return a
    }
}

extension StyleEntity {
    var overrideJSON: String? {
        if case let .string(s) = field("__overrideStyleJSON") { return s }
        return nil
    }
}
