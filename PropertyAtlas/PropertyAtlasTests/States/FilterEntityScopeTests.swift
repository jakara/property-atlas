import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct FilterEntityScopeTests {
    // MARK: Codable 容错 — 旧 JSON 无 entityType 字段不应崩、回退空串

    @Test func primaryDecodesLegacyJSONWithoutEntityType() throws {
        let json = #"{"conditions":[],"groupBy":null}"#
        let pf = try JSONDecoder().decode(PrimaryFilter.self, from: Data(json.utf8))
        #expect(pf.entityType == "")
        #expect(pf.conditions.isEmpty)
    }

    @Test func normalDecodesLegacyJSONWithoutEntityType() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"等级","dimension":{"kind":"field","fieldKey":"grade","fieldSource":"base"}}
        """
        let nf = try JSONDecoder().decode(NormalFilter.self, from: Data(json.utf8))
        #expect(nf.entityType == "")
        #expect(nf.name == "等级")
    }

    @Test func roundTripPreservesEntityType() throws {
        let nf = NormalFilter(name: "阶段", dimension: MapDimension(kind: .field, fieldKey: "category"), entityType: "school")
        let data = try JSONEncoder().encode(nf)
        let back = try JSONDecoder().decode(NormalFilter.self, from: data)
        #expect(back.entityType == "school")
    }

    // MARK: inferEntityType — 旧库回填映射

    @Test func inferByName() {
        let d = MapDimension(kind: .field, fieldKey: "category")
        #expect(LegacyMigrator.inferEntityType(name: "区域类型", dimension: d) == "area")
        #expect(LegacyMigrator.inferEntityType(name: "阶段", dimension: d) == "school")
        #expect(LegacyMigrator.inferEntityType(name: "POI 类型", dimension: d) == "poi")
    }

    @Test func inferByFieldKeyWhenNameUnknown() {
        #expect(LegacyMigrator.inferEntityType(
            name: "随便", dimension: MapDimension(kind: .field, fieldKey: "finishType")
        ) == "compound")
        #expect(LegacyMigrator.inferEntityType(
            name: "随便", dimension: MapDimension(kind: .field, fieldKey: "grade")
        ) == "school")
    }

    @Test func ambiguousCategoryFieldReturnsNil() {
        #expect(LegacyMigrator.inferEntityType(
            name: "随便", dimension: MapDimension(kind: .field, fieldKey: "category")
        ) == nil)
    }
}
