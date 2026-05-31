// PropertyAtlasTests/States/FilterStateTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct FilterStateTests {
    @Test func toggleHidesThenShows() {
        let s = FilterState()
        #expect(s.isHidden(entityType: "school", fieldKey: "category", value: "小学") == false)
        s.toggle(entityType: "school", fieldKey: "category", value: "小学")
        #expect(s.isHidden(entityType: "school", fieldKey: "category", value: "小学") == true)
        s.toggle(entityType: "school", fieldKey: "category", value: "小学")
        #expect(s.isHidden(entityType: "school", fieldKey: "category", value: "小学") == false)
    }

    @Test func predicateReflectsHidden() {
        let s = FilterState()
        s.toggle(entityType: "school", fieldKey: "category", value: "小学")
        #expect(s.predicate.hidden["school.category"]?.contains("小学") == true)
    }

    @Test func resetClearsAll() {
        let s = FilterState()
        s.toggle(entityType: "poi", fieldKey: "category", value: "地铁")
        s.reset()
        #expect(s.predicate.hidden.isEmpty)
    }
}
