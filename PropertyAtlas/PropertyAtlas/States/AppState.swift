// PropertyAtlas/PropertyAtlas/States/AppState.swift
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum EditTab { case basic, relations, media, custom, privateNotes }

    var activeDatasetId: UUID?
    var activeThemeId: UUID?
    var selectedRef: EntityRef?
    var currentEditTab: EditTab = .basic

    /// 单一就地编辑面板:选中即打开可编辑面板(无只读/编辑切换)。
    func select(_ ref: EntityRef) {
        selectedRef = ref
        currentEditTab = .basic
    }

    /// 兼容旧调用(新建后)。面板已就地可编辑,这里只回到基本 tab。
    func beginEditing() {
        currentEditTab = .basic
    }

    func clearSelection() {
        selectedRef = nil
    }

    func switchDataset(to id: UUID) {
        activeDatasetId = id
        clearSelection()
    }
}
