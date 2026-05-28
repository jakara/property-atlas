#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

/// 自绘 pin: 学片色形状 + glyph + (可选)校名 label.
/// 形状: 小学=圆, 初中=圆角方, 九年一贯=六边形.
/// Pin 和 nameplate 同色, 通过 zone 分组.
final class SchoolPinView: MKAnnotationView {
    static let reuseIdentifier = "schoolPin"
    private static let dotSize: CGFloat = 22
    private static let gap: CGFloat = 4

    enum Shape { case circle, square, hexagon }

    private let dot = UIView()
    private let shapeLayer = CAShapeLayer()
    private let glyphLabel = UILabel()
    private let nameLabel = UILabel()

    override var annotation: (any MKAnnotation)? {
        didSet { refresh() }
    }

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        canShowCallout = false
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 1.5
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.25
        shapeLayer.shadowRadius = 2
        shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
        dot.layer.addSublayer(shapeLayer)
        glyphLabel.textAlignment = .center
        glyphLabel.font = .systemFont(ofSize: 11, weight: .bold)
        glyphLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.layer.cornerRadius = 4
        nameLabel.layer.masksToBounds = true
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOpacity = 0.20
        nameLabel.layer.shadowRadius = 2
        nameLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        nameLabel.textAlignment = .center
        dot.addSubview(glyphLabel)
        addSubview(dot)
        addSubview(nameLabel)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func refresh() {
        guard let s = annotation as? SchoolAnnotation else { return }
        let zoneColor: UIColor = {
            if let hex = s.zoneColorHex, !hex.isEmpty {
                return ZoneColorPalette.color(fromHex: hex)
            }
            return ZoneColorPalette.color(for: s.zoneName)
        }()
        let shape: Shape = s.isJiunian ? .hexagon : Self.shape(for: s.level)
        shapeLayer.fillColor = zoneColor.cgColor
        shapeLayer.frame = CGRect(x: 0, y: 0, width: Self.dotSize, height: Self.dotSize)
        shapeLayer.path = Self.path(for: shape, in: shapeLayer.bounds).cgPath
        glyphLabel.text = Self.tierGlyph(s.tier)
        glyphLabel.frame = CGRect(x: 0, y: 0, width: Self.dotSize, height: Self.dotSize)

        if s.showName {
            nameLabel.isHidden = false
            nameLabel.text = "  \(s.name)  "
            nameLabel.backgroundColor = zoneColor.withAlphaComponent(0.92)
            let nameSize = nameLabel.intrinsicContentSize
            let h: CGFloat = max(Self.dotSize, nameSize.height + 2)
            dot.frame = CGRect(
                x: 0,
                y: (h - Self.dotSize) / 2,
                width: Self.dotSize,
                height: Self.dotSize
            )
            nameLabel.frame = CGRect(
                x: Self.dotSize + Self.gap,
                y: 0,
                width: nameSize.width,
                height: h
            )
            frame = CGRect(
                x: 0,
                y: 0,
                width: Self.dotSize + Self.gap + nameSize.width,
                height: h
            )
        } else {
            nameLabel.isHidden = true
            dot.frame = CGRect(x: 0, y: 0, width: Self.dotSize, height: Self.dotSize)
            frame = dot.frame
        }
        centerOffset = CGPoint(x: (frame.width - Self.dotSize) / 2, y: 0)
    }

    static func shape(for level: String) -> Shape {
        // level 只 小学/初中 (九年一贯 由 SchoolAnnotation.isJiunian 单独判断, 优先)
        if level.contains("小") { return .circle }
        return .square
    }

    static func path(for shape: Shape, in rect: CGRect) -> UIBezierPath {
        switch shape {
        case .circle:
            UIBezierPath(ovalIn: rect.insetBy(dx: 0.75, dy: 0.75))
        case .square:
            UIBezierPath(
                roundedRect: rect.insetBy(dx: 0.75, dy: 0.75),
                cornerRadius: 3
            )
        case .hexagon:
            hexagonPath(in: rect.insetBy(dx: 0.75, dy: 0.75))
        }
    }

    /// Pointy-top regular hexagon.
    private static func hexagonPath(in rect: CGRect) -> UIBezierPath {
        let cx = rect.midX, cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        let p = UIBezierPath()
        for i in 0..<6 {
            let angle = Double.pi / 3 * Double(i) - Double.pi / 2
            let x = cx + r * CGFloat(cos(angle))
            let y = cy + r * CGFloat(sin(angle))
            if i == 0 {
                p.move(to: CGPoint(x: x, y: y))
            } else {
                p.addLine(to: CGPoint(x: x, y: y))
            }
        }
        p.close()
        return p
    }

    static func tierGlyph(_ tier: String) -> String {
        switch tier {
        case "重点": "重"
        case "区重点": "区"
        default: "普"
        }
    }
}
#endif
