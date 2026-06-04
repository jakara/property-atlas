#if targetEnvironment(macCatalyst)
import SwiftUI

/// AnyJSON 标量编辑为字符串。inOp 多值由调用方用逗号分隔串处理。
struct AnyJSONValueField: View {
    @Binding var value: AnyJSON
    private var text: Binding<String> {
        Binding(get: { ValueFormat.display(value) }, set: { value = .string($0) })
    }

    var body: some View {
        TextField("值", text: text).glassField()
    }
}
#endif
