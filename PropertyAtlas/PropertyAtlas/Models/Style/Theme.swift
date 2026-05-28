import Foundation
import SwiftData

@Model
final class Theme {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var isActive: Bool = false
    var cameraPresetId: UUID?
    var styleRuleIds: [UUID] = []
    var defaultStylesJSON: String = "{}"
    var visibilityJSON: String = #"{"compound":true,"school":true,"poi":true,"area":true}"#
    var defaultEnabledLayerIds: [UUID] = []
    var spotlightOnSelect: Bool = true
    var drawEdgeLines: [String] = []
    var showLegend: Bool = true
    var bgMapStyle: String = "standard"
    var copyTitle: String?
    var copySubtitle: String?
    var copyWatermark: String?
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
    }
}
