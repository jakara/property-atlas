import Foundation
import SwiftData

@Model
final class Layer {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var iconSF: String?
    var colorHex: String?
    // 新:图层 = 单一实体类型(创建时定死)
    var entityType: String = "compound"
    // 新:吸收自 MapView 的视图配置
    var primaryFilterJSON: String = #"{"conditions":[],"groupBy":null}"#
    var normalFiltersJSON: String = "[]"
    var hiddenChipsJSON: String = "{}"
    var paletteHex: [String] = []
    var showLegend: Bool = true
    // 既有
    var staticRefsJSON: String? // deprecated, Phase B 删
    var dynamicQueryJSON: String? // deprecated, Phase B 删
    var minZoom: Double?
    var maxZoom: Double?
    var isDefault: Bool = false // deprecated, Phase B 删
    var enabled: Bool = true
    var sortOrder: Int = 0
    var zIndex: Int = 0
    var themeId: UUID? // deprecated, Phase B 删
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), datasetId: UUID, name: String, entityType: String = "compound") {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.entityType = entityType
    }
}
