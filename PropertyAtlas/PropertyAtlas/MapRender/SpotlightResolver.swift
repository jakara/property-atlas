// PropertyAtlas/PropertyAtlas/MapRender/SpotlightResolver.swift
import Foundation

enum SpotlightResolver {
    /// 返回应高亮（不 dim）的 id 集；nil = 不启用 spotlight（全部正常）。
    static func highlightedIds(selected: UUID?, relatedIds: [UUID], enabled: Bool) -> Set<UUID>? {
        guard enabled, let selected else { return nil }
        var set = Set(relatedIds)
        set.insert(selected)
        return set
    }
}
