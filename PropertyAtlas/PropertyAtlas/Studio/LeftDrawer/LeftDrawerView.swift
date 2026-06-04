// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LeftDrawerView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LeftDrawerView: View {
    let legendSections: [LegendSection]
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var filterState: DimensionFilterState
    @Bindable var layerState: LayerState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LayersView(layers: layers, currentZoom: currentZoom, layerState: layerState)
                Rectangle().fill(Studio.glassLine).frame(height: 1)
                LegendView(sections: legendSections, filterState: filterState)
            }
            .padding(.horizontal, 10).padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .frame(width: 244)
        .frame(maxHeight: 640)
        .glassSurface(Studio.glass, radius: Studio.rPanel, elevation: .float)
        .environment(\.colorScheme, .dark)
    }
}
#endif
