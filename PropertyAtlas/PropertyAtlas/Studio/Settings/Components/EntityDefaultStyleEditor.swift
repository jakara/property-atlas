#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 单实体类型的视图默认样式编辑(ViewEntityStyle 一行)。空行 = builtin。
struct EntityDefaultStyleEditor: View {
    let datasetId: UUID
    let viewId: UUID
    let entityType: String
    let title: String
    @Environment(\.modelContext) private var context
    @State private var row: ViewEntityStyle?

    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    var body: some View {
        StudioDisclosure(title, summary: row?.fillHex ?? "默认", open: false) {
            let bound = ensureRow()
            if entityType != "area" {
                VStack(alignment: .leading, spacing: 6) {
                    Text("形状").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(shapes, id: \.self) { shape in
                                StudioChip(shape, isOn: bound.shape == shape) {
                                    bound.shape = (bound.shape == shape) ? nil : shape
                                    bound.updatedAt = Date()
                                }
                            }
                        }
                    }
                }
            }
            ColorHexField(title: "填充色", hex: hexBinding(bound, \.fillHex))
            ColorHexField(title: "描边色", hex: hexBinding(bound, \.strokeHex))
            Toggle("显示标签", isOn: Binding(
                get: { bound.labelVisible ?? false },
                set: { bound.labelVisible = $0
                    bound.updatedAt = Date()
                }
            ))
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { row = fetchRow() }
    }

    private func hexBinding(
        _ styleRow: ViewEntityStyle,
        _ keyPath: ReferenceWritableKeyPath<ViewEntityStyle, String?>
    ) -> Binding<String> {
        Binding(
            get: { styleRow[keyPath: keyPath] ?? "" },
            set: { styleRow[keyPath: keyPath] = $0.isEmpty ? nil : $0
                styleRow.updatedAt = Date()
            }
        )
    }

    private func fetchRow() -> ViewEntityStyle? {
        let targetView = viewId
        let targetType = entityType
        return (try? context.fetch(FetchDescriptor<ViewEntityStyle>(
            predicate: #Predicate { $0.viewId == targetView && $0.entityType == targetType && !$0.deleted }
        )))?.first
    }

    private func ensureRow() -> ViewEntityStyle {
        if let existing = row { return existing }
        let created = ViewEntityStyle(datasetId: datasetId, viewId: viewId, entityType: entityType)
        context.insert(created)
        row = created
        return created
    }
}

/// 视图分组染色色板编辑(MapView.paletteHex 字符串数组)。
struct PaletteHexEditor: View {
    @Bindable var view: MapView

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(view.paletteHex.enumerated()), id: \.offset) { index, _ in
                HStack {
                    ColorHexField(title: "颜色 \(index + 1)", hex: Binding(
                        get: { view.paletteHex[index] },
                        set: { view.paletteHex[index] = $0
                            view.updatedAt = Date()
                        }
                    ))
                    Button(role: .destructive) {
                        view.paletteHex.remove(at: index)
                        view.updatedAt = Date()
                    } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.plain)
                }
            }
            Button {
                view.paletteHex.append("#888888")
                view.updatedAt = Date()
            } label: { Label("加颜色", systemImage: "plus") }
                .buttonStyle(.tbtn(.ghost))
        }
    }
}
#endif
