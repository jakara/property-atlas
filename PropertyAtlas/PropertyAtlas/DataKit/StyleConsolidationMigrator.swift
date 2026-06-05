import Foundation
import SwiftData

/// Stage A 启动幂等搬运:旧 Theme/Palette/实体 overrideStyleJSON → 新视图样式模型。
/// 每视图闸 = 是否已有 ViewEntityStyle 行;实体 override 闸 = Dataset.stylesMigratedV2。
/// 后续阶段删除本文件。
@MainActor
enum StyleConsolidationMigrator {
    static func run(in context: ModelContext) {
        migrateViews(in: context)
        migrateEntityOverrides(in: context)
        try? context.save()
    }

    private static func migrateViews(in context: ModelContext) {
        let views = (try? context.fetch(FetchDescriptor<MapView>(
            predicate: #Predicate { !$0.deleted }
        ))) ?? []
        for view in views {
            let viewId = view.id
            let datasetId = view.datasetId
            let existing = (try? context.fetch(FetchDescriptor<ViewEntityStyle>(
                predicate: #Predicate { $0.viewId == viewId && !$0.deleted }
            ))) ?? []
            let existingTypes = Set(existing.map(\.entityType))
            let missing = ["compound", "school", "poi", "area"].filter { !existingTypes.contains($0) }
            if missing.isEmpty { continue } // 全 4 类已有 → 跳过整视图(含 palette/legend),不覆盖用户编辑

            let theme = resolveTheme(for: view, in: context)
            let parsed = theme.flatMap { try? StyleDefaults.parseThemeDefaults($0.defaultStylesJSON) }

            for entityType in missing {
                let row = ViewEntityStyle(datasetId: datasetId, viewId: viewId, entityType: entityType)
                applyParsedDefaults(parsed, entityType: entityType, to: row)
                context.insert(row)
            }

            applyPaletteAndLegend(view: view, theme: theme, in: context)
        }
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

    private static func applyPaletteAndLegend(view: MapView, theme: Theme?, in context: ModelContext) {
        if let paletteId = view.paletteId {
            let palette = (try? context.fetch(FetchDescriptor<Palette>(
                predicate: #Predicate { $0.id == paletteId && !$0.deleted }
            )))?.first
            if let palette { view.paletteHex = palette.colorsHex }
        }
        if let resolvedTheme = theme { view.showLegend = resolvedTheme.showLegend }
    }

    private static func resolveTheme(for view: MapView, in context: ModelContext) -> Theme? {
        let datasetId = view.datasetId
        let enabledIds = Set(view.enabledLayerIds)
        let allLayers = (try? context.fetch(FetchDescriptor<Layer>(
            predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }
        ))) ?? []
        let topThemeId = allLayers
            .filter { enabledIds.contains($0.id) }
            .sorted { $0.zIndex > $1.zIndex }
            .compactMap(\.themeId)
            .first
        if let themeId = topThemeId, let theme = themeById(themeId, in: context) {
            return theme
        }
        let activeThemeId = (try? context.fetch(FetchDescriptor<Dataset>(
            predicate: #Predicate { $0.id == datasetId }
        )))?.first?.activeThemeId
        return activeThemeId.flatMap { themeById($0, in: context) }
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
}
