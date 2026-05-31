// PropertyAtlasTests/MapRender/SpotlightResolverTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

struct SpotlightResolverTests {
    @Test func nilSelectionMeansNoSpotlight() {
        let r = SpotlightResolver.highlightedIds(selected: nil, relatedIds: [], enabled: true)
        #expect(r == nil) // nil = 不 dim 任何
    }

    @Test func disabledMeansNoSpotlight() {
        let r = SpotlightResolver.highlightedIds(selected: UUID(), relatedIds: [UUID()], enabled: false)
        #expect(r == nil)
    }

    @Test func includesSelectedAndRelated() {
        let sel = UUID()
        let a = UUID()
        let b = UUID()
        let r = SpotlightResolver.highlightedIds(selected: sel, relatedIds: [a, b], enabled: true)
        #expect(r == Set([sel, a, b]))
    }
}
