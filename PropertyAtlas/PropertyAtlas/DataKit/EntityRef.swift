// PropertyAtlas/PropertyAtlas/DataKit/EntityRef.swift
import Foundation

enum EntityKind: String, CaseIterable, Codable, Hashable {
    case compound, school, poi, area
}

struct EntityRef: Hashable, Identifiable {
    let id: UUID
    let kind: EntityKind

    var typeString: String {
        kind.rawValue
    }
}
