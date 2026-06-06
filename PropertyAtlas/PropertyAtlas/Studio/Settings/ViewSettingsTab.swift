#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct ViewSettingsTab: View {
    @Bindable var viewContext: MapViewContext
    @Environment(\.modelContext) private var modelContext
    @Query private var cameraPresets: [CameraPreset]
    @Query private var layers: [Layer]

    @State private var primary = PrimaryFilter(conditions: [], groupBy: nil)
    @State private var normals: [NormalFilter] = []

    private let primaryEntityType = "school"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            viewSwitcher
            if let mv = viewContext.activeMapView {
                SettingsCard("视图") {
                    fieldRow("名称") { TextField("名称", text: nameBinding(mv)).glassField() }
                }
                ViewStyleSection(mv: mv)
                SettingsCard("分组染色调色板") {
                    PaletteHexEditor(view: mv).padding(.horizontal, 13).padding(.bottom, 12)
                }
                SettingsCard("可见类型") { visibilityChips(mv) }
                SettingsCard("启用图层") { layerToggles(mv) }
                SettingsCard("出图文案") {
                    VStack(alignment: .leading, spacing: 10) {
                        labeled("标题") { TextField("标题", text: optBinding(\.copyTitle, mv)).glassField() }
                        labeled("副标题") { TextField("副标题", text: optBinding(\.copySubtitle, mv)).glassField() }
                        labeled("水印") { TextField("水印", text: optBinding(\.copyWatermark, mv)).glassField() }
                    }.padding(.horizontal, 13).padding(.bottom, 12)
                }
                SettingsCard("引用") {
                    SettingsRow(title: "显示图例") {
                        Toggle("", isOn: Binding(
                            get: { mv.showLegend },
                            set: { mv.showLegend = $0
                                mv.updatedAt = Date()
                            }
                        )).labelsHidden().tint(Studio.cool)
                    }
                    RowDivider()
                    SettingsRow(title: "相机") {
                        Picker("", selection: cameraBinding(mv)) {
                            Text("无").tag(UUID?.none)
                            ForEach(cameraPresets.filter { $0.datasetId == mv.datasetId && !$0.deleted }, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                        }.labelsHidden().tint(Studio.cool)
                            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    }
                    RowDivider()
                    SettingsRow(title: "选中聚光") {
                        Toggle("", isOn: spotlightBinding(mv)).labelsHidden().tint(Studio.cool)
                    }
                }
                SettingsCard("主过滤 · 分组染色") {
                    PrimaryFilterEditor(filter: $primary, entityType: primaryEntityType, datasetId: mv.datasetId)
                        .onChange(of: primary) { _, new in mv.primaryFilterJSON = ViewConfigCodec.encodePrimary(new)
                            mv.updatedAt = Date()
                        }
                        .padding(.horizontal, 13).padding(.bottom, 12)
                }
                normalFiltersSection(mv)
            } else {
                Text("无视图").font(Studio.sans(13)).foregroundStyle(Studio.on2)
            }
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { loadFilters() }
        .onChange(of: viewContext.activeMapView?.id) { _, _ in loadFilters() }
    }

    private var viewSwitcher: some View {
        HStack(spacing: 8) {
            Text("视图").font(Studio.sans(11)).foregroundStyle(Studio.on2)
            Picker("", selection: activeBinding) {
                ForEach(viewContext.allMapViews, id: \.id) { Text($0.name).tag($0.id as UUID?) }
            }.labelsHidden().tint(Studio.cool)
                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            Spacer()
            Button { addView() } label: { Image(systemName: "plus") }
                .buttonStyle(.tbtn(.ghost))
            if let mv = viewContext.activeMapView, viewContext.allMapViews.count > 1, !isDefaultView(mv) {
                Button(role: .destructive) { deleteView(mv) } label: { Image(systemName: "trash") }
                    .buttonStyle(.tbtn(.dangerGhost))
            }
        }
    }

    private func loadFilters() {
        guard let mv = viewContext.activeMapView else { return }
        primary = ViewConfigCodec.decodePrimary(mv.primaryFilterJSON)
        normals = ViewConfigCodec.decodeNormals(mv.normalFiltersJSON)
    }

    private func normalFiltersSection(_ mv: MapView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "普通过滤(图例 + 计数)", trailing: "\(normals.count)")
            ForEach(normals.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("名称", text: Binding(get: { normals[i].name }, set: { normals[i].name = $0
                            saveNormals(mv)
                        })).glassField()
                        Button(role: .destructive) { normals.remove(at: i)
                            saveNormals(mv)
                        } label: { Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad) }.buttonStyle(.plain)
                    }
                    DimensionPicker(
                        dimension: Binding(get: { normals[i].dimension }, set: { normals[i].dimension = $0
                            saveNormals(mv)
                        }),
                        entityType: primaryEntityType,
                        datasetId: mv.datasetId
                    )
                }
                .padding(12)
                .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
            }
            AddRow("加普通过滤") { normals.append(NormalFilter(name: "新过滤", dimension: MapDimension(kind: .field)))
                saveNormals(mv)
            }
        }
    }

    private func saveNormals(_ mv: MapView) {
        mv.normalFiltersJSON = ViewConfigCodec.encodeNormals(normals)
        mv.updatedAt = Date()
    }

    private func fieldRow(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 12) {
            Text(label).frame(width: 64, alignment: .leading).font(Studio.sans(12)).foregroundStyle(Studio.on2)
            content()
        }.padding(.horizontal, 13).padding(.vertical, 10)
    }

    private func labeled(_ label: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            content()
        }
    }

    private func visibilityChips(_ mv: MapView) -> some View {
        let types = [("compound", "小区"), ("school", "学校"), ("poi", "POI"), ("area", "片区")]
        return FlowChips {
            ForEach(types, id: \.0) { t in
                let on = decodeVis(mv)[t.0] ?? true
                StudioChip(t.1, isOn: on) {
                    var d = decodeVis(mv)
                    d[t.0] = !on
                    mv.visibilityJSON = encodeVis(d)
                    mv.updatedAt = Date()
                }
            }
        }
        .padding(.horizontal, 13).padding(.bottom, 12)
    }

    private func layerToggles(_ mv: MapView) -> some View {
        let list = layers.filter { $0.datasetId == mv.datasetId && !$0.deleted }
        return VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { idx, layer in
                if idx > 0 { RowDivider() }
                SettingsRow(title: layer.name) {
                    Toggle("", isOn: layerBinding(mv, layer.id)).labelsHidden().tint(Studio.cool)
                }
            }
        }
    }

    private var activeBinding: Binding<UUID?> {
        Binding(get: { viewContext.activeMapView?.id }, set: { id in
            if let v = viewContext.allMapViews.first(where: { $0.id == id }) { viewContext.switchView(to: v) }
        })
    }

    private func nameBinding(_ mv: MapView) -> Binding<String> {
        Binding(get: { mv.name }, set: { mv.name = $0
            mv.updatedAt = Date()
        })
    }

    private func optBinding(_ kp: ReferenceWritableKeyPath<MapView, String?>, _ mv: MapView) -> Binding<String> {
        Binding(get: { mv[keyPath: kp] ?? "" }, set: { mv[keyPath: kp] = $0.isEmpty ? nil : $0
            mv.updatedAt = Date()
        })
    }

    private func spotlightBinding(_ mv: MapView) -> Binding<Bool> {
        Binding(get: { mv.spotlightOnSelect }, set: { mv.spotlightOnSelect = $0
            mv.updatedAt = Date()
        })
    }

    private func cameraBinding(_ mv: MapView) -> Binding<UUID?> {
        Binding(get: { mv.cameraPresetId }, set: { mv.cameraPresetId = $0
            mv.updatedAt = Date()
        })
    }

    private func layerBinding(_ mv: MapView, _ id: UUID) -> Binding<Bool> {
        Binding(get: { mv.enabledLayerIds.contains(id) }, set: { on in
            var s = Set(mv.enabledLayerIds)
            if on { s.insert(id) } else { s.remove(id) }
            mv.enabledLayerIds = Array(s)
            mv.updatedAt = Date()
        })
    }

    private func decodeVis(_ mv: MapView) -> [String: Bool] {
        let fallback: [String: Bool] = ["compound": true, "school": true, "poi": true, "area": true]
        return (try? JSONSerialization.jsonObject(with: Data(mv.visibilityJSON.utf8)) as? [String: Bool]) ?? fallback
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

    /// 默认视图 = sortOrder 最小者(首个 seed 的视图),不可删。
    private func isDefaultView(_ mv: MapView) -> Bool {
        guard let minOrder = viewContext.allMapViews.map(\.sortOrder).min() else { return false }
        return mv.sortOrder == minOrder
    }

    private func deleteView(_ mv: MapView) {
        guard !isDefaultView(mv) else { return }
        mv.deleted = true
        mv.updatedAt = Date()
        if let other = viewContext.allMapViews.first(where: { $0.id != mv.id }) { viewContext.switchView(to: other) }
    }
}

/// Simple wrapping HStack for chips (mirrors `.chip-row`).
private struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 7) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
