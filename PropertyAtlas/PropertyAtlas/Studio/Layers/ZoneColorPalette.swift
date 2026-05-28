#if targetEnvironment(macCatalyst)
import Foundation
import UIKit

/// 学片→颜色 调色板. 同学片 pin + polygon 同色.
/// 8 色, hash(zoneName) % 8 选色, 同名稳定.
enum ZoneColorPalette {
    /// ColorBrewer Set1 改 — 高饱和高对比, 白字 readable. 跳黄(白字看不清).
    static let colors: [UIColor] = [
        UIColor(red: 0xE4 / 255.0, green: 0x1A / 255.0, blue: 0x1C / 255.0, alpha: 1), // 红
        UIColor(red: 0x37 / 255.0, green: 0x7E / 255.0, blue: 0xB8 / 255.0, alpha: 1), // 蓝
        UIColor(red: 0x4D / 255.0, green: 0xAF / 255.0, blue: 0x4A / 255.0, alpha: 1), // 绿
        UIColor(red: 0x98 / 255.0, green: 0x4E / 255.0, blue: 0xA3 / 255.0, alpha: 1), // 紫
        UIColor(red: 0xFF / 255.0, green: 0x7F / 255.0, blue: 0x00 / 255.0, alpha: 1), // 橙
        UIColor(red: 0xA6 / 255.0, green: 0x56 / 255.0, blue: 0x28 / 255.0, alpha: 1), // 棕
        UIColor(red: 0xF7 / 255.0, green: 0x81 / 255.0, blue: 0xBF / 255.0, alpha: 1), // 粉
        UIColor(red: 0x17 / 255.0, green: 0xBE / 255.0, blue: 0xCF / 255.0, alpha: 1), // 青
    ]
    /// 空 zoneName 默认色 (紫). 不再用灰.
    static let fallback = UIColor(red: 0x98 / 255.0, green: 0x4E / 255.0, blue: 0xA3 / 255.0, alpha: 1)

    /// 所有 zone (含"行政区域"/"全区"/"特殊") 都 hash 到 8 色板.
    static func color(for zoneName: String?) -> UIColor {
        guard let name = zoneName, !name.isEmpty else { return fallback }
        var hash: UInt32 = 5381
        for u in name.unicodeScalars {
            hash = (hash &* 33) &+ u.value
        }
        return colors[Int(hash % UInt32(colors.count))]
    }

    static func hex(for zoneName: String?) -> String {
        let c = color(for: zoneName)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }

    static func color(fromHex hex: String) -> UIColor {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return fallback }
        return UIColor(
            red: CGFloat((v >> 16) & 0xFF) / 255.0,
            green: CGFloat((v >> 8) & 0xFF) / 255.0,
            blue: CGFloat(v & 0xFF) / 255.0,
            alpha: 1
        )
    }
}
#endif
