import Foundation
import SwiftData

/// 全局视图预设(spec 的 "View";命名 MapView 避撞 SwiftUI.View)。
/// 一个 dataset 可多个。持有启用图层 + PrimaryFilter + NormalFilter[] + palette + 文案。
@Model
final class MapView {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var enabledLayerIds: [UUID] = []
    var primaryFilterJSON: String = #"{"conditions":[],"groupBy":null}"#
    var normalFiltersJSON: String = "[]"
    var visibilityJSON: String = #"{"compound":true,"school":true,"poi":true,"area":true}"#
    var paletteId: UUID?
    var cameraPresetId: UUID?
    var bgMapStyle: String = "standard"
    var drawEdgeLines: [String] = []
    var copyTitle: String?
    var copySubtitle: String?
    var copyWatermark: String?
    var spotlightOnSelect: Bool = true
    var sortOrder: Int = 0
    var isActive: Bool = false
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), datasetId: UUID, name: String) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
    }
}
