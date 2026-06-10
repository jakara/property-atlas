// PropertyAtlasTests/States/AppStateTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct AppStateTests {
    @Test func selectSetsRefAndDefaultsToReadMode() {
        let s = AppState()
        let ref = EntityRef(id: UUID(), kind: .school)
        s.select(ref)
        #expect(s.selectedRef == ref)
    }

    @Test func editEntersEditMode() {
        let s = AppState()
        s.select(EntityRef(id: UUID(), kind: .poi))
        s.beginEditing()
        #expect(s.currentEditTab == .basic)
    }

    @Test func clearSelectionResetsMode() {
        let s = AppState()
        s.select(EntityRef(id: UUID(), kind: .poi))
        s.beginEditing()
        s.clearSelection()
        #expect(s.selectedRef == nil)
    }

    @Test func switchDatasetResetsSelection() {
        let s = AppState()
        s.activeDatasetId = UUID()
        s.select(EntityRef(id: UUID(), kind: .area))
        s.switchDataset(to: UUID())
        #expect(s.selectedRef == nil)
    }
}
