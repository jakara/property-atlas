// PropertyAtlas/PropertyAtlas/Studio/Editor/StyleOverrideSection.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct StyleOverrideSection: View {
    let ref: EntityRef
    @Environment(\.modelContext) private var context
    @State private var override = OverrideStyle()

    private var summary: String {
        override.fillHex == nil ? "继承视图默认" : "自定义"
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
            // 区域(多边形/折线)无 pin 形状概念 → 不显示形状选择。
            if ref.kind != .area {
                ShapeChipRow(selected: override.shape) { newShape in
                    override.shape = newShape
                    persist()
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
                Label("清空 → 继承视图默认", systemImage: "eraser")
            }
            .buttonStyle(.tbtn(.dangerGhost))
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { override = EntityReader.overrideStyle(ref, in: context) }
    }

    private func persist() {
        EntityWriter.setOverrideStyle(ref, override, in: context)
    }
}
#endif
