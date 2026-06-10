import Foundation
import SwiftData

/// Stage A 启动幂等搬运:旧 Theme/Palette/实体 overrideStyleJSON → 新视图样式模型。
/// 每视图闸(views pass) = 是否已有 ViewEntityStyle 行;实体 override 闸 = Dataset.stylesMigratedV2。
/// 第三段(style rules pass):旧 StyleRule → ViewStyleRule + ViewStyleCondition;每视图闸 = 已有 ViewStyleRule 行。
/// 后续阶段删除本文件。
@MainActor
enum StyleConsolidationMigrator {
    static func run(in context: ModelContext) {
        migrateViews(in: context)
        migrateEntityOverrides(in: context)
        migrateStyleRules(in: context)
        try? context.save()
    }

    private static func migrateViews(in context: ModelContext) {
        let layers = (try? context.fetch(FetchDescriptor<Layer>(
            predicate: #Predicate { !$0.deleted }
        ))) ?? []
        for layer in layers {
            let lid = layer.id
            let existing = (try? context.fetch(FetchDescriptor<ViewEntityStyle>(
                predicate: #Predicate { $0.layerId == lid && !$0.deleted }
            ))) ?? []
            if !existing.isEmpty { continue } // 该图层已有样式行 → 跳过,不覆盖用户编辑

            let theme = activeTheme(datasetId: layer.datasetId, in: context)
            let parsed = theme.flatMap { try? StyleDefaults.parseThemeDefaults($0.defaultStylesJSON) }
            let row = ViewEntityStyle(datasetId: layer.datasetId, layerId: lid, entityType: layer.entityType)
            applyParsedDefaults(parsed, entityType: layer.entityType, to: row)
            context.insert(row)
        }
    }

    private static func activeTheme(datasetId: UUID, in context: ModelContext) -> Theme? {
        guard let aid = (try? context.fetch(FetchDescriptor<Dataset>(
            predicate: #Predicate { $0.id == datasetId }
        )))?.first?.activeThemeId else { return nil }
        return themeById(aid, in: context)
    }

    private static func applyParsedDefaults(
        _ parsed: StyleDefaults.ParsedDefaults?,
        entityType: String,
        to row: ViewEntityStyle
    ) {
        if entityType == "area", let areaPartial = parsed?.area["area"] {
            row.fillHex = areaPartial.fillHex
            row.fillOpacity = areaPartial.fillOpacity
            row.strokeHex = areaPartial.strokeHex
            row.strokeWidth = areaPartial.strokeWidth
            row.labelVisible = areaPartial.labelVisible
        } else if let pinPartial = parsed?.pin[entityType] {
            row.shape = pinPartial.shape?.rawValue
            row.fillHex = pinPartial.fillHex
            row.strokeHex = pinPartial.strokeHex
            row.glyph = pinPartial.glyph
            row.glyphHex = pinPartial.glyphHex
            row.size = pinPartial.size.map { Int($0) }
            row.labelVisible = pinPartial.labelVisible
        }
    }

    private static func themeById(_ themeId: UUID, in context: ModelContext) -> Theme? {
        (try? context.fetch(FetchDescriptor<Theme>(
            predicate: #Predicate { $0.id == themeId && !$0.deleted }
        )))?.first
    }

    private static func migrateEntityOverrides(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>(
            predicate: #Predicate { !$0.deleted && !$0.stylesMigratedV2 }
        ))) ?? []
        for dataset in datasets {
            applyOverrides(datasetId: dataset.id, in: context)
            dataset.stylesMigratedV2 = true
        }
    }

    private static func applyOverrides(datasetId: UUID, in context: ModelContext) {
        applyCompoundOverrides(datasetId: datasetId, in: context)
        applySchoolOverrides(datasetId: datasetId, in: context)
        applyPOIOverrides(datasetId: datasetId, in: context)
        applyAreaOverrides(datasetId: datasetId, in: context)
    }

    private static func applyCompoundOverrides(datasetId: UUID, in context: ModelContext) {
        let compounds = (try? context.fetch(FetchDescriptor<Compound>(
            predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }
        ))) ?? []
        for compound in compounds {
            let style = OverrideStyleCodec.decode(compound.overrideStyleJSON)
            compound.styleShape = style.shape
            compound.styleFillHex = style.fillHex
            compound.styleGlyph = style.glyph
            compound.styleGlyphHex = style.glyphHex
            compound.styleSize = style.size
            compound.styleLabelVisible = style.labelVisible
        }
    }

    private static func applySchoolOverrides(datasetId: UUID, in context: ModelContext) {
        let schools = (try? context.fetch(FetchDescriptor<School>(
            predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }
        ))) ?? []
        for school in schools {
            let style = OverrideStyleCodec.decode(school.overrideStyleJSON)
            school.styleShape = style.shape
            school.styleFillHex = style.fillHex
            school.styleGlyph = style.glyph
            school.styleGlyphHex = style.glyphHex
            school.styleSize = style.size
            school.styleLabelVisible = style.labelVisible
        }
    }

    private static func applyPOIOverrides(datasetId: UUID, in context: ModelContext) {
        let pois = (try? context.fetch(FetchDescriptor<POI>(
            predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }
        ))) ?? []
        for poi in pois {
            let style = OverrideStyleCodec.decode(poi.overrideStyleJSON)
            poi.styleShape = style.shape
            poi.styleFillHex = style.fillHex
            poi.styleGlyph = style.glyph
            poi.styleGlyphHex = style.glyphHex
            poi.styleSize = style.size
            poi.styleLabelVisible = style.labelVisible
        }
    }

    private static func applyAreaOverrides(datasetId: UUID, in context: ModelContext) {
        let areas = (try? context.fetch(FetchDescriptor<Area>(
            predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }
        ))) ?? []
        for area in areas {
            let style = OverrideStyleCodec.decode(area.overrideStyleJSON)
            area.styleFillHex = style.fillHex
            area.styleLabelVisible = style.labelVisible
        }
    }

    /// 旧 StyleRule(挂 theme.styleRuleIds)→ ViewStyleRule + ViewStyleCondition。
    /// 每视图闸 = 已有 ViewStyleRule 行则跳过。
    private static func migrateStyleRules(in context: ModelContext) {
        let layers = (try? context.fetch(FetchDescriptor<Layer>(
            predicate: #Predicate { !$0.deleted }
        ))) ?? []
        for layer in layers {
            let lid = layer.id
            let existing = (try? context.fetch(FetchDescriptor<ViewStyleRule>(
                predicate: #Predicate { $0.layerId == lid && !$0.deleted }
            ))) ?? []
            if !existing.isEmpty { continue }
            guard let theme = activeTheme(datasetId: layer.datasetId, in: context) else { continue }
            let layerType = layer.entityType
            for styleRuleId in theme.styleRuleIds {
                guard let old = styleRuleById(styleRuleId, in: context) else { continue }
                // 单类型图层:只搬运匹配本图层 entityType 的旧规则
                guard old.entityType == layerType else { continue }
                migrateStyleRule(old, layerId: lid, datasetId: layer.datasetId, in: context)
            }
        }
    }

    private static func migrateStyleRule(
        _ old: StyleRule,
        layerId: UUID,
        datasetId: UUID,
        in context: ModelContext
    ) {
        let conditions: [StyleCondition]
        do {
            conditions = try JSONHelpers.decode(old.conditionsJSON)
        } catch {
            return // conditionsJSON 损坏 → 跳过整条规则,避免产生 match-all
        }
        let rule = ViewStyleRule(datasetId: datasetId, layerId: layerId, entityType: old.entityType)
        rule.priority = old.priority
        rule.enabled = old.enabled
        rule.shape = old.appliesShape
        // palette 模式:fillHex 由 PaletteAssigner 渲染时决定;paletteId/keyField 不存在 ViewStyleRule 上,故丢弃
        rule.fillHex = (old.appliesFillMode == "palette") ? nil : old.appliesFillHex
        rule.strokeHex = old.appliesStrokeHex
        rule.glyph = old.appliesGlyph
        rule.glyphHex = old.appliesGlyphHex
        rule.size = old.appliesSize
        rule.labelVisible = old.appliesLabelVisible
        rule.fillOpacity = old.appliesFillOpacity
        rule.strokeWidth = old.appliesStrokeWidth
        context.insert(rule)
        for (index, condition) in conditions.enumerated() {
            let columns = ViewStyleConditionCodec.columns(from: condition.value, op: condition.op)
            let newCondition = ViewStyleCondition(
                ruleId: rule.id, field: condition.field, op: condition.op.rawValue
            )
            newCondition.valueString = columns.valueString
            newCondition.valueList = columns.valueList
            newCondition.sortOrder = index
            context.insert(newCondition)
        }
    }

    private static func styleRuleById(_ id: UUID, in context: ModelContext) -> StyleRule? {
        (try? context.fetch(FetchDescriptor<StyleRule>(
            predicate: #Predicate { $0.id == id && !$0.deleted }
        )))?.first
    }
}
