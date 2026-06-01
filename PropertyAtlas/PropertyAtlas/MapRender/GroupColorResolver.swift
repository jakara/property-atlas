import Foundation
import SwiftData

/// 分组染色:可见实体在 groupBy 维度的值集 → PaletteAssigner 取色 → 每实体 fillHex。
/// groupBy 为 nil 或 palette 空 → 返回空(此时渲染走 theme 基样式)。多值取排序首值作染色键。
@MainActor
enum GroupColorResolver {
    struct Item {
        let id: UUID
        let entity: StyleEntity
        let layerNames: [String]
    }

    static func colors(
        items: [Item],
        groupBy: MapDimension?,
        palette: [String],
        context: ModelContext?,
        datasetId: UUID?
    ) -> [UUID: String] {
        guard let gb = groupBy, !palette.isEmpty else { return [:] }
        var firstValue: [UUID: String] = [:]
        var distinct = Set<String>()
        for it in items {
            let input = MapDimension.Input(entity: it.entity, layerNames: it.layerNames, context: context, datasetId: datasetId)
            let vals = gb.resolve(input).sorted()
            guard let first = vals.first, !first.isEmpty else { continue }
            firstValue[it.id] = first
            distinct.insert(first)
        }
        let assign = PaletteAssigner.assign(values: Array(distinct), palette: palette)
        var out: [UUID: String] = [:]
        for (id, v) in firstValue {
            if let hex = assign[v] { out[id] = hex }
        }
        return out
    }
}
