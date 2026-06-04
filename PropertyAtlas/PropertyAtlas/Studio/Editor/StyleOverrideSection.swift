// PropertyAtlas/PropertyAtlas/Studio/Editor/StyleOverrideSection.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct StyleOverrideSection: View {
    let ref: EntityRef
    @Environment(\.modelContext) private var context
    @State private var override = OverrideStyle()

    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    private var summary: String {
        (override.shape ?? "圆点") + " · " + (override.fillHex == nil ? "跟随主题" : "自定义")
    }

    private var fillBinding: Binding<String> {
        Binding(
            get: { override.fillHex ?? "" },
            set: {
                override.fillHex = $0.isEmpty ? nil : $0
                persist()
            }
        )
    }

    private var glyphBinding: Binding<String> {
        Binding(
            get: { override.glyph ?? "" },
            set: {
                override.glyph = $0.isEmpty ? nil : String($0.prefix(2))
                persist()
            }
        )
    }

    var body: some View {
        StudioDisclosure("样式覆盖", summary: summary, open: false) {
            VStack(alignment: .leading, spacing: 6) {
                Text("形状").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(shapes, id: \.self) { s in
                            StudioChip(s, isOn: override.shape == s) {
                                override.shape = (override.shape == s) ? nil : s
                                persist()
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("字符 / 图标").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                TextField("SF Symbol 或 1 字", text: glyphBinding)
                    .glassField().font(Studio.mono(13))
            }
            ColorHexField(title: "填充色", hex: fillBinding)
            Button {
                override = OverrideStyle()
                persist()
            } label: {
                Label("清空 → 跟随主题", systemImage: "eraser")
            }
            .buttonStyle(.tbtn(.dangerGhost))
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { override = OverrideStyleCodec.decode(EntityReader.overrideStyleJSON(ref, in: context)) }
    }

    private func persist() {
        EntityWriter.setOverrideStyleJSON(ref, OverrideStyleCodec.encode(override), in: context)
    }
}
#endif
