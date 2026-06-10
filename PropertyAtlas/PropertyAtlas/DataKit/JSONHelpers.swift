import Foundation

/// Discriminated JSON value used in *JSON String columns where Codable models
/// stored heterogeneous payloads (e.g. CustomFieldDef.defaultValueJSON).
enum AnyJSON: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyJSON])
    case object([String: AnyJSON])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .double(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null
            return
        }
        // Bool must come before Int: on Foundation JSONDecoder, Bool decodes
        // as Int 1/0 on some platforms if Int is tried first.
        if let value = try? container.decode(Bool.self) { self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) { self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) { self = .double(value)
            return
        }
        if let value = try? container.decode(String.self) { self = .string(value)
            return
        }
        if let value = try? container.decode([AnyJSON].self) { self = .array(value)
            return
        }
        if let value = try? container.decode([String: AnyJSON].self) { self = .object(value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "AnyJSON: unknown payload"
        )
    }
}

enum JSONHelpers {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    static let decoder = JSONDecoder()

    static func encode(_ value: some Encodable) throws -> String {
        let data = try encoder.encode(value)
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    static func decode<T: Decodable>(_ string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw NSError(
                domain: "JSONHelpers",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "utf8 encoding failed"]
            )
        }
        return try decoder.decode(T.self, from: data)
    }
}
