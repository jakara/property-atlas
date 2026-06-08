// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LeftDrawerView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LeftDrawerView: View {
    let legendSections: [LegendSection]
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var filterState: DimensionFilterState
    @Bindable var layerState: LayerState
    /// 切换图层启用(写回 active MapView.enabledLayerIds → 与视图设置联动)。
    var onToggleLayer: (UUID) -> Void = { _ in }
    /// 上层按屏高算出的上限(顶到指南针上方);内容撑不满则缩到 fit。
    var maxHeight: CGFloat = 640
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LayersView(layers: layers, currentZoom: currentZoom, layerState: layerState, onToggle: onToggleLayer)
                Rectangle().fill(Studio.glassLine).frame(height: 1)
                LegendView(sections: legendSections, filterState: filterState)
            }
            .padding(.horizontal, 10).padding(.vertical, 12)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: DrawerContentHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .scrollIndicators(.hidden)
        .frame(width: 244)
        .frame(height: min(contentHeight, maxHeight))
        .onPreferenceChange(DrawerContentHeightKey.self) { contentHeight = $0 }
        .glassSurface(Studio.glass, radius: Studio.rPanel, elevation: .float)
        .environment(\.colorScheme, .dark)
    }
}

private struct DrawerContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
#endif
