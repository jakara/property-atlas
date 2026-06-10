#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 视图设置「主过滤」组:主过滤器(分组染色)+ 调色板。
struct ViewPrimaryFilterSection: View {
    let mv: MapView
    @State private var primary = PrimaryFilter(conditions: [], groupBy: nil)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("主过滤 · 分组染色") {
                PrimaryFilterEditor(filter: $primary, datasetId: mv.datasetId)
                    .onChange(of: primary) { _, new in
                        mv.primaryFilterJSON = ViewConfigCodec.encodePrimary(new)
                        mv.updatedAt = Date()
                    }
                    .padding(.horizontal, 13).padding(.bottom, 12)
            }
            SettingsCard("分组染色调色板") {
                PaletteHexEditor(view: mv).padding(.horizontal, 13).padding(.bottom, 12)
            }
        }
        .onAppear { primary = ViewConfigCodec.decodePrimary(mv.primaryFilterJSON) }
    }
}

/// 视图设置「普通过滤」组(图例 + 计数)。
struct ViewNormalFilterSection: View {
    let mv: MapView
    @State private var normals: [NormalFilter] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "普通过滤(图例 + 计数)", trailing: "\(normals.count)")
            ForEach(normals.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("名称", text: Binding(get: { normals[index].name }, set: { normals[index].name = $0
                            saveNormals()
                        })).glassField()
                        Button(role: .destructive) { normals.remove(at: index)
                            saveNormals()
                        } label: {
                            Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
                        }.buttonStyle(.plain)
                    }
                    DimensionPicker(
                        dimension: Binding(get: { normals[index].dimension }, set: { normals[index].dimension = $0
                            saveNormals()
                        }),
                        entityType: "",
                        datasetId: mv.datasetId
                    )
                }
                .padding(12)
                .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
            }
            AddRow("加普通过滤") {
                normals.append(NormalFilter(name: "新过滤", dimension: MapDimension(kind: .field)))
                saveNormals()
            }
        }
        .onAppear { normals = ViewConfigCodec.decodeNormals(mv.normalFiltersJSON) }
    }

    private func saveNormals() {
        mv.normalFiltersJSON = ViewConfigCodec.encodeNormals(normals)
        mv.updatedAt = Date()
    }
}
#endif
