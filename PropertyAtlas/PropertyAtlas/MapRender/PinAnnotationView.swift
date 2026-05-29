#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

final class PinAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "pinAnnotation"
    private static let gap: CGFloat = 4

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
        shapeLayer.path = PinShapePath.path(for: style.shape, in: shapeLayer.bounds).cgPath
        shapeLayer.fillColor = fill.cgColor
        shapeLayer.strokeColor = stroke.cgColor

        glyphLabel.text = style.glyph
        glyphLabel.textColor = glyphColor
        glyphLabel.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        glyphLabel.isHidden = (style.glyph == nil) || (style.glyph?.isEmpty == true)

        if style.labelVisible, !a.name.isEmpty {
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
}
#endif
