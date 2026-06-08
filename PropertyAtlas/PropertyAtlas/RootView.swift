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
    @Query private var viewStyleRules: [ViewStyleRule]
    @Query private var viewStyleConditions: [ViewStyleCondition]

    @State private var filterState = DimensionFilterState()
    @State private var layerState = LayerState()
    @State private var viewContext: MapViewContext?
    @State private var camera: MKMapCamera = .init(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 39.125, longitude: 117.205),
        fromDistance: 12000, pitch: 0, heading: 0
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var appState = AppState()
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    /// 地点详情卡的锚点(屏幕坐标,双击/选 POI 时记录)→ 卡浮在鼠标下方。
    @State private var placePoint: CGPoint?
    @State private var drawMode = false
    @State private var areaDrawMode = false
    @State private var areaDrawPoints: [CLLocationCoordinate2D] = []
    /// 当前绘制几何类型(多边形 / 折线)。
    @State private var areaDrawKind: AreaDrawKind = .polygon
    /// 非 nil = 正在重绘某区域(完成时替换其几何,而非新建)。
    @State private var redrawAreaId: UUID?
    @State private var showCreateMenu = false
    @State private var showSettings = false
    /// 从设置页导航到实体详情时置位;详情关闭(selectedRef→nil)后据此重新唤起设置页。
    @State private var reopenSettingsOnDeselect = false

    /// 视图配置(底图样式 / 画幅 / Apple 地点)持有在 active MapView 上 → 工具栏与设置「基本」tab 联动。
    private var activeMV: MapView? {
        viewContext?.activeMapView
    }

    private func touchMV() {
        activeMV?.updatedAt = Date()
    }

    private var mapStyle: StudioMapStyle {
        StudioMapStyle.resolve(activeMV?.studioMapStyleRaw ?? "")
    }

    private var mapStyleBinding: Binding<StudioMapStyle> {
        Binding(get: { mapStyle }, set: { activeMV?.studioMapStyleRaw = $0.rawValue
            touchMV()
        })
    }

    private var aspect: CanvasAspect {
        CanvasAspect(rawValue: activeMV?.canvasAspectRaw ?? "") ?? .ratio16x9
    }

    private var aspectBinding: Binding<CanvasAspect> {
        Binding(get: { aspect }, set: { activeMV?.canvasAspectRaw = $0.rawValue
            touchMV()
        })
    }

    private var selectedPOIOptions: Set<StudioPOIOption> {
        Set((activeMV?.poiCategoriesRaw ?? "").split(separator: ",").compactMap { StudioPOIOption(rawValue: String($0)) })
    }

    /// 未开 POI → 全不显示;开了但没选类别 → 全部;选了 → 仅这些类别。
    private var poiFilter: MKPointOfInterestFilter {
        guard activeMV?.poiEnabled ?? false else { return .excludingAll }
        let cats = selectedPOIOptions
        return cats.isEmpty ? .includingAll : MKPointOfInterestFilter(including: cats.map(\.category))
    }

    private var poiSignature: String {
        "\(mapStyle.rawValue)|\(activeMV?.poiEnabled ?? false)|\(activeMV?.poiCategoriesRaw ?? "")"
    }

    private var poiEnabledBinding: Binding<Bool> {
        Binding(get: { activeMV?.poiEnabled ?? false }, set: { activeMV?.poiEnabled = $0
            touchMV()
        })
    }

    private var poiCategoriesBinding: Binding<Set<StudioPOIOption>> {
        Binding(
            get: { selectedPOIOptions },
            set: { activeMV?.poiCategoriesRaw = $0.map(\.rawValue).sorted().joined(separator: ",")
                touchMV()
            }
        )
    }

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
                    // 折线区域:styleMap 命中 → 描边渲染;未命中的 MKPolyline(edge 连线)走默认。
                    if let style = cache.styleMap[ObjectIdentifier(overlay)] {
                        let color = HexColor.parse(style.fillHex) ?? HexColor.parse(style.strokeHex) ?? .systemTeal
                        let width = max(CGFloat(style.strokeWidth), 4)
                        if let line = overlay as? MKPolyline {
                            let r = MKPolylineRenderer(polyline: line)
                            r.strokeColor = color
                            r.lineWidth = width
                            r.lineCap = .round
                            r.lineJoin = .round
                            return r
                        }
                        if let mline = overlay as? MKMultiPolyline {
                            let r = MKMultiPolylineRenderer(multiPolyline: mline)
                            r.strokeColor = color
                            r.lineWidth = width
                            r.lineCap = .round
                            r.lineJoin = .round
                            return r
                        }
                    }
                    return nil
                },
                onRegionChange: { visibleRegion = $0 },
                onSchoolSelect: { id in
                    // 地图上直接选 pin → 不属于"从设置导航",撤销重开设置标记。
                    reopenSettingsOnDeselect = false
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
                },
                onDoubleTapCoordinate: { pt, coord in
                    placePoint = pt
                    Task { await lookupPlace(at: coord) }
                },
                onSelectMapFeature: { pt, feature in
                    // 系统底图 POI(卫星/混合)点击 → 复用外部地点详情卡(浮在点击处)。
                    // 先用 feature 自带 title/坐标立即弹卡(大陆高德数据 getMapItem 常返回 nil),
                    // 再异步主线程取 MKMapItem 补全电话/网址/分类。
                    reopenSettingsOnDeselect = false
                    appState.clearSelection()
                    placePoint = pt
                    let coord = feature.coordinate
                    let name = feature.title ?? "地点"
                    searchPlace = ExternalPlaceSearch.PlaceHit(
                        name: name, subtitle: "", coordinate: coord,
                        category: nil, phone: nil, url: nil, fullAddress: nil
                    )
                    searchMarker = SearchMarker(coordinate: coord, name: name)
                    showPlaceDetail = true
                    let request = MKMapItemRequest(mapFeatureAnnotation: feature)
                    request.getMapItem { item, _ in
                        guard let item else { return }
                        DispatchQueue.main.async {
                            searchPlace = ExternalPlaceSearch.placeHit(from: item)
                        }
                    }
                },
                mapStyle: mapStyle,
                poiFilter: poiFilter,
                poiSignature: poiSignature
            )
            .ignoresSafeArea()

            // 自由绘图层:盖在地图上方、chrome 下方(无 zIndex → 按顺序在 StudioOverlay 之下,工具栏仍可点)
            if drawMode {
                FreeDrawCanvas(active: $drawMode)
                    .ignoresSafeArea()
            }
            // 绘制区域层:点击放顶点(同样在 chrome 之下)
            if areaDrawMode {
                AreaDrawLayer(points: $areaDrawPoints, region: visibleRegion, closed: areaDrawKind == .polygon)
                    .ignoresSafeArea()
            }

            if let ctx = viewContext {
                StudioOverlay(
                    aspect: aspectBinding, viewContext: ctx, showSettings: $showSettings,
                    exportMode: $exportMode, showSafeFrame: $showSafeFrame, showSearch: $showSearch,
                    mapStyle: mapStyleBinding,
                    poiEnabled: poiEnabledBinding,
                    poiCategories: poiCategoriesBinding,
                    drawMode: $drawMode,
                    areaDrawMode: $areaDrawMode,
                    areaDrawKind: $areaDrawKind,
                    hideWatermark: !exportMode && (appState.selectedRef != nil || showPlaceDetail)
                )
            }

            if areaDrawMode {
                VStack {
                    AreaDrawPanel(
                        count: areaDrawPoints.count,
                        kind: areaDrawKind,
                        onUndo: { if !areaDrawPoints.isEmpty { areaDrawPoints.removeLast() } },
                        onFinish: { finishAreaDraw() },
                        onCancel: { areaDrawPoints = []
                            areaDrawMode = false
                            redrawAreaId = nil
                        }
                    )
                    .padding(.top, 96)
                    Spacer()
                }
                .zIndex(35)
            }

            if !exportMode, showSearch {
                VStack {
                    Spacer()
                    StudioSearchPanel(
                        datasetId: dsId,
                        visibleRegion: visibleRegion,
                        onPickEntity: { ref, coord, hasCoord in
                            appState.select(ref)
                            focusOnSelect(ref, coord, hasCoord)
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

            if !exportMode, !areaDrawMode {
                GeometryReader { geo in
                    HStack {
                        Spacer()
                        Group {
                            if showCreateMenu {
                                createDrawer(dsId: dsId)
                            } else {
                                RightDrawer(
                                    appState: appState, datasetId: dsId,
                                    onRedrawArea: { startAreaRedraw($0) },
                                    // 顶到底部 dock 上方:屏高 − 顶距80 − 底部 dock 区(22+52+14)。
                                    maxHeight: max(280, geo.size.height - 80 - 88)
                                )
                            }
                        }
                        .frame(width: geo.size.width * 0.382)
                        .padding(.top, 80).padding(.trailing, 16).padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                .animation(.easeInOut(duration: 0.2), value: appState.selectedRef)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // 地点详情卡:浮在鼠标(双击点 / POI 点击点)下方,离近。
            if !exportMode, showPlaceDetail, let place = searchPlace, let pt = placePoint {
                GeometryReader { geo in
                    let cardW: CGFloat = 300
                    let x = min(max(pt.x, 16), geo.size.width - cardW - 16)
                    let y = min(pt.y + 14, geo.size.height - 120)
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
                    .frame(width: cardW)
                    .offset(x: x, y: y)
                }
                .transition(.opacity)
                .zIndex(20)
            }

            if !exportMode, !areaDrawMode {
                GeometryReader { geo in
                    HStack {
                        LeftDrawerView(
                            legendSections: legendSections,
                            layers: layersForDataset(dsId),
                            currentZoom: zoom,
                            filterState: filterState,
                            layerState: layerState,
                            onToggleLayer: { toggleLayer($0) },
                            onToggleChip: { toggleChip($0, $1) },
                            // 顶到指南针上方:屏高 − 顶距80 − 指南针区(88+22)− 间隙16。
                            maxHeight: max(200, geo.size.height - 80 - 126)
                        )
                        .padding(.top, 80).padding(.leading, 16)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // 指南针:左下角,随地图方向扭转,双击恢复正北。
            if !exportMode {
                VStack {
                    Spacer()
                    HStack {
                        CompassView(heading: camera.heading, onResetNorth: resetNorth)
                            .padding(.leading, 16).padding(.bottom, 22)
                        Spacer()
                    }
                }
            }

            // 设置抽屉:右侧浮层,宽=屏×0.382,上下占满,浮于一切之上。
            // 点 scrim / 完成 关闭。出图模式下隐藏(与其它 chrome 一致)。
            if !exportMode, showSettings, let ctx = viewContext {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { showSettings = false }
                    .transition(.opacity)
                    .zIndex(39)

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        SettingsSheet(
                            viewContext: ctx,
                            onClose: { showSettings = false },
                            onEntitySelect: { ref, coord, hasCoord in
                                appState.select(ref)
                                focusOnSelect(ref, coord, hasCoord)
                                reopenSettingsOnDeselect = true
                                showSettings = false
                            },
                            onEntityEdit: { ref, coord, hasCoord in
                                appState.select(ref)
                                appState.beginEditing()
                                focusOnSelect(ref, coord, hasCoord)
                                reopenSettingsOnDeselect = true
                                showSettings = false
                            }
                        )
                        .frame(width: geo.size.width * 0.382)
                        // 顶 44 让出菜单/标题栏;底 88 清开底部浮动工具栏(dock 在 bottom 22 + 高约 52)
                        .padding(.top, 44)
                        .padding(.bottom, 88)
                        .padding(.trailing, 16)
                    }
                }
                .ignoresSafeArea()
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(40)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: exportMode)
        .animation(.easeInOut(duration: 0.25), value: showSettings)
        .onChange(of: viewContext?.activeMapView?.id) { _, _ in
            layerState.resetForTheme(enabledIds: viewContext?.activeMapView?.enabledLayerIds ?? [])
            restoreChips()
            searchMarker = nil
            searchPlace = nil
            showPlaceDetail = false
            showSearch = false
        }
        .onAppear { ensureViewContext()
            restoreChips()
            configureTitlebar()
        }
        .onChange(of: datasets.first?.id) { _, _ in ensureViewContext() }
        // 视图设置改「启用图层」→ 同步 layerState(与左抽屉图层开关联动)
        .onChange(of: viewContext?.activeMapView?.enabledLayerIds) { _, new in
            if let new { layerState.initialize(enabledIds: new) }
        }
        .onChange(of: appState.selectedRef) { _, newValue in
            // 从设置导航来的详情关闭(esc/×)→ 重新唤起设置页。
            if newValue == nil, reopenSettingsOnDeselect {
                reopenSettingsOnDeselect = false
                showSettings = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioPresetSelected)) { note in
            // Studio 菜单「跳到 …」机位 → 飞到该预设相机。
            guard let preset = note.object as? StudioCameraPreset else { return }
            camera = preset.camera
        }
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
        hasher.combine(activeMapView?.spotlightOnSelect ?? false)
        hasher.combine((activeMapView?.drawEdgeLines ?? []).sorted().joined(separator: ","))
        hasher.combine((activeMapView?.paletteHex ?? []).joined(separator: ","))
        hasher.combine(activeMapView?.showLegend ?? true)
        let activeViewId = activeMapView?.id ?? UUID()
        let styleFetch = FetchDescriptor<ViewEntityStyle>(
            predicate: #Predicate { $0.datasetId == dsId && $0.viewId == activeViewId && !$0.deleted }
        )
        for row in (try? modelContext.fetch(styleFetch)) ?? [] {
            hasher.combine(row.viewId)
            hasher.combine(row.entityType)
            hasher.combine(row.updatedAt)
        }
        combineRuleSignature(&hasher, dsId: dsId, activeViewId: activeViewId)
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

    /// 活跃视图的样式规则 + 条件签名(纯内存,走 @Query)。count 抓增删,maxUpdatedAt 抓改,
    /// priority/enabled 单独并入 —— 改任一即触发 rebuild,但 pan/zoom 不打 DB。
    private func combineRuleSignature(_ hasher: inout Hasher, dsId: UUID, activeViewId: UUID) {
        let activeRules = viewStyleRules.filter { $0.viewId == activeViewId && $0.datasetId == dsId && !$0.deleted }
        hasher.combine(activeRules.count)
        var rulesMaxUpdated = Date.distantPast
        for rule in activeRules {
            hasher.combine(rule.priority)
            hasher.combine(rule.enabled)
            if rule.updatedAt > rulesMaxUpdated { rulesMaxUpdated = rule.updatedAt }
        }
        hasher.combine(rulesMaxUpdated)
        let activeRuleIds = Set(activeRules.map(\.id))
        let activeConds = viewStyleConditions.filter { activeRuleIds.contains($0.ruleId) && !$0.deleted }
        hasher.combine(activeConds.count)
        var condsMaxUpdated = Date.distantPast
        for condition in activeConds {
            if condition.updatedAt > condsMaxUpdated { condsMaxUpdated = condition.updatedAt }
        }
        hasher.combine(condsMaxUpdated)
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
        let viewRules = buildViewStyleRules(dsId: dsId, viewId: activeMapView?.id)
        let palette = activeMapView.flatMap { $0.paletteHex.isEmpty ? nil : $0.paletteHex }
            ?? PaletteAssigner.highContrast
        // 分组染色只作用于主过滤器绑定的实体类型(空 entityType → 不染)
        let groupItems = cands
            .filter { visibleIds.contains($0.id) && !primary.entityType.isEmpty && $0.type == primary.entityType }
            .map { GroupColorResolver.Item(id: $0.id, entity: $0.entity, layerNames: membership[$0.id] ?? []) }
        let groupColors = GroupColorResolver.colors(
            items: groupItems, groupBy: primary.groupBy, palette: palette,
            context: modelContext, datasetId: dsId,
            edgeProjection: edgeProjection, cache: dimCache
        )
        let pins = buildPins(
            cands: cands, visibleIds: visibleIds, groupColors: groupColors,
            viewStyles: viewStyles, viewRules: viewRules, highlight: highlight
        )
        // 选中片区 → 即便所在层/过滤隐藏也强制绘制(配合 focusArea 自动 focus)
        let selectedAreaId = appState.selectedRef?.kind == .area ? appState.selectedRef?.id : nil
        let dsAreas = areas.filter { $0.datasetId == dsId }
        let (areaOverlays, styleMap) = buildAreaOverlays(
            areas: visibility["area"] == true ? dsAreas : dsAreas.filter { $0.id == selectedAreaId },
            visibleIds: visibleIds, viewStyles: viewStyles, viewRules: viewRules,
            groupColors: groupColors, forceId: selectedAreaId
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
        /// entityType 非空时只计入该类型实体(图例/计数按实体 scope)
        func entriesFor(_ ids: Set<UUID>, _ dim: MapDimension, entityType: String, prefixOne: Bool) -> [LegendSpec.Entry] {
            cands.filter { ids.contains($0.id) && (entityType.isEmpty || $0.type == entityType) }.map { cand in
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
            let entries = entriesFor(visibleIds, gb, entityType: primary.entityType, prefixOne: true)
            let distinct = Array(Set(entries.flatMap(\.values)))
            let assign = PaletteAssigner.assign(values: distinct, palette: palette)
            specs.append(LegendSpec(
                title: legendTitle(for: gb, fallback: "分组"), dimensionKey: gb.key,
                togglable: false, dropZeroViewport: true, swatch: assign, entries: entries
            ))
        }
        for nf in normals {
            let entries = entriesFor(normalLegendIds, nf.dimension, entityType: nf.entityType, prefixOne: false)
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
        viewStyles: [String: ViewEntityStyle], viewRules: [String: [ResolvedStyleRule]],
        highlight: Set<UUID>?
    ) -> [MKAnnotation] {
        var result: [MKAnnotation] = []
        for c in cands where c.type != "area" && c.hasCoordinate && visibleIds.contains(c.id) {
            let style = StyleResolver.resolvePin(
                entity: c.entity, viewStyle: viewStyles[c.type],
                rules: viewRules[c.type] ?? [], groupFillHex: groupColors[c.id]
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
        areas: [Area], visibleIds: Set<UUID>, viewStyles: [String: ViewEntityStyle],
        viewRules: [String: [ResolvedStyleRule]], groupColors: [UUID: String] = [:], forceId: UUID? = nil
    ) -> ([MKOverlay], [ObjectIdentifier: AreaStyle]) {
        var overlays: [MKOverlay] = []
        var map: [ObjectIdentifier: AreaStyle] = [:]
        for a in areas where !a.deleted && (visibleIds.contains(a.id) || a.id == forceId) {
            let style = StyleResolver.resolveArea(
                entity: a.styleEntity, viewStyle: viewStyles["area"], rules: viewRules["area"] ?? [],
                groupFillHex: groupColors[a.id]
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

    /// 选中实体后 focus:片区按多边形包围盒 fit,其余实体按坐标 flyTo。
    private func focusOnSelect(_ ref: EntityRef, _ coord: CLLocationCoordinate2D?, _ hasCoord: Bool) {
        if ref.kind == .area {
            focusArea(ref.id)
        } else if hasCoord, let coord {
            flyTo(coord)
        }
    }

    /// 片区聚焦:解析 geometryJSON 多边形 → 包围盒中心 + 视距。无几何则不动。
    private func focusArea(_ id: UUID) {
        guard let a = areas.first(where: { $0.id == id }) else { return }
        let coords = (
            a.geometryKind == "line"
                ? (try? GeoJSONHelper.decodeLines(a.geometryJSON))?.flatMap { $0 }
                : try? GeoJSONHelper.decodePolygon(a.geometryJSON)
        ) ?? []
        guard !coords.isEmpty, let fit = AreaFocus.fit(coordinates: coords) else { return }
        camera = MKMapCamera(lookingAtCenter: fit.center, fromDistance: fit.distance, pitch: 0, heading: 0)
    }

    /// 指南针双击:保持中心/距离/俯仰,heading 归零(正北朝上)。
    private func resetNorth() {
        camera = MKMapCamera(
            lookingAtCenter: camera.centerCoordinate,
            fromDistance: camera.centerCoordinateDistance,
            pitch: camera.pitch,
            heading: 0
        )
    }

    /// 双击地图空白:逆地理编码坐标 → 复用外部地点详情卡(ExternalPlaceCard)。
    private func lookupPlace(at coord: CLLocationCoordinate2D) async {
        searchMarker = SearchMarker(coordinate: coord, name: "查询中…")
        showPlaceDetail = false
        do {
            if let hit = try await ExternalPlaceSearch.reverseGeocode(coord) {
                searchPlace = hit
                searchMarker = SearchMarker(coordinate: hit.coordinate, name: hit.name)
                showPlaceDetail = true
            } else {
                searchMarker = nil
            }
        } catch {
            searchMarker = nil
        }
    }

    /// 新建实体抽屉(右侧,与实体详情一致)。原为居中 .sheet,现做成抽屉。
    @ViewBuilder
    private func createDrawer(dsId: UUID) -> some View {
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

    /// 进入区域重绘:按原几何类型(line/polygon)从空白打点;聚焦原区域便于参照。
    private func startAreaRedraw(_ id: UUID) {
        redrawAreaId = id
        areaDrawPoints = []
        areaDrawKind = (areas.first(where: { $0.id == id })?.geometryKind == "line") ? .line : .polygon
        focusArea(id)
        areaDrawMode = true
    }

    /// 完成绘制:顶点 → GeoJSON(Polygon / LineString)。重绘态替换原几何;否则新建 Area(默认层)。
    private func finishAreaDraw() {
        guard areaDrawPoints.count >= areaDrawKind.minPoints, let dsId = viewContext?.datasetIdValue else { return }
        let isLine = areaDrawKind == .line
        let geo = (
            isLine
                ? try? GeoJSONHelper.encodeLine(areaDrawPoints)
                : try? GeoJSONHelper.encodePolygon(areaDrawPoints)
        ) ?? ""
        let kindStr = isLine ? "line" : "polygon"

        if let id = redrawAreaId {
            if let a = EntityReader.fetch(Area.self, id, modelContext) {
                a.geometryJSON = geo
                a.geometryKind = kindStr
                a.updatedAt = Date()
            }
            try? modelContext.save()
            areaDrawPoints = []
            areaDrawMode = false
            redrawAreaId = nil
            return // 保留原选中 + 编辑态,抽屉随 areaDrawMode=false 恢复
        }

        let layerId = layersForDataset(dsId).first(where: { $0.isDefault })?.id
        let ref = EntityWriter.createPin(
            kind: .area, datasetId: dsId, name: isLine ? "新折线" : "新区域",
            latitude: 0, longitude: 0, layerId: layerId, in: modelContext
        )
        if let a = EntityReader.fetch(Area.self, ref.id, modelContext) {
            a.geometryJSON = geo
            a.geometryKind = kindStr
            if isLine { a.category = "道路" } // 折线默认归"道路"类型
            a.updatedAt = Date()
        }
        try? modelContext.save()
        areaDrawPoints = []
        areaDrawMode = false
        appState.select(ref)
        appState.beginEditing()
    }

    /// 切换普通过滤 chip 隐藏 + 持久到 active MapView.hiddenChipsJSON。
    private func toggleChip(_ dimKey: String, _ value: String) {
        filterState.toggle(dimensionKey: dimKey, value: value)
        guard let mv = viewContext?.activeMapView,
              let data = try? JSONEncoder().encode(filterState.snapshot()),
              let s = String(data: data, encoding: .utf8) else { return }
        mv.hiddenChipsJSON = s
        mv.updatedAt = Date()
    }

    /// 从 active MapView.hiddenChipsJSON 恢复 chip 隐藏态(切视图/启动)。
    private func restoreChips() {
        guard let mv = viewContext?.activeMapView,
              let data = mv.hiddenChipsJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            filterState.reset()
            return
        }
        filterState.load(dict)
    }

    /// 切换图层启用:写回 active MapView.enabledLayerIds(持久,单一数据源)+ 同步 layerState。
    /// 视图设置「启用图层」也改同一字段 → 两处联动。
    private func toggleLayer(_ id: UUID) {
        guard let mv = viewContext?.activeMapView else { layerState.toggle(id)
            return
        }
        if mv.enabledLayerIds.contains(id) {
            mv.enabledLayerIds.removeAll { $0 == id }
        } else {
            mv.enabledLayerIds.append(id)
        }
        mv.updatedAt = Date()
        layerState.initialize(enabledIds: mv.enabledLayerIds)
    }

    private func idKind(for id: UUID, in pins: [MKAnnotation]) -> EntityKind? {
        for case let p as PinAnnotation in pins where p.entityId == id {
            return EntityKind(rawValue: p.entityType)
        }
        return nil
    }

    /// 按 viewId 预取该视图的 ViewEntityStyle → [entityType: ViewEntityStyle]。
    private func buildViewStyles(dsId: UUID, viewId: UUID?) -> [String: ViewEntityStyle] {
        guard let viewId else { return [:] }
        let fetch = FetchDescriptor<ViewEntityStyle>(
            predicate: #Predicate { $0.datasetId == dsId && $0.viewId == viewId && !$0.deleted }
        )
        let rows = (try? modelContext.fetch(fetch)) ?? []
        return Dictionary(rows.map { ($0.entityType, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// 按 viewId 预取该视图全部 ViewStyleRule(+ 各自 ViewStyleCondition)→ 按 entityType 分组、
    /// priority 升序的 ResolvedStyleRule。resolver 纯内存,不再查 DB。
    private func buildViewStyleRules(dsId: UUID, viewId: UUID?) -> [String: [ResolvedStyleRule]] {
        guard let viewId else { return [:] }
        let ruleFetch = FetchDescriptor<ViewStyleRule>(
            predicate: #Predicate { $0.datasetId == dsId && $0.viewId == viewId && !$0.deleted },
            sortBy: [SortDescriptor(\.priority)]
        )
        let rules = (try? modelContext.fetch(ruleFetch)) ?? []
        var out: [String: [ResolvedStyleRule]] = [:]
        for rule in rules {
            let ruleId = rule.id
            let condFetch = FetchDescriptor<ViewStyleCondition>(
                predicate: #Predicate { $0.ruleId == ruleId && !$0.deleted },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            let conditions = ((try? modelContext.fetch(condFetch)) ?? []).map { condition in
                ViewStyleConditionCodec.styleCondition(
                    field: condition.field,
                    op: StyleConditionOp(rawValue: condition.op) ?? .equals,
                    valueString: condition.valueString, valueList: condition.valueList
                )
            }
            let resolved = ResolvedStyleRule(
                pinPartial: StyleFieldConvert.pinPartial(
                    shape: rule.shape, fillHex: rule.fillHex, strokeHex: rule.strokeHex,
                    glyph: rule.glyph, glyphHex: rule.glyphHex, size: rule.size, labelVisible: rule.labelVisible
                ),
                areaPartial: StyleFieldConvert.areaPartial(
                    fillHex: rule.fillHex, fillOpacity: rule.fillOpacity,
                    strokeHex: rule.strokeHex, strokeWidth: rule.strokeWidth, labelVisible: rule.labelVisible
                ),
                priority: rule.priority, enabled: rule.enabled, conditions: conditions
            )
            out[rule.entityType, default: []].append(resolved)
        }
        return out
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
    }

    /// 隐藏标题文字 + 去 toolbar/分隔线(公开 API),再经 NSWindow 反射去毛玻璃材质。
    private func configureTitlebar() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene, let titlebar = windowScene.titlebar else { continue }
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
            titlebar.separatorStyle = .none
        }
        // NSWindow 首帧可能未就绪,延迟再跑一次。
        makeNSWindowTitlebarTransparent()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { makeNSWindowTitlebarTransparent() }
    }

    /// Catalyst 无公开 API 去 titlebar 毛玻璃 → 经 NSApplication 反射设
    /// titlebarAppearsTransparent + fullSizeContentView(1<<15)+ 透明背景。
    /// 全程 KVC 真属性 + responds 守卫,防 NSException 崩溃;失败静默(best-effort)。
    private func makeNSWindowTitlebarTransparent() {
        guard let appClass = NSClassFromString("NSApplication") as? NSObject.Type,
              let sharedApp = appClass.value(forKey: "sharedApplication") as? NSObject,
              let windows = sharedApp.value(forKey: "windows") as? [NSObject] else { return }
        let clearColor = (NSClassFromString("NSColor") as? NSObject.Type)?.value(forKey: "clearColor")
        for window in windows {
            if window.responds(to: NSSelectorFromString("setTitlebarAppearsTransparent:")) {
                window.setValue(true, forKey: "titlebarAppearsTransparent")
            }
            if let mask = window.value(forKey: "styleMask") as? UInt {
                window.setValue(mask | (1 << 15), forKey: "styleMask") // .fullSizeContentView
            }
            if window.responds(to: NSSelectorFromString("setOpaque:")) {
                window.setValue(false, forKey: "opaque")
            }
            if let clearColor, window.responds(to: NSSelectorFromString("setBackgroundColor:")) {
                window.setValue(clearColor, forKey: "backgroundColor")
            }
        }
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
