// PropertyAtlas/PropertyAtlas/MapRender/LegendSwatch.swift
import Foundation

@MainActor
enum LegendSwatch {
    /// 合成只含目标字段的 entity，复用 StyleResolver 求 fill，保证 legend 与地图一致。
    static func fillHex(
        entityType: String,
        fieldKey: String,
        value: String,
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette]
    ) -> String {
        let entity = StyleEntity(
            entityType: entityType,
            id: UUID(),
            baseFields: [fieldKey: .string(value)],
            customFields: [:]
        )
        let style = StyleResolver.resolvePin(entity: entity, theme: theme, rules: rules, palettes: palettes)
        return style.fillHex
    }
}
