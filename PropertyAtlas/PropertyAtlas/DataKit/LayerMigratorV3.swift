import Foundation
import SwiftData

/// 图层中心化重构启动幂等迁移。闸 = Dataset.layerModelV3。
/// 既有库:旧 seed 已建「默认/路网」图层(无 entityType 语义)+ 旧 MapView 已随 schema 破坏消失。
/// 本迁移确保每 dataset 有「楼盘/学校/POI/行政区/路网」5 图层(按 name 幂等),展示设置已在 Dataset(默认值即可)。
@MainActor
enum LayerMigratorV3 {
    static func run(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>(
            predicate: #Predicate { !$0.deleted && !$0.layerModelV3 }
        ))) ?? []
        for ds in datasets {
            ensureLayers(ds: ds, in: context)
            ds.layerModelV3 = true
        }
        try? context.save()
    }

    private static func ensureLayers(ds: Dataset, in context: ModelContext) {
        let dsId = ds.id
        let existing = (try? context.fetch(FetchDescriptor<Layer>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted }
        ))) ?? []
        let byName = Dictionary(existing.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

        func ensure(_ name: String, _ type: String, icon: String, z: Int, enabled: Bool, category: String?) {
            let primary: PrimaryFilter = category.map {
                PrimaryFilter(conditions: [FilterCondition(
                    dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base"),
                    op: .equals, value: .string($0)
                )], groupBy: nil)
            } ?? PrimaryFilter(conditions: [], groupBy: nil)
            let primaryJSON = (try? JSONHelpers.encode(primary)) ?? #"{"conditions":[],"groupBy":null}"#
            if let l = byName[name] {
                // 既有图层(旧 seed 的「默认」「路网」)→ 补 entityType / 过滤器语义
                l.entityType = type
                if l.primaryFilterJSON.isEmpty || l.primaryFilterJSON == #"{"conditions":[],"groupBy":null}"# {
                    l.primaryFilterJSON = primaryJSON
                }
                l.updatedAt = Date()
            } else {
                let l = Layer(datasetId: dsId, name: name, entityType: type)
                l.iconSF = icon
                l.zIndex = z
                l.sortOrder = z
                l.enabled = enabled
                l.primaryFilterJSON = primaryJSON
                context.insert(l)
            }
        }
        ensure("楼盘", "compound", icon: "building.2", z: 10, enabled: true, category: nil)
        ensure("学校", "school", icon: "graduationcap", z: 20, enabled: true, category: nil)
        ensure("POI", "poi", icon: "mappin", z: 30, enabled: false, category: nil)
        ensure("行政区", "area", icon: "map", z: 1, enabled: true, category: "行政区")
        ensure("路网", "area", icon: "road.lanes", z: 2, enabled: true, category: "道路")

        // 旧「默认」混类型兜底图层在新模型无意义 → 软删。
        if let legacy = byName["默认"] {
            legacy.deleted = true
            legacy.updatedAt = Date()
        }
    }
}
