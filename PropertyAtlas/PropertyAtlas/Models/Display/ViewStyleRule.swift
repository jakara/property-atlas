import Foundation
import SwiftData

/// 视图持有的条件样式规则(条件层)。每 (viewId × entityType) 可 0..N 条。
/// 命中(全部 ViewStyleCondition AND)则其非 nil 属性列覆盖视图固定默认。priority 升序合并。
@Model
final class ViewStyleRule {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var viewId: UUID = UUID()
    var entityType: String = ""
    var priority: Int = 0
    var enabled: Bool = true

    var shape: String?
    var fillHex: String?
    var strokeHex: String?
    var glyph: String?
    var glyphHex: String?
    var size: Int?
    var labelVisible: Bool?
    var fillOpacity: Double?
    var strokeWidth: Double?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), datasetId: UUID, viewId: UUID, entityType: String) {
        self.id = id
        self.datasetId = datasetId
        self.viewId = viewId
        self.entityType = entityType
    }
}
