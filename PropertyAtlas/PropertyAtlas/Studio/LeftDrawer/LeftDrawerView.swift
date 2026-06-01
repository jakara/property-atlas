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
            VStack(alignment: .leading, spacing: 16) {
                LayersView(layers: layers, currentZoom: currentZoom, layerState: layerState)
                Divider().opacity(0.5)
                LegendView(sections: legendSections, filterState: filterState)
            }
            .padding(12)
        }
        .frame(width: 220)
        .frame(maxHeight: 640)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}
#endif
