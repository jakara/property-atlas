#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct LayerSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var layers: [Layer]
    @Query private var themes: [Theme]

    private var dsLayers: [Layer] {
        layers.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.zIndex < $1.zIndex }
    }
    private var dsThemes: [Theme] { themes.filter { $0.datasetId == datasetId && !$0.deleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("图层").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addLayer() } label: { Label("新图层", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(dsLayers, id: \.id) { layer in layerCard(layer) }
        }
    }

    private func layerCard(_ l: Layer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { l.name }, set: { l.name = $0; l.updatedAt = Date() })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { l.deleted = true; l.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                Text("zIndex").font(.system(size: 11)).foregroundStyle(.secondary)
                Stepper(value: Binding(get: { l.zIndex }, set: { l.zIndex = $0; l.updatedAt = Date() }), in: 0...999) { Text("\(l.zIndex)").font(.system(size: 12).monospacedDigit()) }
            }
            Picker("主题", selection: Binding(get: { l.themeId }, set: { l.themeId = $0; l.updatedAt = Date() })) {
                Text("无").tag(UUID?.none)
                ForEach(dsThemes, id: \.id) { Text($0.name).tag($0.id as UUID?) }
            }.font(.system(size: 12))
            ColorHexField(title: "图例色", hex: Binding(get: { l.colorHex ?? "" }, set: { l.colorHex = $0.isEmpty ? nil : ColorHexField.normalize($0); l.updatedAt = Date() }))
            HStack {
                Text("SF 图标").frame(width: 84, alignment: .leading).font(.system(size: 12))
                TextField("如 building.2", text: Binding(get: { l.iconSF ?? "" }, set: { l.iconSF = $0.isEmpty ? nil : $0; l.updatedAt = Date() })).font(.system(size: 12))
            }
            HStack {
                Toggle("启用", isOn: Binding(get: { l.enabled }, set: { l.enabled = $0; l.updatedAt = Date() })).font(.system(size: 12))
                Toggle("默认开", isOn: Binding(get: { l.isDefault }, set: { l.isDefault = $0; l.updatedAt = Date() })).font(.system(size: 12))
            }
            HStack {
                zoomField("minZoom", get: { l.minZoom }, set: { l.minZoom = $0; l.updatedAt = Date() })
                zoomField("maxZoom", get: { l.maxZoom }, set: { l.maxZoom = $0; l.updatedAt = Date() })
            }
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func zoomField(_ title: String, get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("—", text: Binding(get: { get().map { String(Int($0)) } ?? "" }, set: { set($0.isEmpty ? nil : Double($0)) }))
                .font(.system(size: 12).monospaced()).frame(width: 44)
        }
    }

    private func addLayer() {
        let l = Layer(datasetId: datasetId, name: "新图层")
        l.zIndex = (dsLayers.map(\.zIndex).max() ?? 0) + 1
        l.sortOrder = l.zIndex
        modelContext.insert(l)
    }
}
#endif
