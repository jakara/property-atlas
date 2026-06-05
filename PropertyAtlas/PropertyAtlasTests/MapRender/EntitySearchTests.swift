import CoreLocation
import Testing
@testable import PropertyAtlas

#if targetEnvironment(macCatalyst)
@MainActor
struct EntitySearchTests {
    private func mk(
        _ kind: EntityKind, _ name: String,
        aliases: [String] = [], address: String? = nil, category: String? = nil
    ) -> EntitySearch.Searchable {
        EntitySearch.Searchable(
            ref: EntityRef(id: UUID(), kind: kind), name: name, aliases: aliases,
            address: address, category: category,
            coordinate: CLLocationCoordinate2D(latitude: 39, longitude: 117), hasCoordinate: true
        )
    }

    @Test func emptyQueryReturnsEmpty() {
        let items = [mk(.compound, "万科城")]
        #expect(EntitySearch.search("", in: items).isEmpty)
        #expect(EntitySearch.search("   ", in: items).isEmpty)
    }

    @Test func namePrefixRanksAboveSubstring() {
        let items = [mk(.compound, "万科城"), mk(.compound, "城市花园")]
        let hits = EntitySearch.search("城", in: items)
        #expect(hits.count == 2)
        #expect(hits[0].name == "城市花园")
    }

    @Test func matchesAlias() {
        let hits = EntitySearch.search("实小", in: [mk(.school, "实验小学", aliases: ["实小"])])
        #expect(hits.count == 1)
        #expect(hits[0].name == "实验小学")
    }

    @Test func matchesAddressAndCategory() {
        let items = [mk(.poi, "星巴克", address: "南京路1号", category: "咖啡")]
        #expect(EntitySearch.search("南京路", in: items).count == 1)
        #expect(EntitySearch.search("咖啡", in: items).count == 1)
    }

    @Test func caseInsensitive() {
        #expect(EntitySearch.search("apple", in: [mk(.poi, "Apple Store")]).count == 1)
    }

    @Test func limitTruncates() {
        let items = (0..<60).map { mk(.poi, "店\($0)") }
        #expect(EntitySearch.search("店", in: items, limit: 50).count == 50)
    }

    @Test func subtitleIncludesType() {
        let hits = EntitySearch.search("实验", in: [mk(.school, "实验小学", address: "河西区")])
        #expect(hits[0].subtitle == "学校 · 河西区")
    }
}
#endif
