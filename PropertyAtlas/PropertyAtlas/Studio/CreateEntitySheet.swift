#if targetEnvironment(macCatalyst)
import SwiftUI

/// 长按地图新建实体:选类型 + 选一个启用图层。
struct CreateEntitySheet: View {
    let enabledLayers: [(id: UUID, name: String)]
    let defaultLayerId: UUID?
    let onCreate: (EntityKind, UUID?) -> Void
    let onCancel: () -> Void

    @State private var kind: EntityKind = .compound
    @State private var layerId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建实体").font(Studio.sans(17, .bold)).foregroundStyle(Studio.on)

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
                    ForEach(enabledLayers, id: \.id) { l in
                        Button { layerId = l.id } label: {
                            HStack {
                                Text(l.name).font(Studio.sans(13)).foregroundStyle(Studio.on)
                                Spacer()
                                if (layerId ?? defaultLayerId) == l.id {
                                    Image(systemName: "checkmark").foregroundStyle(Studio.cool)
                                }
                            }
                            .padding(.horizontal, 10).frame(height: 38)
                            .background(
                                (layerId ?? defaultLayerId) == l.id ? Studio.glassHover : .clear,
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
                Button("建立") { onCreate(kind, layerId ?? defaultLayerId) }.buttonStyle(.tbtn(.primary))
            }
        }
        .padding(18)
        .frame(width: 320)
        .background(Studio.glassStrong).background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Studio.rPanel, style: .continuous))
        .environment(\.colorScheme, .dark)
        .onAppear { layerId = defaultLayerId }
    }
}
#endif
