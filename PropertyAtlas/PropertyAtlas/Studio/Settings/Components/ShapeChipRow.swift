#if targetEnvironment(macCatalyst)
import SwiftUI

/// pin 形状 ↔ SF Symbol 图标映射(用于样式编辑器的形状选择 chip)。
enum PinShapeIcon {
    static let all = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    static func symbol(_ shape: String) -> String {
        switch shape {
        case "circle": "circle.fill"
        case "square": "square.fill"
        case "hexagon": "hexagon.fill"
        case "diamond": "diamond.fill"
        case "triangle": "triangle.fill"
        case "star": "star.fill"
        default: "circle.fill"
        }
    }
}

/// 形状选择 chip 行(图标,无英文)。点中=高亮,再点取消(传 nil)。
struct ShapeChipRow: View {
    let selected: String?
    let onSelect: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("形状").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            HStack(spacing: 7) {
                ForEach(PinShapeIcon.all, id: \.self) { shape in
                    Button {
                        onSelect(selected == shape ? nil : shape)
                    } label: {
                        Image(systemName: PinShapeIcon.symbol(shape))
                            .font(.system(size: 14))
                            .foregroundStyle(selected == shape ? Studio.cool : Studio.on2)
                            .frame(width: 36, height: 32)
                            .background(selected == shape ? Studio.coolSoft : .clear, in: Capsule())
                            .overlay {
                                Capsule().strokeBorder(
                                    selected == shape ? Studio.coolLine : Studio.glassLine, lineWidth: 1
                                )
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
#endif
