import Foundation

/// 选 pin 名称标签字色:亮底用深字、暗底用白字。基于 sRGB luma。
/// 纯逻辑(无 UIKit),便于单测;PinAnnotationView 消费。
enum ContrastText {
    static let darkHex = "#1A1A1A"
    static let lightHex = "#FFFFFF"

    /// 名称标签字色 hex(随底色 fillHex)。解析失败回退白字。
    static func labelHex(onFill fillHex: String) -> String {
        isLight(fillHex) ? darkHex : lightHex
    }

    /// 底色是否"亮"(luma > 0.7)。阈值 0.7:黄(#FFCC00,0.769)算亮 → 深字;
    /// 学校红(0.456)/橙(0.642)/灰(0.557)≤0.7 仍算暗 → 白字不变。
    static func isLight(_ hex: String) -> Bool {
        guard let (r, g, b) = rgb(hex) else { return false }
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        return luma > 0.7
    }

    private static func rgb(_ hex: String) -> (Double, Double, Double)? {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let n = UInt32(s, radix: 16) else { return nil }
        return (
            Double((n >> 16) & 0xFF) / 255,
            Double((n >> 8) & 0xFF) / 255,
            Double(n & 0xFF) / 255
        )
    }
}
