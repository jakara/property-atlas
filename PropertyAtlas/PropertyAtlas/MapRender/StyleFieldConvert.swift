import CoreGraphics
import Foundation

/// 可空样式字段(ViewEntityStyle / 实体 override 列)→ PartialPinStyle/PartialAreaStyle。
/// 无副作用纯映射;非法 shape 字符串 → nil(忽略)。
enum StyleFieldConvert {
    static func pinPartial(
        shape: String?,
        fillHex: String?,
        strokeHex: String?,
        glyph: String?,
        glyphHex: String?,
        size: Int?,
        labelVisible: Bool?
    ) -> PartialPinStyle {
        PartialPinStyle(
            shape: shape.flatMap { PinShape(rawValue: $0) },
            fillHex: fillHex,
            strokeHex: strokeHex,
            glyph: glyph,
            glyphHex: glyphHex,
            size: size.map { CGFloat($0) },
            labelVisible: labelVisible
        )
    }

    static func areaPartial(
        fillHex: String?,
        fillOpacity: Double?,
        strokeHex: String?,
        strokeWidth: Double?,
        labelVisible: Bool?
    ) -> PartialAreaStyle {
        PartialAreaStyle(
            fillHex: fillHex,
            fillOpacity: fillOpacity,
            strokeHex: strokeHex,
            strokeWidth: strokeWidth,
            labelVisible: labelVisible
        )
    }
}
