import Foundation
import Observation

@MainActor
@Observable
final class DimensionFilterState {
    private(set) var hidden: [String: Set<String>] = [:]

    func isHidden(dimensionKey: String, value: String) -> Bool {
        hidden[dimensionKey]?.contains(value) == true
    }

    func toggle(dimensionKey: String, value: String) {
        var set = hidden[dimensionKey] ?? []
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
        hidden[dimensionKey] = set.isEmpty ? nil : set
    }

    func reset() {
        hidden = [:]
    }
}
