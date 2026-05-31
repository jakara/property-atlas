import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ThemeContext {
    private let dataset: Dataset
    private let modelContext: ModelContext

    init(dataset: Dataset, modelContext: ModelContext) {
        self.dataset = dataset
        self.modelContext = modelContext
    }

    var datasetIdValue: UUID {
        dataset.id
    }

    var activeTheme: Theme? {
        guard let id = dataset.activeThemeId else { return nil }
        let descriptor = FetchDescriptor<Theme>(
            predicate: #Predicate { $0.id == id && !$0.deleted }
        )
        return try? modelContext.fetch(descriptor).first
    }

    var allThemes: [Theme] {
        let dsId = dataset.id
        let descriptor = FetchDescriptor<Theme>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func switchTheme(to theme: Theme) {
        dataset.activeThemeId = theme.id
        dataset.updatedAt = Date()
    }
}
