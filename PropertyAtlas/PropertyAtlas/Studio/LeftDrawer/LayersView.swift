// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LayersView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LayersView: View {
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var layerState: LayerState
    var onToggle: (UUID) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: "图层").padding(.horizontal, 8).padding(.bottom, 4)
            ForEach(layers, id: \.id) { layer in row(layer) }
        }
    }

    private func row(_ layer: Layer) -> some View {
        let inZoom = zoomOK(layer)
        let on = layerState.isEnabled(layer.id)
        let hasZoom = layer.minZoom != nil || layer.maxZoom != nil
        return HStack(spacing: 10) {
            if let icon = layer.iconSF {
                Image(systemName: icon).font(.system(size: 15))
                    .foregroundStyle(Studio.on2).frame(width: 26, height: 26)
                    .background(Studio.glassHover, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name).font(Studio.sans(13, .medium)).foregroundStyle(Studio.on).lineLimit(1)
                // 仅当图层设了 zoom 限制才显示范围(默认图层无限制 → 不显示噪声小字)
                if hasZoom {
                    Text(zoomLabel(layer)).font(Studio.mono(10))
                        .foregroundStyle(inZoom ? Studio.on3 : Studio.warn)
                }
            }
            Spacer(minLength: 4)
            if hasZoom, !inZoom { ZoomFlag("越界") }
            Toggle("", isOn: Binding(get: { on }, set: { _ in onToggle(layer.id) }))
                .labelsHidden().tint(Studio.cool).controlSize(.mini)
        }
        .opacity(on ? 1 : 0.6)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(minHeight: 40)
        .contentShape(Rectangle())
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
