#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct ViewSettingsTab: View {
    @Bindable var viewContext: MapViewContext
    @Environment(\.modelContext) private var modelContext
    @Query private var palettes: [Palette]
    @Query private var cameraPresets: [CameraPreset]
    @Query private var layers: [Layer]

    @State private var primary = PrimaryFilter(conditions: [], groupBy: nil)
    @State private var normals: [NormalFilter] = []

    private let primaryEntityType = "school"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("视图", selection: activeBinding) {
                    ForEach(viewContext.allMapViews, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                }.font(.system(size: 12))
                Button { addView() } label: { Image(systemName: "plus") }
                if let mv = viewContext.activeMapView, viewContext.allMapViews.count > 1 {
                    Button(role: .destructive) { deleteView(mv) } label: { Image(systemName: "trash") }
                }
            }
            if let mv = viewContext.activeMapView {
                row("名称") { TextField("名称", text: nameBinding(mv)) }
                Text("可见类型").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                visibilityToggles(mv)
                Text("启用图层").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(layers.filter { $0.datasetId == mv.datasetId && !$0.deleted }, id: \.id) { layer in
                    Toggle(layer.name, isOn: layerBinding(mv, layer.id)).font(.system(size: 12))
                }
                Picker("调色板", selection: paletteBinding(mv)) {
                    Text("默认高对比").tag(UUID?.none)
                    ForEach(palettes.filter { !$0.deleted }, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                }.font(.system(size: 12))
                Picker("相机", selection: cameraBinding(mv)) {
                    Text("无").tag(UUID?.none)
                    ForEach(cameraPresets.filter { $0.datasetId == mv.datasetId && !$0.deleted }, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                }.font(.system(size: 12))
                Toggle("选中聚光", isOn: spotlightBinding(mv)).font(.system(size: 12))
                row("标题") { TextField("标题", text: optBinding(\.copyTitle, mv)) }
                row("副标题") { TextField("副标题", text: optBinding(\.copySubtitle, mv)) }
                row("水印") { TextField("水印", text: optBinding(\.copyWatermark, mv)) }
                Divider().opacity(0.4)
                PrimaryFilterEditor(filter: $primary, entityType: primaryEntityType, datasetId: mv.datasetId)
                    .onChange(of: primary) { _, new in mv.primaryFilterJSON = ViewConfigCodec.encodePrimary(new); mv.updatedAt = Date() }
                Divider().opacity(0.4)
                normalFiltersSection(mv)
            } else {
                Text("无视图").foregroundStyle(.secondary)
            }
        }
        .onAppear { loadFilters() }
        .onChange(of: viewContext.activeMapView?.id) { _, _ in loadFilters() }
    }

    private func loadFilters() {
        guard let mv = viewContext.activeMapView else { return }
        primary = ViewConfigCodec.decodePrimary(mv.primaryFilterJSON)
        normals = ViewConfigCodec.decodeNormals(mv.normalFiltersJSON)
    }

    private func normalFiltersSection(_ mv: MapView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("普通过滤(图例 + 计数)").font(.system(size: 12, weight: .bold))
            ForEach(normals.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("名称", text: Binding(get: { normals[i].name }, set: { normals[i].name = $0; saveNormals(mv) })).font(.system(size: 12))
                        Button(role: .destructive) { normals.remove(at: i); saveNormals(mv) } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
                    }
                    DimensionPicker(dimension: Binding(get: { normals[i].dimension }, set: { normals[i].dimension = $0; saveNormals(mv) }),
                                    entityType: primaryEntityType, datasetId: mv.datasetId)
                }
                .padding(8).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
            Button { normals.append(NormalFilter(name: "新过滤", dimension: MapDimension(kind: .field))); saveNormals(mv) }
                label: { Label("加普通过滤", systemImage: "plus") }.font(.system(size: 12))
        }
    }
    private func saveNormals(_ mv: MapView) { mv.normalFiltersJSON = ViewConfigCodec.encodeNormals(normals); mv.updatedAt = Date() }

    private func row<V: View>(_ label: String, @ViewBuilder _ content: () -> V) -> some View {
        HStack { Text(label).frame(width: 64, alignment: .leading).font(.system(size: 12)); content() }
    }
    private var activeBinding: Binding<UUID?> {
        Binding(get: { viewContext.activeMapView?.id }, set: { id in
            if let v = viewContext.allMapViews.first(where: { $0.id == id }) { viewContext.switchView(to: v) }
        })
    }
    private func nameBinding(_ mv: MapView) -> Binding<String> {
        Binding(get: { mv.name }, set: { mv.name = $0; mv.updatedAt = Date() })
    }
    private func optBinding(_ kp: ReferenceWritableKeyPath<MapView, String?>, _ mv: MapView) -> Binding<String> {
        Binding(get: { mv[keyPath: kp] ?? "" }, set: { mv[keyPath: kp] = $0.isEmpty ? nil : $0; mv.updatedAt = Date() })
    }
    private func spotlightBinding(_ mv: MapView) -> Binding<Bool> {
        Binding(get: { mv.spotlightOnSelect }, set: { mv.spotlightOnSelect = $0; mv.updatedAt = Date() })
    }
    private func paletteBinding(_ mv: MapView) -> Binding<UUID?> {
        Binding(get: { mv.paletteId }, set: { mv.paletteId = $0; mv.updatedAt = Date() })
    }
    private func cameraBinding(_ mv: MapView) -> Binding<UUID?> {
        Binding(get: { mv.cameraPresetId }, set: { mv.cameraPresetId = $0; mv.updatedAt = Date() })
    }
    private func layerBinding(_ mv: MapView, _ id: UUID) -> Binding<Bool> {
        Binding(get: { mv.enabledLayerIds.contains(id) }, set: { on in
            var s = Set(mv.enabledLayerIds); if on { s.insert(id) } else { s.remove(id) }
            mv.enabledLayerIds = Array(s); mv.updatedAt = Date()
        })
    }
    private func visibilityToggles(_ mv: MapView) -> some View {
        let types = [("compound","小区"),("school","学校"),("poi","POI"),("area","片区")]
        return ForEach(types, id: \.0) { t in
            Toggle(t.1, isOn: Binding(
                get: { (decodeVis(mv)[t.0] ?? true) },
                set: { on in var d = decodeVis(mv); d[t.0] = on; mv.visibilityJSON = encodeVis(d); mv.updatedAt = Date() }
            )).font(.system(size: 12))
        }
    }
    private func decodeVis(_ mv: MapView) -> [String: Bool] {
        (try? JSONSerialization.jsonObject(with: Data(mv.visibilityJSON.utf8)) as? [String: Bool]) ?? ["compound":true,"school":true,"poi":true,"area":true]
    }
    private func encodeVis(_ d: [String: Bool]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: d), let s = String(data: data, encoding: .utf8) else { return mvDefaultVis }
        return s
    }
    private let mvDefaultVis = #"{"compound":true,"school":true,"poi":true,"area":true}"#

    private func addView() {
        let v = MapView(datasetId: viewContext.datasetIdValue, name: "新视图")
        v.sortOrder = (viewContext.allMapViews.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(v)
        viewContext.switchView(to: v)
    }
    private func deleteView(_ mv: MapView) {
        mv.deleted = true; mv.updatedAt = Date()
        if let other = viewContext.allMapViews.first(where: { $0.id != mv.id }) { viewContext.switchView(to: other) }
    }
}
#endif
