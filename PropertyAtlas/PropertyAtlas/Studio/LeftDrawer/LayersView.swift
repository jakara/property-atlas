// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LayersView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LayersView: View {
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var layerState: LayerState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: "图层").padding(.horizontal, 8).padding(.bottom, 4)
            ForEach(layers, id: \.id) { layer in row(layer) }
        }
    }

    private func row(_ layer: Layer) -> some View {
        let inZoom = zoomOK(layer)
        let on = layerState.isEnabled(layer.id)
        return Button { layerState.toggle(layer.id) } label: {
            HStack(spacing: 10) {
                checkbox(on)
                if let icon = layer.iconSF {
                    Image(systemName: icon).font(.system(size: 15))
                        .foregroundStyle(Studio.on2).frame(width: 26, height: 26)
                        .background(Studio.glassHover, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(layer.name).font(Studio.sans(13, .medium)).foregroundStyle(Studio.on).lineLimit(1)
                    Text(zoomLabel(layer)).font(Studio.mono(10))
                        .foregroundStyle(inZoom ? Studio.on3 : Studio.warn)
                }
                Spacer(minLength: 4)
                if !inZoom { ZoomFlag("越界") }
            }
            .opacity(on ? 1 : 0.55)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func checkbox(_ on: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(on ? Studio.cool : .clear)
            .frame(width: 20, height: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(on ? Studio.cool : .white.opacity(0.28), lineWidth: 1.5)
            }
            .overlay {
                if on {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Studio.onCool)
                }
            }
    }

    private func zoomOK(_ l: Layer) -> Bool {
        if let mn = l.minZoom, currentZoom < mn { return false }
        if let mx = l.maxZoom, currentZoom > mx { return false }
        return true
    }

    private func zoomLabel(_ l: Layer) -> String {
        let mn = l.minZoom.map { String(Int($0)) } ?? "0"
        let mx = l.maxZoom.map { String(Int($0)) } ?? "21"
        return "z \(mn)–\(mx)"
    }
}
#endif
