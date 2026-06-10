#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 图层「过滤(AND + groupBy)」组 —— 读写 layer.primaryFilterJSON。
struct LayerPrimaryFilterSection: View {
    @Bindable var layer: Layer
    @State private var primary = PrimaryFilter(conditions: [], groupBy: nil)

    var body: some View {
        SettingsCard("过滤 · 分组染色") {
            PrimaryFilterEditor(filter: $primary, datasetId: layer.datasetId)
                .onChange(of: primary) { _, new in
                    layer.primaryFilterJSON = ViewConfigCodec.encodePrimary(new)
                    layer.updatedAt = Date()
                }
                .padding(.horizontal, 13).padding(.bottom, 12)
        }
        .onAppear { primary = ViewConfigCodec.decodePrimary(layer.primaryFilterJSON) }
    }
}

/// 图层「普通过滤(图例 chip)」组 —— 读写 layer.normalFiltersJSON。
struct LayerNormalFilterSection: View {
    @Bindable var layer: Layer
    @State private var normals: [NormalFilter] = []

    var body: some View {
        SettingsCard("普通过滤 · 图例") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(normals.indices, id: \.self) { index in
                    row(index)
                }
                AddRow("加普通过滤") {
                    normals.append(NormalFilter(name: "新过滤", dimension: MapDimension(kind: .field)))
                    save()
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 12)
        }
        .onAppear { normals = ViewConfigCodec.decodeNormals(layer.normalFiltersJSON) }
    }

    private func row(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("名称", text: Binding(get: { normals[index].name }, set: { normals[index].name = $0
                    save()
                })).glassField()
                Button(role: .destructive) { normals.remove(at: index)
                    save()
                } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
                }.buttonStyle(.plain)
            }
            DimensionPicker(
                dimension: Binding(get: { normals[index].dimension }, set: { normals[index].dimension = $0
                    save()
                }),
                entityType: layer.entityType,
                datasetId: layer.datasetId
            )
        }
        .padding(12)
        .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
    }

    private func save() {
        layer.normalFiltersJSON = ViewConfigCodec.encodeNormals(normals)
        layer.updatedAt = Date()
    }
}

/// 图层「样式」组 —— 默认样式(本图层 entityType 1 组)+ 调色板 + 条件样式。
struct LayerStyleSection: View {
    let layer: Layer

    private var typeLabel: String {
        switch layer.entityType {
        case "school": "学校"
        case "poi": "POI"
        case "area": "区域"
        default: "楼盘"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("默认样式") {
                EntityDefaultStyleEditor(
                    datasetId: layer.datasetId, layerId: layer.id,
                    entityType: layer.entityType, title: typeLabel
                )
                .padding(.horizontal, 13).padding(.bottom, 12)
            }
            SettingsCard("分组染色调色板") {
                PaletteHexEditor(layer: layer).padding(.horizontal, 13).padding(.bottom, 12)
            }
            SettingsCard("条件样式") {
                ViewStyleRulesSection(
                    datasetId: layer.datasetId, layerId: layer.id, entityType: layer.entityType
                )
                .padding(.horizontal, 13).padding(.bottom, 12)
            }
        }
        .id(layer.id)
    }
}
#endif
