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

    enum AddResult: Equatable { case added, rejectedSelfLink, skippedDuplicate }

    @discardableResult
    static func add(
        datasetId: UUID,
        from: EntityRef,
        to: EntityRef,
        label: String,
        directed: Bool = false,
        note: String? = nil,
        in context: ModelContext
    ) -> AddResult {
        guard from.id != to.id else { return .rejectedSelfLink }
        let dsId = datasetId
        let fid = from.id, tid = to.id
        let fd = FetchDescriptor<Edge>(predicate: #Predicate {
            $0.datasetId == dsId && !$0.deleted && $0.label == label &&
                (($0.fromId == fid && $0.toId == tid) || ($0.fromId == tid && $0.toId == fid))
        })
        if ((try? context.fetch(fd)) ?? []).isEmpty == false { return .skippedDuplicate }
        context.insert(Edge(
            datasetId: datasetId,
            fromId: from.id,
            fromType: from.typeString,
            toId: to.id,
            toType: to.typeString,
            label: label,
            directed: directed,
            note: note
        ))
        return .added
    }

    static func removeEdge(_ edgeId: UUID, in context: ModelContext) {
        var fd = FetchDescriptor<Edge>(predicate: #Predicate { $0.id == edgeId })
        fd.fetchLimit = 1
        if let e = try? context.fetch(fd).first { e.deleted = true
            e.updatedAt = Date()
        }
    }

    static func cascadeSoftDelete(entityId: UUID, datasetId: UUID, in context: ModelContext) {
        let dsId = datasetId
        let fd = FetchDescriptor<Edge>(predicate: #Predicate {
            $0.datasetId == dsId && !$0.deleted && ($0.fromId == entityId || $0.toId == entityId)
        })
        for e in (try? context.fetch(fd)) ?? [] {
            e.deleted = true
            e.updatedAt = Date()
        }
    }
}
