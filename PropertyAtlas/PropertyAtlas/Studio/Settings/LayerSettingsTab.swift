#if targetEnvironment(macCatalyst)
import CoreLocation
import SwiftData
import SwiftUI

struct LayerSettingsTab: View {
    let datasetId: UUID
    let onSelect: (EntityRef, CLLocationCoordinate2D?, Bool) -> Void
    let onEdit: (EntityRef, CLLocationCoordinate2D?, Bool) -> Void
    @Environment(\.modelContext) private var modelContext
    @Query private var layers: [Layer]

    private var dsLayers: [Layer] {
        layers.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.zIndex < $1.zIndex }
    }

    @State private var selectedLayerId: UUID?

    private var selectedLayer: Layer? {
        dsLayers.first { $0.id == selectedLayerId } ?? dsLayers.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("图层").font(Studio.sans(11)).foregroundStyle(Studio.on2)
                Picker("", selection: layerPickerBinding) {
                    ForEach(dsLayers, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                }
                .labelsHidden().tint(Studio.cool)
                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                Spacer()
                Button { addLayer() } label: { Image(systemName: "plus") }
                    .buttonStyle(.tbtn(.ghost))
            }
            if let layer = selectedLayer {
                layerCard(layer)
            } else {
                Text("无图层").font(Studio.sans(13)).foregroundStyle(Studio.on2)
            }
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { if selectedLayerId == nil { selectedLayerId = dsLayers.first?.id } }
    }

    private var layerPickerBinding: Binding<UUID?> {
        Binding(get: { selectedLayer?.id }, set: { selectedLayerId = $0 })
    }

    private func layerCard(_ l: Layer) -> some View {
        SettingsCard(trailing: AnyView(cardHeader(l))) {
            VStack(alignment: .leading, spacing: 10) {
                field("zIndex") {
                    GlassStepper(value: Binding(get: { l.zIndex }, set: { l.zIndex = $0
                        l.updatedAt = Date()
                    }), range: 0...999)
                }
                ColorHexField(title: "图例色", hex: Binding(get: { l.colorHex ?? "" }, set: { l.colorHex = $0.isEmpty ? nil : ColorHexField.normalize($0)
                    l.updatedAt = Date()
                }))
                field("SF 图标") {
                    TextField("如 building.2", text: Binding(get: { l.iconSF ?? "" }, set: { l.iconSF = $0.isEmpty ? nil : $0
                        l.updatedAt = Date()
                    })).glassField()
                }
                HStack(spacing: 16) {
                    Toggle("启用", isOn: Binding(get: { l.enabled }, set: { l.enabled = $0
                        l.updatedAt = Date()
                    })).font(Studio.sans(13)).tint(Studio.cool).fixedSize()
                    Text("类型 \(l.entityType)").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on3)
                    Spacer()
                }
                HStack(spacing: 10) {
                    zoomField("minZoom", get: { l.minZoom }, set: { l.minZoom = $0
                        l.updatedAt = Date()
                    })
                    zoomField("maxZoom", get: { l.maxZoom }, set: { l.maxZoom = $0
                        l.updatedAt = Date()
                    })
                }
            }
            .padding(.horizontal, 13).padding(.bottom, 12)
        }
    }

    private func cardHeader(_ l: Layer) -> some View {
        HStack(spacing: 8) {
            TextField("名称", text: Binding(get: { l.name }, set: { l.name = $0
                l.updatedAt = Date()
            })).glassField()
            Button(role: .destructive) { deleteLayer(l)
            } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
            }.buttonStyle(.plain)
        }
    }

    private func field(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func zoomField(_ title: String, get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> some View {
        field(title) {
            TextField("—", text: Binding(get: { get().map { String(Int($0)) } ?? "" }, set: { set($0.isEmpty ? nil : Double($0)) }))
                .glassField().font(Studio.mono(13))
        }
    }

    private func addLayer() {
        let l = Layer(datasetId: datasetId, name: "新图层")
        l.zIndex = (dsLayers.map(\.zIndex).max() ?? 0) + 1
        l.sortOrder = l.zIndex
        modelContext.insert(l)
        try? modelContext.save()
    }

    private func deleteLayer(_ l: Layer) {
        l.deleted = true
        l.updatedAt = Date()
        try? modelContext.save()
    }
}
#endif
