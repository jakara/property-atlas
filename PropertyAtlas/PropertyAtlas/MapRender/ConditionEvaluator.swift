import Foundation

enum StyleConditionOp: String, Codable, Hashable {
    case equals
    case notEquals
    case inOp = "in"
    case contains
    case gte
    case lte
    case exists
}

struct StyleCondition: Codable {
    let field: String
    let op: StyleConditionOp
    let value: AnyJSON
}

struct StyleEntity {
    let entityType: String
    let id: UUID
    private let baseFields: [String: AnyJSON]
    private let customFields: [String: AnyJSON]
    /// 实体级 override（typed 列 → partial）。空 partial = 无 override。
    let overridePin: PartialPinStyle
    let overrideArea: PartialAreaStyle

    init(
        entityType: String,
        id: UUID,
        baseFields: [String: AnyJSON],
        customFields: [String: AnyJSON],
        overridePin: PartialPinStyle = PartialPinStyle(),
        overrideArea: PartialAreaStyle = PartialAreaStyle()
    ) {
        self.entityType = entityType
        self.id = id
        self.baseFields = baseFields
        self.customFields = customFields
        self.overridePin = overridePin
        self.overrideArea = overrideArea
    }

    func field(_ name: String) -> AnyJSON? {
        if let val = baseFields[name] { return val }
        return customFields[name]
    }
}

enum ConditionEvaluator {
    static func matches(entity: StyleEntity, condition: StyleCondition) -> Bool {
        let actual = entity.field(condition.field)
        switch condition.op {
        case .equals:
            return actual == condition.value
        case .notEquals:
            return actual != condition.value
        case .inOp:
            if case let .array(items) = condition.value, let a = actual {
                return items.contains(a)
            }
            return false
        case .contains:
            if case let .string(needle) = condition.value,
               case let .string(haystack) = actual
            {
                return haystack.contains(needle)
            }
            return false
        case .gte:
            guard let l = numeric(actual), let r = numeric(condition.value) else { return false }
            return l >= r
        case .lte:
            guard let l = numeric(actual), let r = numeric(condition.value) else { return false }
            return l <= r
        case .exists:
            if actual == nil { return false }
            if case .null = actual { return false }
            return true
        }
    }

    static func numeric(_ v: AnyJSON?) -> Double? {
        switch v {
        case let .int(n): Double(n)
        case let .double(d): d
        default: nil
        }
    }
}

// MARK: entity adapters

@MainActor
extension School {
    var styleEntity: StyleEntity {
        let custom: [String: AnyJSON] = customFieldsJSON.flatMap { try? JSONHelpers.decode($0) } ?? [:]
        var base: [String: AnyJSON] = [:]
        base["name"] = .string(name)
        if let v = address { base["address"] = .string(v) }
        if let v = category { base["category"] = .string(v) }
        if let v = grade { base["grade"] = .string(v) }
        if let v = form { base["form"] = .string(v) }
        if let v = foundYear { base["foundYear"] = .int(v) }
        if let v = capacity { base["capacity"] = .int(v) }
        if let v = communitiesText { base["communitiesText"] = .string(v) }
        return StyleEntity(
            entityType: "school", id: id, baseFields: base, customFields: custom,
            overridePin: StyleFieldConvert.pinPartial(
                shape: styleShape, fillHex: styleFillHex, strokeHex: styleStrokeHex,
                glyph: styleGlyph, glyphHex: styleGlyphHex, size: styleSize, labelVisible: styleLabelVisible
            )
        )
    }
}

@MainActor
extension Compound {
    var styleEntity: StyleEntity {
        let custom: [String: AnyJSON] = customFieldsJSON.flatMap { try? JSONHelpers.decode($0) } ?? [:]
        var base: [String: AnyJSON] = [:]
        base["name"] = .string(name)
        if let v = address { base["address"] = .string(v) }
        if let v = buildYear { base["buildYear"] = .int(v) }
        if let v = developer { base["developer"] = .string(v) }
        if let v = propertyMgmt { base["propertyMgmt"] = .string(v) }
        if let v = propertyFeeCents { base["propertyFeeCents"] = .int(v) }
        if let v = landYears { base["landYears"] = .int(v) }
        if let v = finishType { base["finishType"] = .string(v) }
        if let v = deliveryTime { base["deliveryTime"] = .string(v) }
        base["isNewHouse"] = .bool(isNewHouse)
        return StyleEntity(
            entityType: "compound", id: id, baseFields: base, customFields: custom,
            overridePin: StyleFieldConvert.pinPartial(
                shape: styleShape, fillHex: styleFillHex, strokeHex: styleStrokeHex,
                glyph: styleGlyph, glyphHex: styleGlyphHex, size: styleSize, labelVisible: styleLabelVisible
            )
        )
    }
}

@MainActor
extension POI {
    var styleEntity: StyleEntity {
        let custom: [String: AnyJSON] = customFieldsJSON.flatMap { try? JSONHelpers.decode($0) } ?? [:]
        var base: [String: AnyJSON] = [:]
        base["name"] = .string(name)
        if let v = address { base["address"] = .string(v) }
        if let v = category { base["category"] = .string(v) }
        return StyleEntity(
            entityType: "poi", id: id, baseFields: base, customFields: custom,
            overridePin: StyleFieldConvert.pinPartial(
                shape: styleShape, fillHex: styleFillHex, strokeHex: styleStrokeHex,
                glyph: styleGlyph, glyphHex: styleGlyphHex, size: styleSize, labelVisible: styleLabelVisible
            )
        )
    }
}

@MainActor
extension Area {
    var styleEntity: StyleEntity {
        let custom: [String: AnyJSON] = customFieldsJSON.flatMap { try? JSONHelpers.decode($0) } ?? [:]
        var base: [String: AnyJSON] = [:]
        base["name"] = .string(name)
        if let v = category { base["category"] = .string(v) }
        base["fillOpacity"] = .double(fillOpacity)
        if let v = textDescription { base["textDescription"] = .string(v) }
        return StyleEntity(
            entityType: "area", id: id, baseFields: base, customFields: custom,
            overrideArea: StyleFieldConvert.areaPartial(
                fillHex: styleFillHex, fillOpacity: styleFillOpacity, strokeHex: styleStrokeHex,
                strokeWidth: styleStrokeWidth, labelVisible: styleLabelVisible
            )
        )
    }
}
