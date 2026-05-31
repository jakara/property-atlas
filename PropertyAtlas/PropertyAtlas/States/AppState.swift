// PropertyAtlas/PropertyAtlas/States/AppState.swift
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum EditingMode { case read, edit, live }
    enum EditTab { case basic, relations, media, custom, privateNotes }

    var activeDatasetId: UUID?
    var activeThemeId: UUID?
    var selectedRef: EntityRef?
    var editingMode: EditingMode = .read
    var currentEditTab: EditTab = .basic

    func select(_ ref: EntityRef) {
        selectedRef = ref
        editingMode = .read
    }

    func beginEditing() {
        guard selectedRef != nil else { return }
        editingMode = .edit
        currentEditTab = .basic
    }

    func clearSelection() {
        selectedRef = nil
        editingMode = .read
    }

    func switchDataset(to id: UUID) {
        activeDatasetId = id
        clearSelection()
    }
}
