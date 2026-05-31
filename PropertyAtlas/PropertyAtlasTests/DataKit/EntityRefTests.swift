// PropertyAtlasTests/DataKit/EntityRefTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

struct EntityRefTests {
    @Test func kindRoundTripsRawValue() {
        #expect(EntityKind(rawValue: "compound") == .compound)
        #expect(EntityKind.school.rawValue == "school")
        #expect(EntityKind(rawValue: "nope") == nil)
    }

    @Test func refEqualityByIdAndKind() {
        let id = UUID()
        #expect(EntityRef(id: id, kind: .poi) == EntityRef(id: id, kind: .poi))
        #expect(EntityRef(id: id, kind: .poi) != EntityRef(id: id, kind: .area))
    }

    @Test func typeStringMatchesRawValue() {
        #expect(EntityRef(id: UUID(), kind: .area).typeString == "area")
    }
}
