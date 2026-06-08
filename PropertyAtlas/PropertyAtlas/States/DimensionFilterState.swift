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

    /// 持久化快照(Set → 有序数组)。
    func snapshot() -> [String: [String]] {
        hidden.mapValues { Array($0).sorted() }
    }

    /// 从持久化字典恢复(空值剔除)。
    func load(_ dict: [String: [String]]) {
        hidden = dict.compactMapValues { $0.isEmpty ? nil : Set($0) }
    }
}
