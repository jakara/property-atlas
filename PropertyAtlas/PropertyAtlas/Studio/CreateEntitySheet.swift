#if targetEnvironment(macCatalyst)
import SwiftUI

/// 长按地图 / 外部搜索新建实体:名称 + 选类型 + 选一个启用图层。
struct CreateEntitySheet: View {
    let enabledLayers: [(id: UUID, name: String)]
    let defaultLayerId: UUID?
    var prefillName: String?
    var defaultKind: EntityKind = .compound
    let onCreate: (EntityKind, UUID?, String) -> Void
    let onCancel: () -> Void

    @State private var kind: EntityKind = .compound
    @State private var layerId: UUID?
    @State private var name: String = ""

    var body: some View {
        ScrollView {
            content.padding(18)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: 560)
        .glassSurface(Studio.glassStrong, radius: Studio.rSheet, elevation: .pop)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear {
            kind = defaultKind
            name = prefillName ?? ""
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("新建实体").font(Studio.sans(17, .bold)).foregroundStyle(Studio.on)
                Spacer()
            }

            Text("名称").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            TextField("未命名", text: $name).glassField()

            Text("类型").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            GlassSegmented(
                options: [(.compound, "小区"), (.school, "学校"), (.poi, "POI"), (.area, "片区")],
                selection: $kind
            )

            Text("归属图层").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            if enabledLayers.isEmpty {
                Text("无启用图层 → 进【默认】").font(Studio.sans(12)).foregroundStyle(Studio.on3)
            } else {
                VStack(spacing: 2) {
                    ForEach(enabledLayers, id: \.id) { layer in
                        Button { layerId = layer.id } label: {
                            HStack {
                                Text(layer.name).font(Studio.sans(13)).foregroundStyle(Studio.on)
                                Spacer()
                                if (layerId ?? defaultLayerId) == layer.id {
                                    Image(systemName: "checkmark").foregroundStyle(Studio.cool)
                                }
                            }
                            .padding(.horizontal, 10).frame(height: 38)
                            .background(
                                (layerId ?? defaultLayerId) == layer.id ? Studio.glassHover : .clear,
                                in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button("取消") { onCancel() }.buttonStyle(.tbtn(.ghost))
                Button("建立") {
                    onCreate(kind, layerId ?? defaultLayerId, name)
                }.buttonStyle(.tbtn(.primary))
            }
        }
    }
}
#endif
