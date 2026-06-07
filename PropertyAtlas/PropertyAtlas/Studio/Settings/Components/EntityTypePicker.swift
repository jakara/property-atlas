#if targetEnvironment(macCatalyst)
import SwiftUI

/// 过滤器实体选择器:先选实体类型,后续字段/值选项围绕该实体 scope。
struct EntityTypePicker: View {
    @Binding var entityType: String

    static let types: [(value: String, label: String)] = [
        ("compound", "小区"), ("school", "学校"), ("poi", "POI"), ("area", "区域"),
    ]

    var body: some View {
        Picker("实体", selection: $entityType) {
            Text("选实体").tag("")
            ForEach(Self.types, id: \.value) { Text($0.label).tag($0.value) }
        }
        .font(Studio.sans(13))
        .tint(Studio.cool)
    }
}
#endif
