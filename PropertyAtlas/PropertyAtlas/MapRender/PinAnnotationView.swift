#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

final class PinAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "pinAnnotation"
    private static let gap: CGFloat = 4
    /// 由地图缩放门控:低于阈值时所有文字标签隐藏(只留圆点),降低密集渲染开销。
    /// 单 Studio 地图,用类级状态即可;Coordinator 在 region settle 时设置 + 刷新可见视图。
    static var labelsAllowed = true

    /// 缩放跨阈值后由 Coordinator 调用,仅重排标签显隐,不重建 annotation。
    func applyLabelVisibility() {
        refresh()
    }

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

        shapeLayer.lineWidth = 1.5
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.25
        shapeLayer.shadowRadius = 2
        shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
        dot.layer.addSublayer(shapeLayer)

        glyphLabel.textAlignment = .center
        glyphLabel.font = .systemFont(ofSize: 11, weight: .bold)
        glyphLabel.textColor = .white
        dot.addSubview(glyphLabel)

        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.layer.cornerRadius = 4
        nameLabel.layer.masksToBounds = true
        nameLabel.textAlignment = .center

        addSubview(dot)
        addSubview(nameLabel)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func refresh() {
        guard let a = annotation as? PinAnnotation else { return }
        let style = a.style
        let dotSize = style.size

        let fill = HexColor.parse(style.fillHex) ?? .gray
        let stroke = HexColor.parse(style.strokeHex) ?? .white
        let glyphColor = HexColor.parse(style.glyphHex) ?? .white

        shapeLayer.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        let path = PinShapePath.path(for: style.shape, in: shapeLayer.bounds).cgPath
        shapeLayer.path = path
        // 显式 shadowPath:否则 CoreAnimation 每帧从 layer 内容算阴影(离屏渲染),
        // 缩放时 ×数百 pin → 严重掉帧。给定 path 后阴影计算变 O(1)。
        shapeLayer.shadowPath = path
        shapeLayer.fillColor = fill.cgColor
        shapeLayer.strokeColor = stroke.cgColor

        glyphLabel.text = style.glyph
        glyphLabel.textColor = glyphColor
        glyphLabel.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        glyphLabel.isHidden = (style.glyph == nil) || (style.glyph?.isEmpty == true)

        if style.labelVisible, Self.labelsAllowed, !a.name.isEmpty {
            nameLabel.isHidden = false
            nameLabel.text = "  \(a.name)  "
            nameLabel.backgroundColor = fill.withAlphaComponent(0.92)
            let nameSize = nameLabel.intrinsicContentSize
            let h: CGFloat = max(dotSize, nameSize.height + 2)
            dot.frame = CGRect(x: 0, y: (h - dotSize) / 2, width: dotSize, height: dotSize)
            nameLabel.frame = CGRect(x: dotSize + Self.gap, y: 0, width: nameSize.width, height: h)
            frame = CGRect(x: 0, y: 0, width: dotSize + Self.gap + nameSize.width, height: h)
        } else {
            nameLabel.isHidden = true
            dot.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
            frame = dot.frame
        }
        centerOffset = CGPoint(x: (frame.width - dotSize) / 2, y: 0)
        if let a = annotation as? PinAnnotation {
            alpha = a.dimmed ? 0.28 : 1.0
            if a.highlighted {
                shapeLayer.shadowColor = UIColor.systemYellow.cgColor
                shapeLayer.shadowOpacity = 0.9
                shapeLayer.shadowRadius = 5
                shapeLayer.lineWidth = 2.5
            } else {
                shapeLayer.shadowColor = UIColor.black.cgColor
                shapeLayer.shadowOpacity = 0.25
                shapeLayer.shadowRadius = 2
                shapeLayer.lineWidth = 1.5
            }
        }
    }
}

enum HexColor {
    static func parse(_ hex: String) -> UIColor? {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let n = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((n >> 16) & 0xFF) / 255
        let g = CGFloat((n >> 8) & 0xFF) / 255
        let b = CGFloat(n & 0xFF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    /// UIColor → "#RRGGBB"(钳到 0–255,忽略 alpha)。供 ColorPicker 回写 hex 用。
    static func hexString(from color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func channel(_ value: CGFloat) -> Int {
            max(0, min(255, Int((value * 255).rounded())))
        }
        return String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
    }
}
#endif
