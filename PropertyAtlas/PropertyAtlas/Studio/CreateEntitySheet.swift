#if targetEnvironment(macCatalyst)
import SwiftUI

/// 长按地图 / 外部搜索新建实体:名称 + 选类型(图层归属由 entityType + 过滤器派生,无需指派)。
struct CreateEntitySheet: View {
    var prefillName: String?
    var defaultKind: EntityKind = .compound
    let onCreate: (EntityKind, String) -> Void
    let onCancel: () -> Void

    @State private var kind: EntityKind = .compound
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
                options: [(.compound, "小区"), (.school, "学校"), (.poi, "POI"), (.area, "区域")],
                selection: $kind
            )

            HStack(spacing: 10) {
                Spacer()
                Button("取消") { onCancel() }.buttonStyle(.tbtn(.ghost))
                Button("建立") {
                    onCreate(kind, name)
                }.buttonStyle(.tbtn(.primary))
            }
        }
    }
}
#endif
