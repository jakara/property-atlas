#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct PaletteSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var palettes: [Palette]

    private var live: [Palette] { palettes.filter { !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("调色板").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addPalette() } label: { Label("新建", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(live, id: \.id) { pal in paletteCard(pal) }
        }
    }

    private func paletteCard(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { p.name }, set: { p.name = $0; p.updatedAt = Date() })).font(.system(size: 12, weight: .semibold))
                if p.builtIn { Text("内置").font(.system(size: 9)).foregroundStyle(.secondary) }
                Spacer()
                if !p.builtIn {
                    Button(role: .destructive) { p.deleted = true; p.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
                }
            }
            ForEach(p.colorsHex.indices, id: \.self) { i in
                HStack {
                    Circle().fill(Color(uiColor: HexColor.parse(p.colorsHex[i]) ?? .gray)).frame(width: 16, height: 16)
                    TextField("#RRGGBB", text: Binding(
                        get: { p.colorsHex[i] },
                        set: { var c = p.colorsHex; c[i] = ColorHexField.normalize($0); p.colorsHex = c; p.updatedAt = Date() }
                    )).font(.system(size: 12).monospaced())
                    Button(role: .destructive) { var c = p.colorsHex; c.remove(at: i); p.colorsHex = c; p.updatedAt = Date() } label: { Image(systemName: "minus.circle").font(.system(size: 11)) }.buttonStyle(.plain)
                }
            }
            Button { var c = p.colorsHex; c.append("#888888"); p.colorsHex = c; p.updatedAt = Date() } label: { Label("加颜色", systemImage: "plus") }.font(.system(size: 11))
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func addPalette() {
        let p = Palette(name: "新调色板", colorsHex: ["#E41A1C", "#377EB8", "#4DAF4A"], builtIn: false)
        p.sortOrder = (live.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(p)
    }
}
#endif
