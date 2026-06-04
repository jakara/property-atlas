#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct PaletteSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var palettes: [Palette]

    private var live: [Palette] {
        palettes.filter { !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(live, id: \.id) { pal in paletteCard(pal) }
            AddRow("新建调色板") { addPalette() }
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }

    private func paletteCard(_ p: Palette) -> some View {
        SettingsCard(trailing: AnyView(headerTrailing(p))) {
            HStack(spacing: 8) {
                TextField("名称", text: Binding(get: { p.name }, set: { p.name = $0
                    p.updatedAt = Date()
                }))
                .glassField()
            }
            .padding(.horizontal, 13).padding(.bottom, 4)
            swatchGrid(p)
        }
    }

    private func headerTrailing(_ p: Palette) -> some View {
        HStack(spacing: 8) {
            if p.builtIn { Text("内置").font(Studio.sans(10, .medium)).foregroundStyle(Studio.on3) }
            if !p.builtIn {
                Button(role: .destructive) { p.deleted = true
                    p.updatedAt = Date()
                } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
                }.buttonStyle(.plain)
            }
        }
    }

    private func swatchGrid(_ p: Palette) -> some View {
        LazyVGrid(columns: cols, spacing: 8) {
            ForEach(p.colorsHex.indices, id: \.self) { i in
                swatchCell(p, i)
            }
            addCell(p)
        }
        .padding(.horizontal, 13).padding(.bottom, 12)
    }

    private func swatchCell(_ p: Palette, _ i: Int) -> some View {
        let fill = Color(uiColor: HexColor.parse(p.colorsHex[i]) ?? .gray)
        return RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(fill)
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                Text(p.colorsHex[i].replacingOccurrences(of: "#", with: ""))
                    .font(Studio.mono(8.5))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                    .padding(5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                Button(role: .destructive) {
                    var c = p.colorsHex
                    c.remove(at: i)
                    p.colorsHex = c
                    p.updatedAt = Date()
                } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 13))
                        .foregroundStyle(.white, .black.opacity(0.45))
                }.buttonStyle(.plain).padding(3)
            }
    }

    private func addCell(_ p: Palette) -> some View {
        Button {
            var c = p.colorsHex
            c.append("#888888")
            p.colorsHex = c
            p.updatedAt = Date()
        } label: {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Studio.glassHover)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Studio.glassLine, lineWidth: 1)
                }
                .overlay { Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(Studio.cool) }
        }.buttonStyle(.plain)
    }

    private func addPalette() {
        let p = Palette(name: "新调色板", colorsHex: ["#E41A1C", "#377EB8", "#4DAF4A"], builtIn: false)
        p.sortOrder = (live.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(p)
    }
}
#endif
