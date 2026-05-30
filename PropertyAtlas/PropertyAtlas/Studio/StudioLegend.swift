#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioLegend: View {
    @Binding var filter: PinFilter
    let visibleZones: [VisibleZone]

    struct VisibleZone: Hashable {
        let name: String
        let colorHex: String
        let count: Int // 学校数 (全 zone, 过滤后)
        var color: Color {
            Color(uiColor: HexColor.parse(colorHex) ?? .gray)
        }
    }

    private let tiers: [(name: String, glyph: String)] = [
        ("重点", "重"),
        ("区重点", "区"),
        ("普通", "普"),
    ]
    private let levels: [(name: String, shape: LegendShape)] = [
        ("小学", .circle),
        ("初中", .square),
    ]

    enum LegendShape { case circle, square, hexagon }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            section(title: "学片 (视图内)") {
                if visibleZones.isEmpty {
                    Text("拖动地图后显示").font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    ForEach(visibleZones, id: \.self) { z in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(z.color.opacity(0.7))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(z.color, lineWidth: 1.2)
                                )
                                .frame(width: 14, height: 10)
                            Text(z.name).font(.system(size: 11)).lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(z.count)")
                                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Divider().opacity(0.5)
            section(title: "类型 (点击过滤)") {
                ForEach(levels, id: \.name) { l in
                    filterRow(
                        active: filter.levels.contains(l.name),
                        label: l.name
                    ) { filter.toggle(level: l.name) } leading: {
                        legendShape(l.shape).frame(width: 12, height: 12)
                    }
                }
                filterRow(
                    active: filter.jiunianVisible,
                    label: "九年一贯"
                ) { filter.jiunianVisible.toggle() } leading: {
                    legendShape(.hexagon).frame(width: 12, height: 12)
                }
            }
            Divider().opacity(0.5)
            section(title: "梯队 (点击过滤)") {
                ForEach(tiers, id: \.name) { t in
                    filterRow(
                        active: filter.tiers.contains(t.name),
                        label: t.name
                    ) { filter.toggle(tier: t.name) } leading: {
                        Circle().fill(.gray.opacity(0.7)).frame(width: 14, height: 14)
                            .overlay(
                                Text(t.glyph)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    }
                }
            }
        }
        .padding(10)
        .frame(width: 200, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func filterRow(
        active: Bool,
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder leading: () -> some View
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                leading()
                Text(label).font(.system(size: 11))
                if !active {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(active ? 1.0 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func legendShape(_ shape: LegendShape) -> some View {
        switch shape {
        case .circle:
            Circle().fill(.gray.opacity(0.7))
        case .square:
            RoundedRectangle(cornerRadius: 3).fill(.gray.opacity(0.7))
        case .hexagon:
            HexagonShape().fill(.gray.opacity(0.7))
        }
    }
}

private struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<6 {
            let angle = Double.pi / 3 * Double(i) - Double.pi / 2
            let x = cx + r * CGFloat(cos(angle))
            let y = cy + r * CGFloat(sin(angle))
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }
}
#endif
