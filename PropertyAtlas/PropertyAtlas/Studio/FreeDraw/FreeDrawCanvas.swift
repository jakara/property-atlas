#if targetEnvironment(macCatalyst)
import SwiftUI

/// 临时自由绘图层:激活时盖在地图上,拖拽即画;退出(active=false)清空轨迹。
/// 屏幕坐标涂鸦,不持久、不锚定地理。画笔粗细/颜色/效果由设置页(@AppStorage)控制。
struct FreeDrawCanvas: View {
    @Binding var active: Bool
    @AppStorage("freeDrawWidth") private var width: Double = 4
    @AppStorage("freeDrawColorHex") private var colorHex: String = "#FF3B30"
    @AppStorage("freeDrawEffect") private var effect: String = "solid"

    @State private var strokes: [[CGPoint]] = []
    @State private var current: [CGPoint] = []

    private var color: Color {
        Color(uiColor: HexColor.parse(colorHex) ?? .systemRed)
    }

    var body: some View {
        Canvas { ctx, _ in
            for stroke in strokes where stroke.count > 1 {
                paint(&ctx, stroke)
            }
            if current.count > 1 { paint(&ctx, current) }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { current.append($0.location) }
                .onEnded { _ in
                    if current.count > 1 { strokes.append(current) }
                    current = []
                }
        )
        .onChange(of: active) { _, on in
            if !on { strokes = []
                current = []
            }
        }
        .onDisappear { strokes = []
            current = []
        }
    }

    private func paint(_ ctx: inout GraphicsContext, _ pts: [CGPoint]) {
        var path = Path()
        path.addLines(pts)
        switch effect {
        case "highlighter":
            ctx.stroke(
                path,
                with: .color(color.opacity(0.35)),
                style: StrokeStyle(lineWidth: width * 3, lineCap: .round, lineJoin: .round)
            )
        case "dashed":
            ctx.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: width,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [width * 2, width * 1.6]
                )
            )
        default: // solid
            ctx.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
#endif
