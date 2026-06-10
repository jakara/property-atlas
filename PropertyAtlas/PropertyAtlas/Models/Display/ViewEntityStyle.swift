import Foundation
import SwiftData

/// 视图维度的实体默认样式(spec: 视图=样式容器)。每个 MapView 持 4 行
/// (compound/school/poi/area)。全部可空,nil = 继承 builtin。pin 类型用 pin 字段,
/// area 用 area 字段。求值链中位于 builtin 之后、分组染色之前。
@Model
final class ViewEntityStyle {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var layerId: UUID = UUID()
    var entityType: String = ""

    // pin 字段
    var shape: String?
    var fillHex: String?
    var strokeHex: String?
    var glyph: String?
    var glyphHex: String?
    var size: Int?
    var labelVisible: Bool?
    // area 字段
    var fillOpacity: Double?
    var strokeWidth: Double?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), datasetId: UUID, layerId: UUID, entityType: String) {
        self.id = id
        self.datasetId = datasetId
        self.layerId = layerId
        self.entityType = entityType
    }
}
