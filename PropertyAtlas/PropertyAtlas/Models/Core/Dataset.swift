// PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift
import Foundation
import SwiftData

@Model
final class Dataset {
    var id: UUID = UUID()
    var name: String = ""
    var activeThemeId: UUID?
    var activeCameraPresetId: UUID?
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
