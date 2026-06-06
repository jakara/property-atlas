#if targetEnvironment(macCatalyst)
import SwiftUI

struct ColorHexField: View {
    let title: String
    @Binding var hex: String // "" 表示无

    static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces).uppercased()
        if t.isEmpty { return "" }
        if !t.hasPrefix("#") { t = "#" + t }
        return t
    }

    /// 系统取色器双向绑定:hex 空/非法 → 灰;选色 → 回写规范化 hex。
    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(uiColor: HexColor.parse(hex) ?? .gray) },
            set: { hex = HexColor.hexString(from: UIColor($0)) }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: Studio.fieldW, alignment: .leading)
                .font(Studio.sans(11, .medium))
                .foregroundStyle(Studio.on2)
            // 原生 ColorPicker(色块即触发系统取色器)+ mono uppercase hex 输入,两种皆可改
            HStack(spacing: 8) {
                ColorPicker("", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 26, height: 26)
                TextField("#RRGGBB", text: $hex)
                    .textFieldStyle(.plain)
                    .font(Studio.mono(13))
                    .foregroundStyle(Studio.on)
                    .textCase(.uppercase)
                    .onSubmit { hex = Self.normalize(hex) }
            }
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .frame(height: 38)
            .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                    .strokeBorder(Studio.glassLine, lineWidth: 1)
            }
        }
    }
}
#endif
