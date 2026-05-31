// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LayersView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LayersView: View {
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var layerState: LayerState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("图层").font(.system(size: 12, weight: .bold))
            ForEach(layers, id: \.id) { layer in row(layer) }
        }
    }

    private func row(_ layer: Layer) -> some View {
        let inZoom = zoomOK(layer)
        let on = layerState.isEnabled(layer.id)
        return Button { layerState.toggle(layer.id) } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundStyle(on ? Color.accentColor : .secondary)
                if let icon = layer.iconSF { Image(systemName: icon).font(.system(size: 10)) }
                Text(layer.name).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 4)
                Text(zoomLabel(layer)).font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(inZoom ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
            }
            .opacity(inZoom ? 1 : 0.5)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func zoomOK(_ l: Layer) -> Bool {
        if let mn = l.minZoom, currentZoom < mn { return false }
        if let mx = l.maxZoom, currentZoom > mx { return false }
        return true
    }

    private func zoomLabel(_ l: Layer) -> String {
        let mn = l.minZoom.map { String(Int($0)) } ?? "0"
        let mx = l.maxZoom.map { String(Int($0)) } ?? "21"
        return "\(mn)-\(mx)"
    }
}
#endif
