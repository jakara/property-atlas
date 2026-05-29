import Foundation

enum PaletteResolver {
    static let fallbackHex = "#7C7C7C"

    static func resolve(palette: Palette, entity: StyleEntity, keyField: String?) -> String {
        guard !palette.colorsHex.isEmpty else { return fallbackHex }
        let key = resolveKey(entity: entity, keyField: keyField)
        let h = StableHash.fnv1a32(key)
        let idx = Int(h % UInt32(palette.colorsHex.count))
        return palette.colorsHex[idx]
    }

    private static func resolveKey(entity: StyleEntity, keyField: String?) -> String {
        if let field = keyField, !field.isEmpty,
           let v = entity.field(field),
           let s = stringify(v)
        {
            return s
        }
        return entity.id.uuidString
    }

    private static func stringify(_ v: AnyJSON) -> String? {
        switch v {
        case let .string(s): s.isEmpty ? nil : s
        case let .int(n): String(n)
        case let .double(d): String(d)
        case let .bool(b): String(b)
        case .null, .array, .object: nil
        }
    }
}
