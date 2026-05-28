#if targetEnvironment(macCatalyst)
import Foundation

struct PinFilter: Equatable {
    var tiers: Set<String> = ["重点", "区重点", "普通"]
    var levels: Set<String> = ["小学", "初中"]
    var jiunianVisible: Bool = true // 九年一贯 (独立维度, 与 level 正交)

    func includes(school: School) -> Bool {
        guard tiers.contains(school.legacyTier) else { return false }
        guard levels.contains(school.legacyType) else { return false }
        if school.legacyIsJiunian, !jiunianVisible { return false }
        return true
    }

    mutating func toggle(tier: String) {
        if tiers.contains(tier) { tiers.remove(tier) } else { tiers.insert(tier) }
    }

    mutating func toggle(level: String) {
        if levels.contains(level) { levels.remove(level) } else { levels.insert(level) }
    }
}
#endif
