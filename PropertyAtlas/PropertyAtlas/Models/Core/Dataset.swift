// PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift
import Foundation
import SwiftData

@Model
final class Dataset {
    var id: UUID = UUID()
    var name: String = ""
    var activeThemeId: UUID?
    var activeCameraPresetId: UUID?
    var stylesMigratedV2: Bool = false
    var areaNamesNormalizedV1: Bool = false
    var districtBoundariesSeededV1: Bool = false
    var filterEntityTypeMigratedV1: Bool = false
    var roadLinesSeededV1: Bool = false
    // 全局展示设置(原 MapView 持有;多图层同屏后上提 dataset)
    var studioMapStyleRaw: String = "mutedLight"
    var bgMapStyle: String = "standard"
    var canvasAspectRaw: String = "16:9"
    var poiEnabled: Bool = false
    var poiCategoriesRaw: String = ""
    var spotlightOnSelect: Bool = true
    var drawEdgeLines: [String] = []
    var copyTitle: String?
    var copySubtitle: String?
    var copyWatermark: String?
    var watermarkQRData: Data?
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
