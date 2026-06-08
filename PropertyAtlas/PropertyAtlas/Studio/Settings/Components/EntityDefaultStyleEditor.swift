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

    var body: some View {
        StudioDisclosure(title, summary: row?.fillHex ?? "默认", open: false) {
            if entityType == "area" {
                ColorHexField(title: "填充色", hex: lazyHexBinding(\.fillHex))
                opacityStepper
                ColorHexField(title: "描边色", hex: lazyHexBinding(\.strokeHex))
                widthStepper
            } else {
                shapePicker
                ColorHexField(title: "填充色", hex: lazyHexBinding(\.fillHex))
                ColorHexField(title: "描边色", hex: lazyHexBinding(\.strokeHex))
                glyphField
                ColorHexField(title: "字符色", hex: lazyHexBinding(\.glyphHex))
                sizeStepper
            }
            labelToggle
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { row = fetchRow() }
    }

    // MARK: - Subviews

    private var shapePicker: some View {
        ShapeChipRow(selected: row?.shape) { newShape in
            let bound = getOrCreateRow()
            bound.shape = newShape
            bound.updatedAt = Date()
        }
    }

    private var glyphField: some View {
        TextField("字符 / 图标", text: Binding(
            get: { row?.glyph ?? "" },
            set: { newValue in
                let bound = getOrCreateRow()
                bound.glyph = newValue.isEmpty ? nil : String(newValue.prefix(2))
                bound.updatedAt = Date()
            }
        )).glassField().font(Studio.sans(13))
    }

    private var sizeStepper: some View {
        Stepper("大小 \(row?.size ?? 22)", value: Binding(
            get: { row?.size ?? 22 },
            set: { newValue in
                let bound = getOrCreateRow()
                bound.size = newValue
                bound.updatedAt = Date()
            }
        ), in: 8...60)
    }

    private var opacityStepper: some View {
        Stepper(
            "不透明度 \(String(format: "%.2f", row?.fillOpacity ?? 0.2))",
            value: Binding(
                get: { row?.fillOpacity ?? 0.2 },
                set: { newValue in
                    let bound = getOrCreateRow()
                    bound.fillOpacity = newValue
                    bound.updatedAt = Date()
                }
            ),
            in: 0...1,
            step: 0.05
        )
    }

    private var widthStepper: some View {
        Stepper(
            "描边宽 \(String(format: "%.1f", row?.strokeWidth ?? 1.0))",
            value: Binding(
                get: { row?.strokeWidth ?? 1.0 },
                set: { newValue in
                    let bound = getOrCreateRow()
                    bound.strokeWidth = newValue
                    bound.updatedAt = Date()
                }
            ),
            in: 0...10,
            step: 0.5
        )
    }

    private var labelToggle: some View {
        Toggle("显示标签", isOn: Binding(
            get: { row?.labelVisible ?? false },
            set: { newValue in
                let bound = getOrCreateRow()
                bound.labelVisible = newValue
                bound.updatedAt = Date()
            }
        ))
    }

    // MARK: - Helpers

    private func lazyHexBinding(
        _ keyPath: ReferenceWritableKeyPath<ViewEntityStyle, String?>
    ) -> Binding<String> {
        Binding(
            get: { row?[keyPath: keyPath] ?? "" },
            set: { newValue in
                let bound = getOrCreateRow()
                bound[keyPath: keyPath] = newValue.isEmpty ? nil : newValue
                bound.updatedAt = Date()
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

    private func getOrCreateRow() -> ViewEntityStyle {
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
