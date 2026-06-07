#if targetEnvironment(macCatalyst)
import SwiftUI

/// 左下角指南针:N/S 双极指针随地图 heading 扭转,红极指真北;双击恢复正北朝上。
struct CompassView: View {
    let heading: Double // 地图 heading(度,顺时针)
    let onResetNorth: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .fill(Studio.glass)
                .background(.ultraThinMaterial, in: Circle())
            Circle().strokeBorder(Studio.glassLine, lineWidth: 1)
            needle
        }
        .frame(width: 44, height: 44)
        .overlay { Circle().strokeBorder(Studio.glassEdge, lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .contentShape(Circle())
        .onTapGesture(count: 2) { onResetNorth() }
        .environment(\.colorScheme, .dark)
        .help("双击恢复正北")
    }

    /// N/S 双极菱形指针 + N/S 字,整体按 −heading 旋转 → 红极永远指真北。
    private var needle: some View {
        ZStack {
            NeedleHalf().fill(Studio.bad).frame(width: 9, height: 13).offset(y: -6.5)
            NeedleHalf().fill(Studio.on3).rotationEffect(.degrees(180)).frame(width: 9, height: 13).offset(y: 6.5)
            Text("N").font(Studio.sans(7, .bold)).foregroundStyle(Studio.bad).offset(y: -16)
            Text("S").font(Studio.sans(7, .bold)).foregroundStyle(Studio.on2).offset(y: 16)
        }
        .rotationEffect(.degrees(-heading))
    }
}

/// 单极三角(尖朝上),两个拼成菱形指针。
private struct NeedleHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
#endif
