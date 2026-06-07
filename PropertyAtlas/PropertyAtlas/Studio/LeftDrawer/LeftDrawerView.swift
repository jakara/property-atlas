// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LeftDrawerView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LeftDrawerView: View {
    let legendSections: [LegendSection]
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var filterState: DimensionFilterState
    @Bindable var layerState: LayerState
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LayersView(layers: layers, currentZoom: currentZoom, layerState: layerState)
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
        .frame(height: min(contentHeight, 640))
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
