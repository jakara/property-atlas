#if targetEnvironment(macCatalyst)
import MapKit
import SwiftUI

struct StudioToolbar: View {
    @Bindable var viewContext: MapViewContext
    @Binding var aspect: CanvasAspect
    let onSnapshot: () -> Void
    var showSettings: Binding<Bool>
    @Binding var exportMode: Bool
    @Binding var showSafeFrame: Bool
    @Binding var showSearch: Bool
    @Binding var mapStyle: StudioMapStyle
    @Binding var poiEnabled: Bool
    @Binding var poiCategories: Set<StudioPOIOption>

    var body: some View {
        HStack(spacing: 4) {
            // view switch
            Menu {
                ForEach(viewContext.allMapViews, id: \.id) { mv in
                    Button(mv.name) { viewContext.switchView(to: mv) }
                }
            } label: {
                DockLabel(icon: "map", text: viewContext.activeMapView?.name ?? "无视图", caret: true)
            }
            .menuStyle(.borderlessButton).fixedSize()

            // aspect ratio
            Menu {
                Toggle("显示出图框", isOn: $showSafeFrame)
                Divider()
                Picker("画幅", selection: $aspect) {
                    ForEach(CanvasAspect.allCases) { a in Text(a.rawValue).tag(a) }
                }
            } label: {
                DockLabel(icon: "crop", text: aspect.rawValue, caret: true)
            }
            .menuStyle(.borderlessButton).fixedSize()

            // map style — 扁平按钮(同视图切换),点一下直接选,当前项打勾
            Menu {
                ForEach(StudioMapStyle.allCases) { style in
                    Button {
                        mapStyle = style
                    } label: {
                        Label(style.label, systemImage: style == mapStyle ? "checkmark" : style.icon)
                    }
                }
            } label: {
                DockLabel(icon: mapStyle.icon, text: mapStyle.label, caret: true)
            }
            .menuStyle(.borderlessButton).fixedSize()

            // Apple 地点 — 独立下拉(同视图/底图):总开关 + 类别多选
            Menu {
                Toggle("显示 Apple 地点", isOn: $poiEnabled)
                if poiEnabled {
                    Divider()
                    ForEach(StudioPOIOption.allCases) { opt in
                        Toggle(opt.label, isOn: categoryBinding(opt))
                    }
                }
            } label: {
                DockLabel(icon: "mappin.and.ellipse", text: "地点", caret: true)
            }
            .menuStyle(.borderlessButton).fixedSize()

            // search
            Button { showSearch.toggle() } label: {
                DockLabel(icon: "magnifyingglass", iconOnly: true)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)

            // settings
            Button { showSettings.wrappedValue = true } label: {
                DockLabel(icon: "gearshape", iconOnly: true)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)

            sep

            // 出图模式 toggle
            Button { exportMode.toggle() } label: {
                HStack(spacing: 6) {
                    Circle().fill(exportMode ? Studio.cool : Studio.on3)
                        .frame(width: 7, height: 7)
                        .shadow(color: exportMode ? Studio.cool : .clear, radius: 4)
                    Text("出图模式").font(Studio.sans(13, .medium))
                }
                .foregroundStyle(exportMode ? Studio.cool : Studio.on2)
                .padding(.horizontal, 12).frame(height: 38)
                .background(
                    exportMode ? Studio.coolSoft : Studio.glassHover,
                    in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                )
                .overlay {
                    if exportMode {
                        RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                            .strokeBorder(Studio.coolLine, lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)

            // capture (primary)
            Button(action: onSnapshot) {
                HStack(spacing: 7) {
                    Image(systemName: "camera.fill").font(.system(size: 13, weight: .semibold))
                    Text("截屏").font(Studio.sans(14, .semibold))
                }
                .foregroundStyle(Studio.onAmber)
                .padding(.horizontal, 14).frame(height: 38)
                .background(Studio.amber, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("e", modifiers: .command)
        }
        .padding(6)
        .glassSurface(Studio.glass, radius: Studio.rPanel, elevation: .float)
        .environment(\.colorScheme, .dark)
    }

    private func categoryBinding(_ opt: StudioPOIOption) -> Binding<Bool> {
        Binding(
            get: { poiCategories.contains(opt) },
            set: { on in if on { poiCategories.insert(opt) } else { poiCategories.remove(opt) } }
        )
    }

    private var sep: some View {
        Rectangle().fill(Studio.glassLine).frame(width: 1, height: 24).padding(.horizontal, 3)
    }
}

/// A dock pill label — icon (+ text) (+ caret).
private struct DockLabel: View {
    let icon: String
    var text: String = ""
    var caret: Bool = false
    var iconOnly: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 15, weight: .regular))
            if !iconOnly {
                Text(text).font(Studio.sans(14, .medium)).lineLimit(1)
                if caret {
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Studio.on2)
                }
            }
        }
        .foregroundStyle(Studio.on)
        .padding(.horizontal, iconOnly ? 0 : 12)
        .frame(width: iconOnly ? 38 : nil, height: 38)
    }
}
#endif
