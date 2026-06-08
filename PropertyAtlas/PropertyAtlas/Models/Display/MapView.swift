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
    /// 普通过滤器 chip 隐藏态(持久):{dimensionKey: [hidden values]}。下次启动还原。
    var hiddenChipsJSON: String = "{}"
    var visibilityJSON: String = #"{"compound":true,"school":true,"poi":true,"area":true}"#
    var paletteId: UUID?
    var paletteHex: [String] = []
    var showLegend: Bool = true
    var cameraPresetId: UUID?
    var bgMapStyle: String = "standard"
    var drawEdgeLines: [String] = []
    var copyTitle: String?
    var copySubtitle: String?
    var copyWatermark: String?
    /// 出图/非出图 都展示的公众号二维码图(用户从相册/文件选)。
    var watermarkQRData: Data?
    /// 底图样式(StudioMapStyle rawValue):静音浅/深、标准、卫星、混合。
    var studioMapStyleRaw: String = "mutedLight"
    /// 是否显示系统底图 Apple 地点(POI)。
    var poiEnabled: Bool = false
    /// 选中的 POI 类别(StudioPOIOption rawValue,逗号分隔;空=全部)。
    var poiCategoriesRaw: String = ""
    /// 出图画幅(CanvasAspect rawValue)。
    var canvasAspectRaw: String = "16:9"
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
