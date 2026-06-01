import Foundation

struct PrimaryFilter: Codable, Equatable {
    var conditions: [FilterCondition]
    var groupBy: MapDimension?

    @MainActor
    func matches(_ input: MapDimension.Input) -> Bool {
        for c in conditions where !c.evaluate(input) {
            return false
        }
        return true
    }

    @MainActor
    func groupValues(_ input: MapDimension.Input) -> [String] {
        groupBy?.resolve(input) ?? []
    }
}

struct NormalFilter: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var dimension: MapDimension

    init(id: UUID = UUID(), name: String, dimension: MapDimension) {
        self.id = id
        self.name = name
        self.dimension = dimension
    }
}
