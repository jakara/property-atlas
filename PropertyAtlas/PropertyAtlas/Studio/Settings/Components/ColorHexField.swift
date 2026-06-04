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

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .frame(width: Studio.fieldW, alignment: .leading)
                .font(Studio.sans(11, .medium))
                .foregroundStyle(Studio.on2)
            // `.hex` well: 26pt rounded color dot (radius 7) + mono uppercase hex field
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(uiColor: HexColor.parse(hex) ?? .clear))
                    .frame(width: 26, height: 26)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Studio.glassRim, lineWidth: 1)
                    }
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
