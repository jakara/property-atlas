#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case view = "视图", layer = "图层", palette = "调色板", enumOption = "枚举"
    case theme = "主题", styleRule = "样式", camera = "相机", customField = "字段"
    var id: String {
        rawValue
    }
}

struct SettingsSheet: View {
    @Bindable var viewContext: MapViewContext
    let onClose: () -> Void
    @State private var tab: SettingsTab = .view

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置").font(.headline)
                Spacer()
                Button("完成", action: onClose).keyboardShortcut(.defaultAction)
            }
            .padding(12)
            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            Divider().padding(.top, 8)
            ScrollView {
                Group {
                    switch tab {
                    case .view: ViewSettingsTab(viewContext: viewContext)
                    case .layer: LayerSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .palette: PaletteSettingsTab()
                    case .enumOption: EnumOptionSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .theme: ThemeSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .styleRule: StyleRuleSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .camera: CameraSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .customField: CustomFieldSettingsTab(datasetId: viewContext.datasetIdValue)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 460, height: 820)
    }
}
#endif
