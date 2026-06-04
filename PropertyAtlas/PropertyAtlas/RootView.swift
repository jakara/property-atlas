import SwiftUI

#if targetEnvironment(macCatalyst)
import MapKit
import SwiftData
#endif

struct RootView: View {
    @Environment(AppMode.self) private var appMode

    var body: some View {
        switch appMode.value {
        case .explore: ExploreRootView()
        case .studio: StudioRootView()
        }
    }
}

struct ExploreRootView: View {
    @Environment(MapSelectionState.self) private var selection

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                MapContainerView()
                    .ignoresSafeArea()

                ToolbarView()
                    .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 11, x: 0, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    .zIndex(30)

                DrawerContainerView()
                    .frame(width: geo.size.width * 0.382 - 16)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 108)
                    .padding(.bottom, 16)
                    .padding(.trailing, 16)
                    .zIndex(5)
            }
        }
        .ignoresSafeArea()
    }
}

#if targetEnvironment(macCatalyst)
struct StudioRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var datasets: [Dataset]
    @Query private var compounds: [Compound]
    @Query private var schools: [School]
    @Query private var pois: [POI]
    @Query private var areas: [Area]
    @Query private var styleRules: [StyleRule]
    @Query private var palettes: [Palette]
    @Query private var layersQuery: [Layer]

    @State private var filterState = DimensionFilterState()
    @State private var layerState = LayerState()
    @State private var viewContext: MapViewContext?
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var watermark: String = "@公众号名 · PropertyAtlas"
    @State private var aspect: CanvasAspect = .ratio16x9
    @State private var camera: MKMapCamera = .init(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 39.125, longitude: 117.205),
        fromDistance: 12000, pitch: 0, heading: 0
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var appState = AppState()
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    @State private var showCreateMenu = false
    @State private var showSettings = false
    @State private var exportMode = false
    @State private var showSafeFrame = false

    var body: some View {
        let palettesById: [UUID: Palette] = Dictionary(uniqueKeysWithValues: palettes.map { ($0.id, $0) })
        let dsId = viewContext?.datasetIdValue ?? UUID()
        let activeMapView = viewContext?.activeMapView
        let activeTheme = viewContext?.activeTheme
        let activeRuleIds = Set(activeTheme?.styleRuleIds ?? [])
        let rulesForTheme = styleRules.filter { activeRuleIds.contains($0.id) }
        let visibility = viewContext?.visibility ?? ["compound": true, "school": true, "poi": true, "area": true]
        let primary = viewContext?.primaryFilter ?? PrimaryFilter(conditions: [], groupBy: nil)
        let normals = viewContext?.normalFilters ?? []

        // spotlight
        let relatedIds: [UUID] = appState.selectedRef.map {
            EdgeStore.relations(of: $0, datasetId: dsId, in: modelContext)
                .flatMap { $0.items.map(\.other.id) }
        } ?? []
        let highlight = SpotlightResolver.highlightedIds(
            selected: appState.selectedRef?.id, relatedIds: relatedIds,
            enabled: activeMapView?.spotlightOnSelect ?? false
        )

        let zoom = visibleRegion.map { ZoomLevel.from(region: $0) } ?? 12
        let _: Void = layerState.initializeIfNeeded(enabledIds: activeMapView?.enabledLayerIds ?? [])

        // ── 候选集(含坐标 + 图层归属)──
        let cands = buildCandidates(dsId: dsId, visibility: visibility)
        let defaultLayerId = layersForDataset(dsId).first(where: { $0.isDefault })?.id
            ?? layersForDataset(dsId).first?.id ?? dsId
        let namedLayers = layersForDataset(dsId).map {
            LayerEvaluator.NamedLayer(
                name: $0.name,
                layer: LayerEvaluator.ActiveLayer(
                    id: $0.id, enabled: layerState.isEnabled($0.id),
                    minZoom: $0.minZoom, maxZoom: $0.maxZoom
                )
            )
        }
        let evalCands = cands.map { LayerEvaluator.Candidate(id: $0.id, layerId: $0.layerId) }
        let layerVisible = LayerEvaluator.visibleIds(
            layers: namedLayers.map(\.layer), zoom: zoom, candidates: evalCands,
            defaultLayerId: defaultLayerId
        )
        let membership = LayerEvaluator.membership(
            layers: namedLayers, zoom: zoom, candidates: evalCands, defaultLayerId: defaultLayerId
        )

        // ── 可见集(layer ∩ primary ∩ ¬chip 隐藏)──
        let visCands = cands.map {
            VisibilityResolver.Candidate(id: $0.id, entity: $0.entity, layerNames: membership[$0.id] ?? [])
        }
        let visibleIds = VisibilityResolver.visibleIds(
            candidates: visCands, layerVisible: layerVisible,
            primary: primary, normals: normals, filterState: filterState,
            context: modelContext, datasetId: dsId
        )

        // ── 分组染色 ──
        let palette = activeMapView?.paletteId.flatMap { palettesById[$0]?.colorsHex }
            ?? PaletteAssigner.highContrast
        let groupItems = cands
            .filter { visibleIds.contains($0.id) && $0.type != "area" }
            .map { GroupColorResolver.Item(id: $0.id, entity: $0.entity, layerNames: membership[$0.id] ?? []) }
        let groupColors = GroupColorResolver.colors(
            items: groupItems, groupBy: primary.groupBy, palette: palette,
            context: modelContext, datasetId: dsId
        )

        // ── 图例 sections(primary groupBy 彩色 + 每个 normal 灰)──
        let legendSections = buildLegendSections(
            cands: cands, visibleIds: visibleIds, membership: membership,
            primary: primary, normals: normals, palette: palette,
            groupColors: groupColors, dsId: dsId
        )

        // ── pins / overlays ──
        let pins = buildPins(
            cands: cands, visibleIds: visibleIds, groupColors: groupColors,
            theme: activeTheme, rules: rulesForTheme, palettes: palettesById, highlight: highlight
        )
        let (areaOverlays, styleMap) = buildAreaOverlays(
            areas: visibility["area"] == true ? areas.filter { $0.datasetId == dsId } : [],
            visibleIds: visibleIds, theme: activeTheme, rules: rulesForTheme, palettes: palettesById
        )
        let edgeLines = buildEdgeLines(labels: activeMapView?.drawEdgeLines ?? [], datasetId: dsId)
        let overlays = areaOverlays + edgeLines

        ZStack {
            MapContainerView(
                camera: $camera, overlays: overlays, annotations: pins,
                rendererFor: { overlay in
                    if let polygon = overlay as? MKPolygon, let style = styleMap[ObjectIdentifier(overlay)] {
                        return AreaOverlayRenderer(polygon: polygon, style: style)
                    }
                    return nil
                },
                onRegionChange: { visibleRegion = $0 },
                onSchoolSelect: { id in
                    if let id, let kind = idKind(for: id, in: pins) { appState.select(EntityRef(id: id, kind: kind)) }
                    else { appState.clearSelection() }
                },
                onLongPressCoordinate: { coord in
                    pendingCoordinate = coord
                    showCreateMenu = true
                }
            )
            .ignoresSafeArea()

            if let ctx = viewContext {
                StudioOverlay(
                    title: $title, subtitle: $subtitle, watermark: $watermark,
                    aspect: $aspect, viewContext: ctx, showSettings: $showSettings,
                    exportMode: $exportMode, showSafeFrame: $showSafeFrame
                )
            }

            if !exportMode {
                HStack {
                    Spacer()
                    RightDrawer(appState: appState, datasetId: dsId)
                        .padding(.top, 80).padding(.trailing, 16).padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .animation(.easeInOut(duration: 0.2), value: appState.selectedRef)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            if !exportMode {
                HStack {
                    LeftDrawerView(
                        legendSections: legendSections,
                        layers: layersForDataset(dsId),
                        currentZoom: zoom,
                        filterState: filterState,
                        layerState: layerState
                    )
                    .padding(.top, 80).padding(.leading, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: exportMode)
        .onChange(of: viewContext?.activeMapView?.id) { _, _ in
            layerState.resetForTheme(enabledIds: viewContext?.activeMapView?.enabledLayerIds ?? [])
            filterState.reset()
        }
        .sheet(isPresented: $showCreateMenu) {
            if let dsId = viewContext?.datasetIdValue {
                let layers = layersForDataset(dsId)
                let defaultId = layers.first(where: { $0.isDefault })?.id
                let enabled = layers.filter { layerState.isEnabled($0.id) }.map { (id: $0.id, name: $0.name) }
                CreateEntitySheet(
                    enabledLayers: enabled,
                    defaultLayerId: defaultId,
                    onCreate: { kind, layerId in
                        showCreateMenu = false
                        createPin(kind, layerId: layerId)
                    },
                    onCancel: { showCreateMenu = false }
                )
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showSettings) {
            if let ctx = viewContext {
                SettingsSheet(viewContext: ctx, onClose: { showSettings = false })
            }
        }
        .onAppear { ensureViewContext() }
        .onChange(of: datasets.first?.id) { _, _ in ensureViewContext() }
    }

    // MARK: - 候选

    private struct Cand {
        let id: UUID
        let type: String
        let layerId: UUID?
        let name: String
        let entity: StyleEntity
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
    }

    private func buildCandidates(dsId: UUID, visibility: [String: Bool]) -> [Cand] {
        var out: [Cand] = []
        if visibility["compound"] == true {
            for c in compounds where !c.deleted && c.datasetId == dsId {
                out.append(.init(
                    id: c.id,
                    type: "compound",
                    layerId: c.layerId,
                    name: c.name,
                    entity: c.styleEntity,
                    coordinate: c.coordinate,
                    hasCoordinate: c.latitude != 0 || c.longitude != 0
                ))
            }
        }
        if visibility["school"] == true {
            for s in schools where !s.deleted && s.datasetId == dsId {
                out.append(.init(
                    id: s.id,
                    type: "school",
                    layerId: s.layerId,
                    name: s.name,
                    entity: s.styleEntity,
                    coordinate: s.coordinate,
                    hasCoordinate: s.latitude != 0 || s.longitude != 0
                ))
            }
        }
        if visibility["poi"] == true {
            for p in pois where !p.deleted && p.datasetId == dsId {
                out.append(.init(
                    id: p.id,
                    type: "poi",
                    layerId: p.layerId,
                    name: p.name,
                    entity: p.styleEntity,
                    coordinate: p.coordinate,
                    hasCoordinate: p.latitude != 0 || p.longitude != 0
                ))
            }
        }
        // areas 加入候选(供 layer 归属/可见集);无点坐标,buildPins 跳过
        if visibility["area"] == true {
            for a in areas where !a.deleted && a.datasetId == dsId {
                out.append(.init(
                    id: a.id,
                    type: "area",
                    layerId: a.layerId,
                    name: a.name,
                    entity: a.styleEntity,
                    coordinate: CLLocationCoordinate2D(),
                    hasCoordinate: false
                ))
            }
        }
        return out
    }

    // MARK: - 图例

    private func buildLegendSections(
        cands: [Cand], visibleIds: Set<UUID>, membership: [UUID: [String]],
        primary: PrimaryFilter, normals: [NormalFilter], palette: [String],
        groupColors: [UUID: String], dsId: UUID
    ) -> [LegendSection] {
        // 仅统计可见实体(含 area)
        let items = cands.filter { visibleIds.contains($0.id) }.map {
            DimensionLegendCounter.Item(
                id: $0.id,
                entity: $0.entity,
                coordinate: $0.coordinate,
                layerNames: membership[$0.id] ?? []
            )
        }
        var sections: [LegendSection] = []

        if let gb = primary.groupBy {
            // groupBy 维度的值 → palette 色(与 pin 一致):由全屏 distinct 值分配
            let distinct = items.flatMap { it -> [String] in
                gb.resolve(MapDimension.Input(
                    entity: it.entity,
                    layerNames: it.layerNames,
                    context: modelContext,
                    datasetId: dsId
                )).sorted().prefix(1).map { $0 }
            }
            let assign = PaletteAssigner.assign(values: Array(Set(distinct)), palette: palette)
            let rows = DimensionLegendCounter.rows(
                dimension: gb, items: items, region: visibleRegion,
                context: modelContext, datasetId: dsId,
                swatch: { assign[$0] ?? "#8E8E93" }
            ).filter { visibleRegion == nil || $0.viewport > 0 }
            sections.append(LegendSection(title: legendTitle(for: gb, fallback: "分组"), dimensionKey: gb.key, rows: rows))
        }

        for nf in normals {
            let rows = DimensionLegendCounter.rows(
                dimension: nf.dimension, items: items, region: visibleRegion,
                context: modelContext, datasetId: dsId,
                swatch: { _ in "#8E8E93" } // normal filter 不参与染色 → 中性灰
            ).filter { visibleRegion == nil || $0.viewport > 0 }
            sections.append(LegendSection(title: nf.name, dimensionKey: nf.dimension.key, rows: rows))
        }
        return sections
    }

    private func legendTitle(for dim: MapDimension, fallback: String) -> String {
        switch dim.kind {
        case .field: dim.fieldKey ?? fallback
        case .layer: "图层"
        case .entityType: "类型"
        case .edgeField: dim.edgeLabel ?? fallback
        }
    }

    // MARK: - pins / overlays

    private func buildPins(
        cands: [Cand], visibleIds: Set<UUID>, groupColors: [UUID: String],
        theme: Theme?, rules: [StyleRule], palettes: [UUID: Palette], highlight: Set<UUID>?
    ) -> [MKAnnotation] {
        var result: [MKAnnotation] = []
        for c in cands where c.type != "area" && c.hasCoordinate && visibleIds.contains(c.id) {
            let style = StyleResolver.resolvePin(
                entity: c.entity, theme: theme, rules: rules, palettes: palettes,
                groupFillHex: groupColors[c.id]
            )
            let pin = PinAnnotation(
                entityId: c.id,
                entityType: c.type,
                name: c.name,
                coordinate: c.coordinate,
                style: style
            )
            if let highlight {
                pin.highlighted = highlight.contains(c.id)
                pin.dimmed = !highlight.contains(c.id)
            }
            result.append(pin)
        }
        return result
    }

    private func buildAreaOverlays(
        areas: [Area], visibleIds: Set<UUID>, theme: Theme?, rules: [StyleRule], palettes: [UUID: Palette]
    ) -> ([MKOverlay], [ObjectIdentifier: AreaStyle]) {
        var overlays: [MKOverlay] = []
        var map: [ObjectIdentifier: AreaStyle] = [:]
        for a in areas where !a.deleted && visibleIds.contains(a.id) {
            let style = StyleResolver.resolveArea(entity: a.styleEntity, theme: theme, rules: rules, palettes: palettes)
            if let r = AreaOverlayFactory.makeOverlay(for: a, style: style) {
                overlays.append(r.overlay)
                map[ObjectIdentifier(r.overlay)] = r.style
            }
        }
        return (overlays, map)
    }

    private func createPin(_ kind: EntityKind, layerId: UUID?) {
        guard let coord = pendingCoordinate, let dsId = viewContext?.datasetIdValue else { return }
        let ref = EntityWriter.createPin(
            kind: kind, datasetId: dsId, name: "未命名",
            latitude: coord.latitude, longitude: coord.longitude, layerId: layerId, in: modelContext
        )
        appState.select(ref)
        appState.beginEditing()
    }

    private func idKind(for id: UUID, in pins: [MKAnnotation]) -> EntityKind? {
        for case let p as PinAnnotation in pins where p.entityId == id {
            return EntityKind(rawValue: p.entityType)
        }
        return nil
    }

    private func buildEdgeLines(labels: [String], datasetId: UUID) -> [MKOverlay] {
        guard !labels.isEmpty else { return [] }
        let labelSet = Set(labels)
        let fd = FetchDescriptor<Edge>(predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted })
        let edges = ((try? modelContext.fetch(fd)) ?? []).filter { labelSet.contains($0.label) }
        var segs: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        for e in edges {
            guard let a = EntityReader.coordinate(EntityRef(id: e.fromId, kind: EntityKind(rawValue: e.fromType) ?? .poi), in: modelContext),
                  let b = EntityReader.coordinate(EntityRef(id: e.toId, kind: EntityKind(rawValue: e.toType) ?? .poi), in: modelContext)
            else { continue }
            segs.append((a, b))
        }
        return EdgeLineFactory.polylines(from: segs)
    }

    private func ensureViewContext() {
        guard viewContext == nil, let ds = datasets.first(where: { !$0.deleted }) else { return }
        viewContext = MapViewContext(dataset: ds, modelContext: modelContext)
        title = viewContext?.activeMapView?.copyTitle ?? ""
        subtitle = viewContext?.activeMapView?.copySubtitle ?? ""
    }

    private func layersForDataset(_ dsId: UUID) -> [Layer] {
        layersQuery.filter { $0.datasetId == dsId && !$0.deleted }.sorted { $0.zIndex < $1.zIndex }
    }
}
#else
struct StudioRootView: View {
    var body: some View {
        Text("Studio Mode 仅在 Mac 端可用。")
    }
}
#endif

struct ToolbarView: View {
    var body: some View {
        Color.clear
    }
}

extension Notification.Name {
    static let studioPresetSelected = Notification.Name("studioPresetSelected")
    static let reloadSeeds = Notification.Name("reloadSeeds")
}
