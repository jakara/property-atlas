// PropertyAtlas/PropertyAtlas/States/LayerState.swift
import Foundation
import Observation

@MainActor
@Observable
final class LayerState {
    private(set) var enabledIds: Set<UUID> = []
    private var initialized: Bool = false

    func initialize(enabledIds: [UUID]) {
        self.enabledIds = Set(enabledIds)
        initialized = true
    }

    /// 仅当尚未初始化时套用默认（防止运行时 toggle 被覆盖）。
    func initializeIfNeeded(enabledIds: [UUID]) {
        guard !initialized else { return }
        initialize(enabledIds: enabledIds)
    }

    /// 切 theme 时强制重置。
    func resetForTheme(enabledIds: [UUID]) {
        initialize(enabledIds: enabledIds)
    }

    func isEnabled(_ id: UUID) -> Bool {
        enabledIds.contains(id)
    }

    func toggle(_ id: UUID) {
        if enabledIds.contains(id) { enabledIds.remove(id) } else { enabledIds.insert(id) }
    }
}
