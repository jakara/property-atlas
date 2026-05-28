// PropertyAtlas/PropertyAtlasTests/Helpers/TestContainer.swift
import Foundation
import SwiftData
@testable import PropertyAtlas

enum TestContainer {
    /// In-memory ModelContainer for unit tests. Pass the @Model types under test.
    static func makeInMemory(for types: [any PersistentModel.Type]) throws -> ModelContainer {
        let schema = Schema(types)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
