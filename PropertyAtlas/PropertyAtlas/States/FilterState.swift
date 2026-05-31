// PropertyAtlas/PropertyAtlas/States/FilterState.swift
import Foundation
import Observation

@MainActor
@Observable
final class FilterState {
    private(set) var hidden: [String: Set<String>] = [:]

    func isHidden(entityType: String, fieldKey: String, value: String) -> Bool {
        hidden[FilterPredicate.key(entityType, fieldKey)]?.contains(value) == true
    }

    func toggle(entityType: String, fieldKey: String, value: String) {
        let k = FilterPredicate.key(entityType, fieldKey)
        var set = hidden[k] ?? []
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
        hidden[k] = set.isEmpty ? nil : set
    }

    func reset() {
        hidden = [:]
    }

    var predicate: FilterPredicate {
        FilterPredicate(hidden: hidden)
    }
}
