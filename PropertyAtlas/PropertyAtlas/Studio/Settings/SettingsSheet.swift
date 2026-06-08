#if targetEnvironment(macCatalyst)
import CoreLocation
import SwiftData
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case view = "视图", layer = "图层", enumOption = "枚举"
    case camera = "相机", customField = "字段", freeDraw = "绘图"
    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .view: "rectangle.on.rectangle"
        case .layer: "square.3.layers.3d"
        case .enumOption: "list.bullet"
        case .camera: "camera"
        case .customField: "character.textbox"
        case .freeDraw: "scribble.variable"
        }
    }
}

struct SettingsSheet: View {
    @Bindable var viewContext: MapViewContext
    let onClose: () -> Void
    let onEntitySelect: (EntityRef, CLLocationCoordinate2D?, Bool) -> Void
    let onEntityEdit: (EntityRef, CLLocationCoordinate2D?, Bool) -> Void
    /// 记录上次活动 tab,关闭后下次打开还原。
    @AppStorage("studioSettingsTab") private var storedTab: String = SettingsTab.view.rawValue

    private var tab: SettingsTab {
        SettingsTab(rawValue: storedTab) ?? .view
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            segTabs
            ScrollView {
                Group {
                    switch tab {
                    case .view: ViewSettingsTab(viewContext: viewContext)
                    case .layer: LayerSettingsTab(
                            datasetId: viewContext.datasetIdValue,
                            onSelect: onEntitySelect, onEdit: onEntityEdit
                        )
                    case .enumOption: EnumOptionSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .camera: CameraSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .customField: CustomFieldSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .freeDraw: FreeDrawSettingsTab()
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 22)
            }
        }
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassSurface(Studio.glassStrong, radius: Studio.rSheet, elevation: .pop)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }

    private var header: some View {
        HStack {
            Text("设置").font(Studio.sans(19, .bold)).foregroundStyle(Studio.on)
            Spacer()
            // 防取色器浮窗卡住:手动关闭。
            Button { MacColorPanel.close() } label: {
                Image(systemName: "eyedropper").font(.system(size: 14, weight: .medium)).foregroundStyle(Studio.on2)
            }
            .buttonStyle(.plain)
            .help("关闭取色器")
            Button(action: onClose) {
                Text("完成").font(Studio.sans(14, .semibold)).foregroundStyle(Studio.cool)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
    }

    /// THE 5-SEGMENT CONTROL — icon over 2-char label, equal widths.
    private var segTabs: some View {
        HStack(spacing: 3) {
            ForEach(SettingsTab.allCases) { t in
                let on = tab == t
                Button { storedTab = t.rawValue } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon).font(.system(size: 17, weight: .regular))
                            .foregroundStyle(on ? Studio.cool : (on ? Studio.on : Studio.on3))
                        Text(t.rawValue).font(Studio.sans(11, .semibold))
                            .foregroundStyle(on ? Studio.on : Studio.on3)
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(
                        on ? Studio.glassRaised : .clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                    .shadow(color: .black.opacity(on ? 0.3 : 0), radius: 1.5, y: 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 14)
    }
}
#endif
