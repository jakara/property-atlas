#if targetEnvironment(macCatalyst)
import SwiftUI

struct ColorHexField: View {
    let title: String
    @Binding var hex: String   // "" 表示无

    static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces).uppercased()
        if t.isEmpty { return "" }
        if !t.hasPrefix("#") { t = "#" + t }
        return t
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title).frame(width: 84, alignment: .leading).font(.system(size: 12))
            Circle().fill(Color(uiColor: HexColor.parse(hex) ?? .clear))
                .frame(width: 16, height: 16).overlay(Circle().stroke(.secondary.opacity(0.3)))
            TextField("#RRGGBB", text: $hex)
                .font(.system(size: 12).monospaced())
                .onSubmit { hex = Self.normalize(hex) }
        }
    }
}
#endif
