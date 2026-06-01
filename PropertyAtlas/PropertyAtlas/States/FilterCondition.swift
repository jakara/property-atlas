import Foundation

struct FilterCondition: Codable, Equatable {
    var dimension: MapDimension
    var op: StyleConditionOp
    var value: AnyJSON

    @MainActor
    func evaluate(_ input: MapDimension.Input) -> Bool {
        let values = dimension.resolve(input)
        switch op {
        case .equals:
            return values.contains { AnyJSON.string($0) == value }
        case .notEquals:
            return !values.contains { AnyJSON.string($0) == value }
        case .inOp:
            guard case let .array(opts) = value else { return false }
            let set = Set(opts.compactMap { item -> String? in
                if case let .string(s) = item { return s } else { return nil }
            })
            return values.contains { set.contains($0) }
        case .contains:
            guard case let .string(needle) = value else { return false }
            return values.contains { $0.contains(needle) }
        case .exists:
            return !values.isEmpty
        case .gte, .lte:
            guard let r = numeric(value) else { return false }
            return values.contains { v in
                guard let l = Double(v) else { return false }
                return op == .gte ? l >= r : l <= r
            }
        }
    }

    private func numeric(_ v: AnyJSON) -> Double? {
        switch v {
        case let .int(n): Double(n)
        case let .double(d): d
        default: nil
        }
    }
}
