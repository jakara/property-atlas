#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct DimensionPicker: View {
    @Binding var dimension: MapDimension
    let entityType: String
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("维度", selection: kindBinding) {
                ForEach(DimensionKind.allCases, id: \.self) { Text(label(for: $0)).tag($0) }
            }
            .font(Studio.sans(13))
            .tint(Studio.cool)

            switch dimension.kind {
            case .field:
                Picker("字段", selection: fieldKeyBinding) {
                    Text("—").tag("")
                    ForEach(fieldItems, id: \.key) { Text($0.label).tag($0.key) }
                }
                .font(Studio.sans(13))
                .tint(Studio.cool)
            case .edgeField:
                Picker("关系", selection: edgeLabelBinding) {
                    Text("—").tag("")
                    ForEach(edgeLabels, id: \.self) { Text($0).tag($0) }
                }
                .font(Studio.sans(13))
                .tint(Studio.cool)
                Picker("方向", selection: edgeDirBinding) {
                    Text("下游").tag("downstream")
                    Text("上游").tag("upstream")
                    Text("双向").tag("either")
                }
                .font(Studio.sans(13))
                .tint(Studio.cool)
                TextField("对端字段(空=名称)", text: edgeTargetBinding).glassField()
            case .layer, .entityType:
                EmptyView()
            }
        }
    }

    private var fieldItems: [FieldKeyCatalog.FieldItem] {
        FieldKeyCatalog.fields(entityType: entityType, datasetId: datasetId, context: modelContext)
    }

    private var edgeLabels: [String] {
        FieldKeyCatalog.edgeLabels(datasetId: datasetId, context: modelContext)
    }

    private func label(for k: DimensionKind) -> String {
        switch k {
        case .field: "字段"
        case .edgeField: "关系字段"
        case .layer: "图层"
        case .entityType: "实体类型"
        }
    }

    private var kindBinding: Binding<DimensionKind> {
        Binding(
            get: { dimension.kind },
            set: { dimension = MapDimension(kind: $0) }
        )
    }

    private var fieldKeyBinding: Binding<String> {
        Binding(
            get: { dimension.fieldKey ?? "" },
            set: { newKey in
                let src = fieldItems.first { $0.key == newKey }?.source ?? "base"
                dimension = MapDimension(kind: .field, fieldKey: newKey.isEmpty ? nil : newKey, fieldSource: src)
            }
        )
    }

    private var edgeLabelBinding: Binding<String> {
        Binding(
            get: { dimension.edgeLabel ?? "" },
            set: {
                dimension = MapDimension(
                    kind: .edgeField,
                    edgeLabel: $0.isEmpty ? nil : $0,
                    edgeDirection: dimension.edgeDirection ?? "downstream",
                    edgeTargetField: dimension.edgeTargetField
                )
            }
        )
    }

    private var edgeDirBinding: Binding<String> {
        Binding(
            get: { dimension.edgeDirection ?? "downstream" },
            set: {
                dimension = MapDimension(
                    kind: .edgeField,
                    edgeLabel: dimension.edgeLabel,
                    edgeDirection: $0,
                    edgeTargetField: dimension.edgeTargetField
                )
            }
        )
    }

    private var edgeTargetBinding: Binding<String> {
        Binding(
            get: { dimension.edgeTargetField ?? "" },
            set: {
                dimension = MapDimension(
                    kind: .edgeField,
                    edgeLabel: dimension.edgeLabel,
                    edgeDirection: dimension.edgeDirection ?? "downstream",
                    edgeTargetField: $0.isEmpty ? nil : $0
                )
            }
        )
    }
}
#endif
