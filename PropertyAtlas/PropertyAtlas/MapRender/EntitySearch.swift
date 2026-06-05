#if targetEnvironment(macCatalyst)
import CoreLocation
import Foundation

/// 库内实体搜索纯逻辑。匹配 name / aliases / address / category,带排序权重。
enum EntitySearch {
    struct Searchable {
        let ref: EntityRef
        let name: String
        let aliases: [String]
        let address: String?
        let category: String?
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
    }

    struct Hit: Identifiable {
        let ref: EntityRef
        let name: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
        var id: UUID {
            ref.id
        }
    }

    /// 大小写无关子串匹配。排序:name 前缀(0) > name 子串(1) > alias(2) > address/category(3);
    /// 同权按 name 本地化升序。空 query → []。
    static func search(_ query: String, in items: [Searchable], limit: Int = 50) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var ranked: [(rank: Int, hit: Hit)] = []
        for item in items {
            guard let rank = matchRank(trimmed, item) else { continue }
            ranked.append((rank, makeHit(item)))
        }
        ranked.sort { lhs, rhs in
            lhs.rank != rhs.rank
                ? lhs.rank < rhs.rank
                : lhs.hit.name.localizedCompare(rhs.hit.name) == .orderedAscending
        }
        return ranked.prefix(limit).map(\.hit)
    }

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func matchRank(_ query: String, _ item: Searchable) -> Int? {
        if let range = item.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
            return range.lowerBound == item.name.startIndex ? 0 : 1
        }
        if item.aliases.contains(where: { contains($0, query) }) { return 2 }
        if let address = item.address, contains(address, query) { return 3 }
        if let category = item.category, contains(category, query) { return 3 }
        return nil
    }

    private static func makeHit(_ item: Searchable) -> Hit {
        let detail = item.address ?? item.category
        let subtitle = detail.map { "\(typeLabel(item.ref.kind)) · \($0)" } ?? typeLabel(item.ref.kind)
        return Hit(
            ref: item.ref, name: item.name, subtitle: subtitle,
            coordinate: item.coordinate, hasCoordinate: item.hasCoordinate
        )
    }

    static func typeLabel(_ kind: EntityKind) -> String {
        switch kind {
        case .compound: "小区"
        case .school: "学校"
        case .poi: "POI"
        case .area: "片区"
        }
    }
}
#endif
