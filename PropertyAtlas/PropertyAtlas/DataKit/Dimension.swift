import Foundation
import SwiftData

enum DimensionKind: String, Codable, CaseIterable {
    case layer, entityType, field, edgeField
}

struct Dimension: Codable, Hashable {
    var kind: DimensionKind
    var fieldKey: String?
    var fieldSource: String?
    var edgeLabel: String?
    var edgeDirection: String?
    var edgeTargetField: String?

    init(
        kind: DimensionKind,
        fieldKey: String? = nil,
        fieldSource: String? = nil,
        edgeLabel: String? = nil,
        edgeDirection: String? = nil,
        edgeTargetField: String? = nil
    ) {
        self.kind = kind
        self.fieldKey = fieldKey
        self.fieldSource = fieldSource
        self.edgeLabel = edgeLabel
        self.edgeDirection = edgeDirection
        self.edgeTargetField = edgeTargetField
    }

    var key: String {
        switch kind {
        case .layer: "layer"
        case .entityType: "entityType"
        case .field: "field:\(fieldKey ?? "")"
        case .edgeField: "edge:\(edgeLabel ?? ""):\(edgeDirection ?? "downstream"):\(edgeTargetField ?? "name")"
        }
    }

    struct Input {
        let entity: StyleEntity
        let layerNames: [String]
        let context: ModelContext?
        let datasetId: UUID?
    }

    @MainActor
    func resolve(_ input: Input) -> [String] {
        switch kind {
        case .layer:
            return input.layerNames.filter { !$0.isEmpty }
        case .entityType:
            return [input.entity.entityType]
        case .field:
            guard let fk = fieldKey else { return [] }
            let s = FilterPredicate.display(input.entity.field(fk))
            return s.isEmpty ? [] : [s]
        case .edgeField:
            guard let label = edgeLabel, let ctx = input.context, let dsId = input.datasetId,
                  let entKind = EntityKind(rawValue: input.entity.entityType) else { return [] }
            let dir: EdgeDirection = switch edgeDirection {
            case "upstream": .upstream
            case "either": .either
            default: .downstream
            }
            return EdgeStore.relatedFieldValues(
                of: EntityRef(id: input.entity.id, kind: entKind),
                edgeLabel: label, direction: dir, targetField: edgeTargetField,
                datasetId: dsId, in: ctx
            )
        }
    }
}
