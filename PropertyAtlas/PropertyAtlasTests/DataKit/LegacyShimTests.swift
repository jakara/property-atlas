import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LegacyShimTests {
    @Test func schoolLegacyTypeReadsFromCategory() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.category = "小学"
        #expect(s.legacyType == "小学")
    }

    @Test func schoolLegacyTierReadsFromGrade() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        #expect(s.legacyTier == "重点")
    }

    @Test func schoolLegacyTierDefaultsToPutongWhenGradeNil() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        #expect(s.legacyTier == "普通")
    }

    @Test func schoolLegacyIsJiunianReadsFromForm() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.form = "九年一贯"
        #expect(s.legacyIsJiunian == true)
        s.form = "普通"
        #expect(s.legacyIsJiunian == false)
    }

    @Test func schoolLegacyZoneIdReadsFromPrimaryAreaId() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let id = UUID()
        s.primaryAreaId = id
        #expect(s.legacyZoneId == id)
    }

    @Test func compoundLegacyZoneIdReadsFromPrimaryAreaId() {
        let c = Compound(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let id = UUID()
        c.primaryAreaId = id
        #expect(c.legacyZoneId == id)
    }
}
