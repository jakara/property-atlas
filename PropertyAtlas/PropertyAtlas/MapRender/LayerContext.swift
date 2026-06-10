import Foundation
import Observation
import SwiftData

/// 图层中心化上下文。持 dataset(全局展示设置源)+ 查询本 dataset 全部图层(enabled 直接读模型)。
@MainActor
@Observable
final class LayerContext {
    let dataset: Dataset
    private let modelContext: ModelContext

    init(dataset: Dataset, modelContext: ModelContext) {
        self.dataset = dataset
        self.modelContext = modelContext
    }

    var datasetIdValue: UUID {
        dataset.id
    }

    var allLayers: [Layer] {
        let dsId = dataset.id
        let fd = FetchDescriptor<Layer>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted },
            sortBy: [SortDescriptor(\.zIndex), SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(fd)) ?? []
    }

    func touch() {
        dataset.updatedAt = Date()
    }
}
