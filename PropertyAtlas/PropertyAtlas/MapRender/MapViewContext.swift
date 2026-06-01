import Foundation
import Observation
import SwiftData

/// 视图驱动上下文(取代 ThemeContext 全局职责)。active MapView + 派生 active theme
/// (启用图层中 zIndex 最高且有 themeId 者,回退 dataset.activeThemeId)+ 解码 primary/normal filter + 可见性 + 切换。
@MainActor
@Observable
final class MapViewContext {
    private let dataset: Dataset
    private let modelContext: ModelContext

    init(dataset: Dataset, modelContext: ModelContext) {
        self.dataset = dataset
        self.modelContext = modelContext
    }

    var datasetIdValue: UUID { dataset.id }

    var allMapViews: [MapView] {
        let dsId = dataset.id
        let fd = FetchDescriptor<MapView>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(fd)) ?? []
    }

    var activeMapView: MapView? {
        let views = allMapViews
        return views.first { $0.isActive } ?? views.first
    }

    func switchView(to view: MapView) {
        for v in allMapViews { v.isActive = (v.id == view.id) }
        dataset.updatedAt = Date()
    }

    var activeTheme: Theme? {
        if let mv = activeMapView {
            let enabled = Set(mv.enabledLayerIds)
            let dsId = dataset.id
            let lf = FetchDescriptor<Layer>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            let layers = ((try? modelContext.fetch(lf)) ?? [])
                .filter { enabled.contains($0.id) }
                .sorted { $0.zIndex > $1.zIndex }
            if let tid = layers.compactMap(\.themeId).first, let t = theme(id: tid) {
                return t
            }
        }
        if let aid = dataset.activeThemeId { return theme(id: aid) }
        return nil
    }

    private func theme(id: UUID) -> Theme? {
        let fd = FetchDescriptor<Theme>(predicate: #Predicate { $0.id == id && !$0.deleted })
        return try? modelContext.fetch(fd).first
    }

    var primaryFilter: PrimaryFilter {
        guard let json = activeMapView?.primaryFilterJSON,
              let pf = try? JSONDecoder().decode(PrimaryFilter.self, from: Data(json.utf8))
        else { return PrimaryFilter(conditions: [], groupBy: nil) }
        return pf
    }

    var normalFilters: [NormalFilter] {
        guard let json = activeMapView?.normalFiltersJSON,
              let nfs = try? JSONDecoder().decode([NormalFilter].self, from: Data(json.utf8))
        else { return [] }
        return nfs
    }

    var visibility: [String: Bool] {
        guard let json = activeMapView?.visibilityJSON,
              let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Bool]
        else { return ["compound": true, "school": true, "poi": true, "area": true] }
        return obj
    }
}
