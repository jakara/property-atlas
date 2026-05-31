// PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift
import Foundation
import SwiftData

@MainActor
enum EdgeStore {
    struct RelationItem: Identifiable {
        let edgeId: UUID
        let other: EntityRef
        let note: String?
        var id: UUID {
            edgeId
        }
    }

    struct RelationGroup: Identifiable {
        let label: String
        let items: [RelationItem]
        var id: String {
            label
        }
    }

    /// 与 ref 相连的所有未删 Edge，按 label 分组（空 label 组剔除），组内按 sortOrder。
    static func relations(of ref: EntityRef, datasetId: UUID, in context: ModelContext) -> [RelationGroup] {
        let id = ref.id
        let dsId = datasetId
        let fd = FetchDescriptor<Edge>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted && ($0.fromId == id || $0.toId == id) },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let edges = (try? context.fetch(fd)) ?? []
        var byLabel: [String: [RelationItem]] = [:]
        var order: [String] = []
        for e in edges where !e.label.isEmpty {
            let other: EntityRef
            if e.fromId == id {
                guard let k = EntityKind(rawValue: e.toType) else { continue }
                other = EntityRef(id: e.toId, kind: k)
            } else {
                guard let k = EntityKind(rawValue: e.fromType) else { continue }
                other = EntityRef(id: e.fromId, kind: k)
            }
            if byLabel[e.label] == nil { byLabel[e.label] = []
                order.append(e.label)
            }
            byLabel[e.label]?.append(RelationItem(edgeId: e.id, other: other, note: e.note))
        }
        return order.map { RelationGroup(label: $0, items: byLabel[$0] ?? []) }
    }
}
