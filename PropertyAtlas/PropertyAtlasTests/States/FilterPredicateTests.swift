// PropertyAtlasTests/States/FilterPredicateTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct FilterPredicateTests {
    private func ent(_ type: String, _ fields: [String: AnyJSON]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: fields, customFields: [:])
    }

    @Test func displayNormalizesScalars() {
        #expect(FilterPredicate.display(.string("精装")) == "精装")
        #expect(FilterPredicate.display(.int(2020)) == "2020")
        #expect(FilterPredicate.display(.bool(true)) == "true")
        #expect(FilterPredicate.display(nil) == "")
    }

    @Test func emptyHiddenPassesAll() {
        let p = FilterPredicate(hidden: [:])
        #expect(p.passes(ent("school", ["category": .string("小学")]), fieldKeys: ["category"]))
    }

    @Test func hiddenValueFailsThatEntity() {
        let p = FilterPredicate(hidden: ["school.category": Set(["小学"])])
        #expect(!p.passes(ent("school", ["category": .string("小学")]), fieldKeys: ["category"]))
        #expect(p.passes(ent("school", ["category": .string("初中")]), fieldKeys: ["category"]))
    }

    @Test func andAcrossSlots() {
        let p = FilterPredicate(hidden: ["school.grade": Set(["普通"])])
        #expect(!p.passes(
            ent("school", ["category": .string("小学"), "grade": .string("普通")]),
            fieldKeys: ["category", "grade"]
        ))
    }

    @Test func excludeSelfFieldIgnoresOwnHidden() {
        let p = FilterPredicate(hidden: ["school.category": Set(["小学"])])
        #expect(p.passes(
            ent("school", ["category": .string("小学")]),
            fieldKeys: ["category"],
            excludeFieldKey: "category"
        ))
    }
}
