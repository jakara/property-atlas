// PropertyAtlas/PropertyAtlas/DataKit/OverrideStyleCodec.swift
import Foundation

struct OverrideStyle: Equatable {
    var shape: String?
    var fillHex: String?
    var glyph: String?
    var glyphHex: String?
    var size: Int?
    var labelVisible: Bool?

    var isEmpty: Bool {
        shape == nil && fillHex == nil && glyph == nil && glyphHex == nil && size == nil && labelVisible == nil
    }
}

enum OverrideStyleCodec {
    static func decode(_ json: String?) -> OverrideStyle {
        guard let json, let decoded: [String: AnyJSON] = try? JSONHelpers.decode(json) else {
            return OverrideStyle()
        }
        var o = OverrideStyle()
        if case let .string(v) = decoded["shape"] { o.shape = v }
        if case let .string(v) = decoded["fillHex"] { o.fillHex = v }
        if case let .string(v) = decoded["glyph"] { o.glyph = v }
        if case let .string(v) = decoded["glyphHex"] { o.glyphHex = v }
        if case let .int(v) = decoded["size"] { o.size = v }
        if case let .double(v) = decoded["size"] { o.size = Int(v) }
        if case let .bool(v) = decoded["labelVisible"] { o.labelVisible = v }
        return o
    }

    /// 全空 → nil（清空 override = 跟随主题）。
    static func encode(_ o: OverrideStyle) -> String? {
        guard !o.isEmpty else { return nil }
        var dict: [String: AnyJSON] = [:]
        if let v = o.shape { dict["shape"] = .string(v) }
        if let v = o.fillHex { dict["fillHex"] = .string(v) }
        if let v = o.glyph { dict["glyph"] = .string(v) }
        if let v = o.glyphHex { dict["glyphHex"] = .string(v) }
        if let v = o.size { dict["size"] = .int(v) }
        if let v = o.labelVisible { dict["labelVisible"] = .bool(v) }
        return try? JSONHelpers.encode(dict)
    }
}
