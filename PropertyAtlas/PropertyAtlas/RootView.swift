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
    @State private var cache = StudioRenderCache()
    @State private var showSearch = false
    @State private var searchMarker: SearchMarker?
    @State private var searchPlace: ExternalPlaceSearch.PlaceHit?
    @State private var showPlaceDetail = false
    @State private var createPrefillName: String?

    var body: some View {
        let dsId = viewContext?.datasetIdValue ?? UUID()
        let activeMapView = viewContext?.activeMapView
        let visibility = viewContext?.visibility ?? ["compound": true, "school": true, "poi": true, "area": true]
        let primary = viewContext?.primaryFilter ?? PrimaryFilter(conditions: [], groupBy: nil)
        let normals = viewContext?.normalFilters ?? []

        let zoom = visibleRegion.map { ZoomLevel.from(region: $0) } ?? 12
        let _: Void = layerState.initializeIfNeeded(enabledIds: activeMapView?.enabledLayerIds ?? [])

        // ── 内容签名(不含 visibleRegion)未变 → 复用缓存,跳过整条重算管线 ──
        // 手势停稳后只在内容真变(数据/过滤/图层/缩放档/选中)时重建 pins/overlays/图例规格;
        // 纯 pan/zoom 仅走下方廉价的图例视口重计数。(在 ViewBuilder 外做副作用 → 包成 Void 方法)
        let _: Void = refreshCacheIfNeeded(
            dsId: dsId, visibility: visibility, activeMapView: activeMapView,
            primary: primary, normals: normals, zoom: zoom
        )

        // 廉价:仅按 region 对预解析 entries 做 bbox 计数(无 styleEntity / resolve)
        let legendSections = renderLegendSections(cache.legendSpecs, region: visibleRegion)
        let overlays = cache.overlays
        let markerAnnotations: [MKAnnotation] = searchMarker.map { [SearchMarkerFactory.annotation(for: $0)] } ?? []
        // 视口裁剪:只把 region(外扩 margin)内的 pin 交给 MapKit。全量 resolve 仍缓存在
        // cache.pins;此处只做廉价 bbox 过滤,pan settle 后重算(无 re-resolve)。降低同屏
        // annotation 渲染量(displayPriority=.required 不去重,全量交付 = 全量渲染 → 卡)。
        let annotations = viewportPins(cache.pins, region: visibleRegion) + markerAnnotations

        ZStack {
            MapContainerView(
                camera: $camera, overlays: overlays, annotations: annotations,
                rendererFor: { overlay in
                    if let polygon = overlay as? MKPolygon, let style = cache.styleMap[ObjectIdentifier(overlay)] {
                        return AreaOverlayRenderer(polygon: polygon, style: style)
                    }
                    return nil
                },
                onRegionChange: { visibleRegion = $0 },
                onSchoolSelect: { id in
                    if id == SearchMarkerFactory.markerId {
                        appState.clearSelection()
                        showPlaceDetail = true
                        return
                    }
                    showPlaceDetail = false
                    if let id, let kind = idKind(for: id, in: cache.pins) {
                        appState.select(EntityRef(id: id, kind: kind))
                    } else {
                        appState.clearSelection()
                    }
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
                    exportMode: $exportMode, showSafeFrame: $showSafeFrame, showSearch: $showSearch
                )
            }

            if !exportMode, showSearch {
                VStack {
                    Spacer()
                    StudioSearchPanel(
                        datasetId: dsId,
                        visibleRegion: visibleRegion,
                        onPickEntity: { ref, coord, hasCoord in
                            appState.select(ref)
                            if hasCoord, let coord { flyTo(coord) }
                            searchMarker = nil
                            searchPlace = nil
                            showPlaceDetail = false
                            showSearch = false
                        },
                        onPickExternal: { hit in
                            flyTo(hit.coordinate)
                            searchMarker = SearchMarker(coordinate: hit.coordinate, name: hit.name)
                            searchPlace = hit
                            showPlaceDetail = false
                        },
                        onCreateAtExternal: { hit in
                            pendingCoordinate = hit.coordinate
                            createPrefillName = hit.name
                            showSearch = false
                            showCreateMenu = true
                        },
                        onClose: { showSearch = false }
                    )
                    .padding(.bottom, 76)
                }
                .transition(.opacity)
            }

            if !exportMode {
                HStack {
                    Spacer()
                    Group {
                        if showPlaceDetail, let place = searchPlace {
                            ExternalPlaceCard(
                                place: place,
                                onAddPOI: {
                                    pendingCoordinate = place.coordinate
                                    createPrefillName = place.name
                                    showPlaceDetail = false
                                    showCreateMenu = true
                                },
                                onClose: { showPlaceDetail = false }
                            )
                        } else {
                            RightDrawer(appState: appState, datasetId: dsId)
                        }
                    }
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
            searchMarker = nil
            searchPlace = nil
            showPlaceDetail = false
            showSearch = false
        }
        .sheet(isPresented: $showCreateMenu, onDismiss: { createPrefillName = nil }) {
            if let dsId = viewContext?.datasetIdValue {
                let layers = layersForDataset(dsId)
                let defaultId = layers.first(where: { $0.isDefault })?.id
                // 列全部图层(非仅已启用);未在当前视图启用的标注提示——选中后需到视图设置启用才会显示
                let pickable = layers.map {
                    (id: $0.id, name: layerState.isEnabled($0.id) ? $0.name : "\($0.name)(未启用)")
                }
                CreateEntitySheet(
                    enabledLayers: pickable,
                    defaultLayerId: defaultId,
                    prefillName: createPrefillName,
                    defaultKind: createPrefillName != nil ? .poi : .compound,
                    onCreate: { kind, layerId, name in
                        showCreateMenu = false
                        createPin(kind, layerId: layerId, name: name)
                    },
                    onCancel: { showCreateMenu = false
                        createPrefillName = nil
                    }
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

    /// 全实体 styleEntity 解析一次(含 customFieldsJSON decode),candidates 与 edgeProjection 共用,
    /// 避免重复 decode。覆盖全部类型(edge 对端可能是当前隐藏类型,投影需要)。
    private func buildEntityIndex(dsId: UUID) -> [UUID: StyleEntity] {
        var index: [UUID: StyleEntity] = [:]
        for compound in compounds where !compound.deleted && compound.datasetId == dsId {
            index[compound.id] = compound.styleEntity
        }
        for school in schools where !school.deleted && school.datasetId == dsId {
            index[school.id] = school.styleEntity
        }
        for poi in pois where !poi.deleted && poi.datasetId == dsId {
            index[poi.id] = poi.styleEntity
        }
        for area in areas where !area.deleted && area.datasetId == dsId {
            index[area.id] = area.styleEntity
        }
        return index
    }

    private func buildCandidates(
        dsId: UUID, visibility: [String: Bool], entityById: [UUID: StyleEntity]
    ) -> [Cand] {
        var out: [Cand] = []
        if visibility["compound"] == true {
            for c in compounds where !c.deleted && c.datasetId == dsId {
                out.append(.init(
                    id: c.id, type: "compound", layerId: c.layerId, name: c.name,
                    entity: entityById[c.id] ?? c.styleEntity,
                    coordinate: c.coordinate, hasCoordinate: c.latitude != 0 || c.longitude != 0
                ))
            }
        }
        if visibility["school"] == true {
            for s in schools where !s.deleted && s.datasetId == dsId {
                out.append(.init(
                    id: s.id, type: "school", layerId: s.layerId, name: s.name,
                    entity: entityById[s.id] ?? s.styleEntity,
                    coordinate: s.coordinate, hasCoordinate: s.latitude != 0 || s.longitude != 0
                ))
            }
        }
        if visibility["poi"] == true {
            for p in pois where !p.deleted && p.datasetId == dsId {
                out.append(.init(
                    id: p.id, type: "poi", layerId: p.layerId, name: p.name,
                    entity: entityById[p.id] ?? p.styleEntity,
                    coordinate: p.coordinate, hasCoordinate: p.latitude != 0 || p.longitude != 0
                ))
            }
        }
        // areas 加入候选(供 layer 归属/可见集);无点坐标,buildPins 跳过
        if visibility["area"] == true {
            for a in areas where !a.deleted && a.datasetId == dsId {
                out.append(.init(
                    id: a.id, type: "area", layerId: a.layerId, name: a.name,
                    entity: entityById[a.id] ?? a.styleEntity,
                    coordinate: CLLocationCoordinate2D(), hasCoordinate: false
                ))
            }
        }
        return out
    }

    // MARK: - 内容签名 + 缓存重建

    /// 算签名并在变化时重建缓存。副作用包在普通方法里(ViewBuilder body 内不能写带副作用的 if)。
    private func refreshCacheIfNeeded(
        dsId: UUID, visibility: [String: Bool], activeMapView: MapView?,
        primary: PrimaryFilter, normals: [NormalFilter], zoom: Double
    ) {
        let sig = contentSignature(
            dsId: dsId, visibility: visibility, activeMapView: activeMapView,
            primary: primary, normals: normals, zoom: zoom
        )
        guard cache.sig != sig else { return }
        cache.sig = sig
        rebuildContent(
            dsId: dsId, visibility: visibility, activeMapView: activeMapView,
            primary: primary, normals: normals, zoom: zoom
        )
    }

    /// 内容签名:涵盖一切影响 pins/overlays/图例规格的输入,但**不含** visibleRegion。
    /// pan/zoom 不改 → 签名不变 → 复用缓存。zoom 取整数档(= 图层 zoom 阈值边界)。
    private func contentSignature(
        dsId: UUID, visibility: [String: Bool], activeMapView: MapView?,
        primary: PrimaryFilter, normals: [NormalFilter], zoom: Double
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(dsId)
        for key in visibility.keys.sorted() {
            hasher.combine(key)
            hasher.combine(visibility[key] ?? false)
        }
        hasher.combine(activeMapView?.id)
        hasher.combine(activeMapView?.primaryFilterJSON)
        hasher.combine(activeMapView?.normalFiltersJSON)
        hasher.combine(activeMapView?.paletteId)
        hasher.combine(activeMapView?.spotlightOnSelect ?? false)
        hasher.combine((activeMapView?.drawEdgeLines ?? []).sorted().joined(separator: ","))
        hasher.combine((activeMapView?.paletteHex ?? []).joined(separator: ","))
        hasher.combine(activeMapView?.showLegend ?? true)
        let styleFetch = FetchDescriptor<ViewEntityStyle>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted }
        )
        for row in (try? modelContext.fetch(styleFetch)) ?? [] {
            hasher.combine(row.viewId)
            hasher.combine(row.entityType)
            hasher.combine(row.updatedAt)
        }
        for (key, values) in filterState.hidden.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key)
            for value in values.sorted() {
                hasher.combine(value)
            }
        }
        for id in layerState.enabledIds.sorted(by: { $0.uuidString < $1.uuidString }) {
            hasher.combine(id)
        }
        let dsLayers = layersForDataset(dsId)
        // zoom 仅在有图层设了 minZoom/maxZoom 时影响可见集 —— 否则缩放不该触发重建。
        let zoomMatters = dsLayers.contains { $0.minZoom != nil || $0.maxZoom != nil }
        if zoomMatters { hasher.combine(Int(zoom)) }
        hasher.combine(appState.selectedRef?.id)
        combineVersion(&hasher, compounds, dsId)
        combineVersion(&hasher, schools, dsId)
        combineVersion(&hasher, pois, dsId)
        combineVersion(&hasher, areas, dsId)
        hasher.combine(dsLayers.count)
        for layer in dsLayers {
            hasher.combine(layer.id)
            hasher.combine(layer.updatedAt)
        }
        return hasher.finalize()
    }

    /// count + maxUpdatedAt → 检测某类型实体的增/删/改。仅读 3 个轻属性,O(N) 但极廉价。
    private func combineVersion(_ hasher: inout Hasher, _ items: [some MapEntityVersioning], _ dsId: UUID) {
        var count = 0
        var maxUpdated = Date.distantPast
        for entity in items where entity.datasetId == dsId && !entity.deleted {
            count += 1
            if entity.updatedAt > maxUpdated { maxUpdated = entity.updatedAt }
        }
        hasher.combine(count)
        hasher.combine(maxUpdated)
    }

    /// 重算整条内容管线写入 cache(只在内容签名变化时调用)。
    private func rebuildContent(
        dsId: UUID, visibility: [String: Bool], activeMapView: MapView?,
        primary: PrimaryFilter, normals: [NormalFilter], zoom: Double
    ) {
        // spotlight 高亮(含 EdgeStore 查询)只在内容变化时算,避免每次 pan 打 store
        let relatedIds: [UUID] = appState.selectedRef.map {
            EdgeStore.relations(of: $0, datasetId: dsId, in: modelContext).flatMap { $0.items.map(\.other.id) }
        } ?? []
        let highlight = SpotlightResolver.highlightedIds(
            selected: appState.selectedRef?.id, relatedIds: relatedIds,
            enabled: activeMapView?.spotlightOnSelect ?? false
        )

        // 全实体 styleEntity 只解析一次,candidates 与 edgeProjection 共用(去重复 JSON decode)。
        let entityById = buildEntityIndex(dsId: dsId)
        let cands = buildCandidates(dsId: dsId, visibility: visibility, entityById: entityById)

        // edgeField 维度的 per-entity DB fetch 是 ON 卡顿主因 —— 一次性建内存投影 + 解析缓存,
        // 供 visibility/groupColors/legend 共享(同维度同实体只算一次,且不再打 DB)。
        let edgeProjection = buildEdgeProjection(dsId: dsId, entityById: entityById)
        let dimCache = DimResolveCache()
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
        let visCands = cands.map {
            VisibilityResolver.Candidate(id: $0.id, entity: $0.entity, layerNames: membership[$0.id] ?? [])
        }
        let visibleIds = VisibilityResolver.visibleIds(
            candidates: visCands, layerVisible: layerVisible,
            primary: primary, normals: normals, filterState: filterState,
            context: modelContext, datasetId: dsId,
            edgeProjection: edgeProjection, cache: dimCache
        )
        // layer ∩ primary 但不含 chip 隐藏 —— 普通过滤图例列全部可切换值(隐藏态仍列出、可再点亮)
        let normalLegendIds = VisibilityResolver.visibleIds(
            candidates: visCands, layerVisible: layerVisible,
            primary: primary, normals: [], filterState: DimensionFilterState(),
            context: modelContext, datasetId: dsId,
            edgeProjection: edgeProjection, cache: dimCache
        )
        let viewStyles = buildViewStyles(dsId: dsId, viewId: activeMapView?.id)
        let palette = (activeMapView?.paletteHex.isEmpty == false)
            ? (activeMapView?.paletteHex ?? PaletteAssigner.highContrast)
            : PaletteAssigner.highContrast
        let groupItems = cands
            .filter { visibleIds.contains($0.id) && $0.type != "area" }
            .map { GroupColorResolver.Item(id: $0.id, entity: $0.entity, layerNames: membership[$0.id] ?? []) }
        let groupColors = GroupColorResolver.colors(
            items: groupItems, groupBy: primary.groupBy, palette: palette,
            context: modelContext, datasetId: dsId,
            edgeProjection: edgeProjection, cache: dimCache
        )
        let pins = buildPins(
            cands: cands, visibleIds: visibleIds, groupColors: groupColors,
            viewStyles: viewStyles, highlight: highlight
        )
        let (areaOverlays, styleMap) = buildAreaOverlays(
            areas: visibility["area"] == true ? areas.filter { $0.datasetId == dsId } : [],
            visibleIds: visibleIds, viewStyles: viewStyles
        )
        let edgeLines = buildEdgeLines(labels: activeMapView?.drawEdgeLines ?? [], datasetId: dsId)

        cache.pins = pins
        cache.overlays = areaOverlays + edgeLines
        cache.styleMap = styleMap
        cache.legendSpecs = buildLegendSpecs(
            cands: cands, visibleIds: visibleIds, normalLegendIds: normalLegendIds,
            membership: membership, primary: primary, normals: normals, palette: palette, dsId: dsId,
            edgeProjection: edgeProjection, dimCache: dimCache
        )
    }

    // MARK: - 图例

    /// 预解析图例规格:每个 item 的维度值 resolve 一次存入 entries。settle/pan 时只按 region bbox 计数。
    private func buildLegendSpecs(
        cands: [Cand], visibleIds: Set<UUID>, normalLegendIds: Set<UUID>, membership: [UUID: [String]],
        primary: PrimaryFilter, normals: [NormalFilter], palette: [String], dsId: UUID,
        edgeProjection: EdgeProjection? = nil, dimCache: DimResolveCache? = nil
    ) -> [LegendSpec] {
        func entriesFor(_ ids: Set<UUID>, _ dim: MapDimension, prefixOne: Bool) -> [LegendSpec.Entry] {
            cands.filter { ids.contains($0.id) }.map { cand in
                let input = MapDimension.Input(
                    entity: cand.entity, layerNames: membership[cand.id] ?? [],
                    context: modelContext, datasetId: dsId,
                    edgeProjection: edgeProjection, cache: dimCache
                )
                var values = dim.resolve(input)
                if prefixOne { values = values.sorted().prefix(1).map { $0 } }
                return LegendSpec.Entry(coordinate: cand.coordinate, values: values)
            }
        }
        var specs: [LegendSpec] = []
        if let gb = primary.groupBy {
            let entries = entriesFor(visibleIds, gb, prefixOne: true)
            let distinct = Array(Set(entries.flatMap(\.values)))
            let assign = PaletteAssigner.assign(values: distinct, palette: palette)
            specs.append(LegendSpec(
                title: legendTitle(for: gb, fallback: "分组"), dimensionKey: gb.key,
                togglable: false, dropZeroViewport: true, swatch: assign, entries: entries
            ))
        }
        for nf in normals {
            let entries = entriesFor(normalLegendIds, nf.dimension, prefixOne: false)
            specs.append(LegendSpec(
                title: nf.name, dimensionKey: nf.dimension.key,
                togglable: true, dropZeroViewport: false, swatch: [:], entries: entries
            ))
        }
        return specs
    }

    /// 廉价渲染:预解析 entries + region → rows。无 styleEntity / dimension.resolve。
    private func renderLegendSections(_ specs: [LegendSpec], region: MKCoordinateRegion?) -> [LegendSection] {
        specs.map { spec in
            var rows = DimensionLegendCounter.rowsFromEntries(
                dimensionKey: spec.dimensionKey, entries: spec.entries, region: region, swatch: spec.swatch
            )
            if spec.dropZeroViewport, region != nil { rows = rows.filter { $0.viewport > 0 } }
            return LegendSection(
                title: spec.title, dimensionKey: spec.dimensionKey, rows: rows, togglable: spec.togglable
            )
        }
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
        viewStyles: [String: ViewEntityStyle], highlight: Set<UUID>?
    ) -> [MKAnnotation] {
        var result: [MKAnnotation] = []
        for c in cands where c.type != "area" && c.hasCoordinate && visibleIds.contains(c.id) {
            let style = StyleResolver.resolvePin(
                entity: c.entity, viewStyle: viewStyles[c.type], groupFillHex: groupColors[c.id]
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
        areas: [Area], visibleIds: Set<UUID>, viewStyles: [String: ViewEntityStyle]
    ) -> ([MKOverlay], [ObjectIdentifier: AreaStyle]) {
        var overlays: [MKOverlay] = []
        var map: [ObjectIdentifier: AreaStyle] = [:]
        for a in areas where !a.deleted && visibleIds.contains(a.id) {
            let style = StyleResolver.resolveArea(
                entity: a.styleEntity, viewStyle: viewStyles["area"]
            )
            if let r = AreaOverlayFactory.makeOverlay(for: a, style: style) {
                overlays.append(r.overlay)
                map[ObjectIdentifier(r.overlay)] = r.style
            }
        }
        return (overlays, map)
    }

    /// 视口裁剪:保留 region 外扩 margin(各方向 0.5×span)内的 pin。region 未知 → 全留。
    /// O(N) bbox 比较,无 styleEntity/resolve;pan settle 时随 body 重跑,交付集合随视口移动。
    private func viewportPins(_ pins: [MKAnnotation], region: MKCoordinateRegion?) -> [MKAnnotation] {
        guard let region else { return pins }
        let latPad = region.span.latitudeDelta
        let lonPad = region.span.longitudeDelta
        let minLat = region.center.latitude - latPad
        let maxLat = region.center.latitude + latPad
        let minLon = region.center.longitude - lonPad
        let maxLon = region.center.longitude + lonPad
        return pins.filter { annotation in
            let coord = annotation.coordinate
            return coord.latitude >= minLat && coord.latitude <= maxLat
                && coord.longitude >= minLon && coord.longitude <= maxLon
        }
    }

    private func flyTo(_ coord: CLLocationCoordinate2D) {
        camera = MKMapCamera(lookingAtCenter: coord, fromDistance: 2000, pitch: 0, heading: 0)
    }

    private func createPin(_ kind: EntityKind, layerId: UUID?, name: String = "") {
        guard let coord = pendingCoordinate, let dsId = viewContext?.datasetIdValue else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ref = EntityWriter.createPin(
            kind: kind, datasetId: dsId, name: trimmed.isEmpty ? "未命名" : trimmed,
            latitude: coord.latitude, longitude: coord.longitude, layerId: layerId, in: modelContext
        )
        searchMarker = nil
        searchPlace = nil
        showPlaceDetail = false
        createPrefillName = nil
        appState.select(ref)
        appState.beginEditing()
    }

    private func idKind(for id: UUID, in pins: [MKAnnotation]) -> EntityKind? {
        for case let p as PinAnnotation in pins where p.entityId == id {
            return EntityKind(rawValue: p.entityType)
        }
        return nil
    }

    /// 按 viewId 预取该视图 4 行 ViewEntityStyle → [entityType: ViewEntityStyle]。
    private func buildViewStyles(dsId: UUID, viewId: UUID?) -> [String: ViewEntityStyle] {
        guard let viewId else { return [:] }
        let fetch = FetchDescriptor<ViewEntityStyle>(
            predicate: #Predicate { $0.datasetId == dsId && $0.viewId == viewId && !$0.deleted }
        )
        let rows = (try? modelContext.fetch(fetch)) ?? []
        return Dictionary(rows.map { ($0.entityType, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// edge 投影:一次 Edge fetch(按两端分组)+ 复用预建 entityById(取对端 targetField/name)。
    /// 取代 edgeField 维度的 per-entity DB fetch —— rebuild 内全部 edgeField 解析转为纯内存查表。
    private func buildEdgeProjection(dsId: UUID, entityById: [UUID: StyleEntity]) -> EdgeProjection {
        let fetch = FetchDescriptor<Edge>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let edges = (try? modelContext.fetch(fetch)) ?? []
        var byEntity: [UUID: [EdgeProjection.E]] = [:]
        for edge in edges {
            let projected = EdgeProjection.E(fromId: edge.fromId, toId: edge.toId, label: edge.label)
            byEntity[edge.fromId, default: []].append(projected)
            byEntity[edge.toId, default: []].append(projected)
        }
        return EdgeProjection(edgesByEntity: byEntity, entityById: entityById)
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
