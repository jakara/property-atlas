#if targetEnvironment(macCatalyst)
import SwiftUI

/// 左下角指南针:红色指针随地图 heading 扭转始终指向真北;双击恢复正北朝上。
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
        .frame(width: 88, height: 88)
        .overlay { Circle().strokeBorder(Studio.glassEdge, lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .contentShape(Circle())
        .onTapGesture(count: 2) { onResetNorth() }
        .environment(\.colorScheme, .dark)
        .help("双击恢复正北")
    }

    /// 指针 + N 字一起按 −heading 旋转 → N 永远指真北。
    private var needle: some View {
        ZStack {
            Image(systemName: "location.north.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Studio.bad)
            Text("N")
                .font(Studio.sans(15, .bold))
                .foregroundStyle(Studio.on2)
                .offset(y: -31)
        }
        .rotationEffect(.degrees(-heading))
    }
}
#endif
