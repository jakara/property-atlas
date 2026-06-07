#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct ViewSettingsTab: View {
    @Bindable var viewContext: MapViewContext
    @Environment(\.modelContext) private var modelContext
    @State private var subTab: String = "basic"

    private let subTabs: [(value: String, label: String)] = [
        (value: "basic", label: "基本"),
        (value: "style", label: "样式"),
        (value: "primary", label: "主过滤"),
        (value: "normal", label: "普通过滤"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            viewSwitcher
            if let mv = viewContext.activeMapView {
                GlassSegmented(options: subTabs, selection: $subTab)
                Group {
                    switch subTab {
                    case "style": ViewStyleSection(mv: mv)
                    case "primary": ViewPrimaryFilterSection(mv: mv)
                    case "normal": ViewNormalFilterSection(mv: mv)
                    default: ViewBasicSection(mv: mv)
                    }
                }
                .id("\(mv.id.uuidString)#\(subTab)")
            } else {
                Text("无视图").font(Studio.sans(13)).foregroundStyle(Studio.on2)
            }
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
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

    private var activeBinding: Binding<UUID?> {
        Binding(get: { viewContext.activeMapView?.id }, set: { id in
            if let v = viewContext.allMapViews.first(where: { $0.id == id }) { viewContext.switchView(to: v) }
        })
    }

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
#endif
