#if targetEnvironment(macCatalyst)
import SwiftUI

/// 视图 tab 底部「样式」区:实体子tab(小区/学校/POI/区域),
/// 选中实体下并列「默认样式」+「条件样式」。
/// 两子组件仅在 onAppear 取数,故内容按 view×entity 加 .id 重挂以刷新。
struct ViewStyleSection: View {
    let mv: MapView
    @State private var styleEntity: String = "compound"

    private let entities: [(value: String, label: String)] = [
        (value: "compound", label: "小区"),
        (value: "school", label: "学校"),
        (value: "poi", label: "POI"),
        (value: "area", label: "区域"),
    ]

    var body: some View {
        SettingsCard("样式") {
            VStack(alignment: .leading, spacing: 12) {
                GlassSegmented(options: entities, selection: $styleEntity)
                styleBody
                    .id("\(mv.id.uuidString)#\(styleEntity)")
            }
            .padding(.horizontal, 13).padding(.bottom, 12)
        }
    }

    private var label: String {
        entities.first { $0.value == styleEntity }?.label ?? ""
    }

    private var styleBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "默认样式")
                EntityDefaultStyleEditor(
                    datasetId: mv.datasetId, viewId: mv.id,
                    entityType: styleEntity, title: label
                )
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "条件样式")
                ViewStyleRulesSection(
                    datasetId: mv.datasetId, viewId: mv.id, entityType: styleEntity
                )
            }
        }
    }
}
#endif
