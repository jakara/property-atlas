#if targetEnvironment(macCatalyst)
import MapKit
import SwiftUI

/// 手动打点绘制区域:点击地图放顶点,实时预览多边形。屏幕↔地理用 visibleRegion 线性映射
/// (城市尺度足够),pan/zoom 后顶点随 region 重投影保持对齐。完成 → 生成 Area 多边形。
/// 绘制几何类型:多边形(闭合 + 填充)或折线(开口 + 仅描边)。
enum AreaDrawKind {
    case polygon, line
    var minPoints: Int {
        self == .polygon ? 3 : 2
    }

    var title: String {
        self == .polygon ? "绘制区域" : "绘制折线"
    }
}

struct AreaDrawLayer: View {
    @Binding var points: [CLLocationCoordinate2D]
    let region: MKCoordinateRegion?
    var closed: Bool = true

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard let region else { return }
                let screen = points.map { Self.project($0, region, size) }
                if screen.count > 1 {
                    var line = Path()
                    line.addLines(screen)
                    if closed, screen.count > 2 { line.addLine(to: screen[0]) }
                    if closed, screen.count > 2 {
                        var fill = Path()
                        fill.addLines(screen)
                        fill.closeSubpath()
                        ctx.fill(fill, with: .color(.orange.opacity(0.14)))
                    }
                    ctx.stroke(
                        line,
                        with: .color(.orange),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [7, 4])
                    )
                }
                for (i, p) in screen.enumerated() {
                    let r: CGFloat = i == 0 ? 6 : 4.5
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                        with: .color(i == 0 ? .red : .orange)
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { loc in
                guard let region else { return }
                points.append(Self.unproject(loc, region, geo.size))
            }
        }
    }

    static func project(_ c: CLLocationCoordinate2D, _ r: MKCoordinateRegion, _ size: CGSize) -> CGPoint {
        let west = r.center.longitude - r.span.longitudeDelta / 2
        let north = r.center.latitude + r.span.latitudeDelta / 2
        let x = (c.longitude - west) / r.span.longitudeDelta * size.width
        let y = (north - c.latitude) / r.span.latitudeDelta * size.height
        return CGPoint(x: x, y: y)
    }

    static func unproject(_ p: CGPoint, _ r: MKCoordinateRegion, _ size: CGSize) -> CLLocationCoordinate2D {
        let west = r.center.longitude - r.span.longitudeDelta / 2
        let north = r.center.latitude + r.span.latitudeDelta / 2
        let lon = west + Double(p.x / max(size.width, 1)) * r.span.longitudeDelta
        let lat = north - Double(p.y / max(size.height, 1)) * r.span.latitudeDelta
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// 绘制控制面板(顶部居中):点数 + 撤销/完成/取消。多边形/折线共用。
struct AreaDrawPanel: View {
    let count: Int
    var kind: AreaDrawKind = .polygon
    let onUndo: () -> Void
    let onFinish: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(kind.title) · \(count) 点").font(Studio.sans(13, .semibold)).foregroundStyle(Studio.on)
            Button("撤销") { onUndo() }.buttonStyle(.tbtn(.ghost)).disabled(count == 0)
            Button("取消") { onCancel() }.buttonStyle(.tbtn(.ghost))
            Button("完成") { onFinish() }.buttonStyle(.tbtn(.primary)).disabled(count < kind.minPoints)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .glassSurface(Studio.glass, radius: Studio.rPanel, elevation: .float)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }
}
#endif
