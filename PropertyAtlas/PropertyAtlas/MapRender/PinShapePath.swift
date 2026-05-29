#if targetEnvironment(macCatalyst)
import UIKit

enum PinShapePath {
    static func path(for shape: PinShape, in rect: CGRect) -> UIBezierPath {
        let r = rect.insetBy(dx: 0.75, dy: 0.75)
        switch shape {
        case .circle:
            return UIBezierPath(ovalIn: r)
        case .square:
            return UIBezierPath(roundedRect: r, cornerRadius: 3)
        case .hexagon:
            return polygonPath(in: r, sides: 6, rotation: -.pi / 2)
        case .diamond:
            return polygonPath(in: r, sides: 4, rotation: 0)
        case .triangle:
            return polygonPath(in: r, sides: 3, rotation: -.pi / 2)
        case .star:
            return starPath(in: r, points: 5)
        }
    }

    private static func polygonPath(in rect: CGRect, sides: Int, rotation: CGFloat) -> UIBezierPath {
        let cx = rect.midX
        let cy = rect.midY
        let radius = min(rect.width, rect.height) / 2
        let path = UIBezierPath()
        for i in 0..<sides {
            let angle = rotation + CGFloat(i) * (2 * .pi) / CGFloat(sides)
            let x = cx + radius * cos(angle)
            let y = cy + radius * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.close()
        return path
    }

    private static func starPath(in rect: CGRect, points: Int) -> UIBezierPath {
        let cx = rect.midX
        let cy = rect.midY
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        let path = UIBezierPath()
        let total = points * 2
        for i in 0..<total {
            let angle = -.pi / 2 + CGFloat(i) * (.pi / CGFloat(points))
            let r = (i % 2 == 0) ? outer : inner
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.close()
        return path
    }
}
#endif
