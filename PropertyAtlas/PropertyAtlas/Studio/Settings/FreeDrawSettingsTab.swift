#if targetEnvironment(macCatalyst)
import SwiftUI

/// 自由绘图设置:画笔粗细 / 颜色 / 效果。值经 @AppStorage 与 FreeDrawCanvas 共享。
struct FreeDrawSettingsTab: View {
    @AppStorage("freeDrawWidth") private var width: Double = 4
    @AppStorage("freeDrawColorHex") private var colorHex: String = "#FF3B30"
    @AppStorage("freeDrawEffect") private var effect: String = "solid"

    private let effects: [(value: String, label: String)] = [
        ("solid", "实线"), ("highlighter", "高亮"), ("dashed", "虚线"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("画笔") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("粗细").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                            Spacer()
                            Text("\(Int(width)) pt").font(Studio.mono(12)).foregroundStyle(Studio.on3)
                        }
                        Slider(value: $width, in: 1...24, step: 1).tint(Studio.cool)
                    }
                    ColorHexField(title: "颜色", hex: Binding(
                        get: { colorHex },
                        set: { colorHex = ColorHexField.normalize($0) }
                    ))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("效果").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                        GlassSegmented(options: effects, selection: $effect)
                    }
                }
                .padding(.horizontal, 13).padding(.bottom, 12)
            }
            Text("工具栏「绘图」进入自由绘图,拖拽作画;退出后轨迹自动清除。")
                .font(Studio.sans(12)).foregroundStyle(Studio.on3)
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }
}
#endif
