#if targetEnvironment(macCatalyst)
import SwiftUI

struct PrimaryFilterEditor: View {
    @Binding var filter: PrimaryFilter
    let entityType: String
    let datasetId: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("主过滤(分组 + 条件)").font(.system(size: 12, weight: .bold))
            Toggle("启用分组染色 (groupBy)", isOn: groupByEnabled).font(.system(size: 12))
            if filter.groupBy != nil {
                DimensionPicker(dimension: groupByBinding, entityType: entityType, datasetId: datasetId)
                    .padding(.leading, 8)
            }
            Divider().opacity(0.4)
            Text("条件 (AND)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(filter.conditions.indices, id: \.self) { i in
                FilterConditionRow(condition: conditionBinding(i), entityType: entityType, datasetId: datasetId,
                                   onDelete: { filter.conditions.remove(at: i) })
            }
            Button { filter.conditions.append(FilterCondition(dimension: MapDimension(kind: .field), op: .equals, value: .string(""))) }
                label: { Label("加条件", systemImage: "plus") }.font(.system(size: 12))
        }
    }

    private var groupByEnabled: Binding<Bool> {
        Binding(get: { filter.groupBy != nil }, set: { filter.groupBy = $0 ? MapDimension(kind: .field) : nil })
    }
    private var groupByBinding: Binding<MapDimension> {
        Binding(get: { filter.groupBy ?? MapDimension(kind: .field) }, set: { filter.groupBy = $0 })
    }
    private func conditionBinding(_ i: Int) -> Binding<FilterCondition> {
        Binding(get: { filter.conditions[i] }, set: { filter.conditions[i] = $0 })
    }
}
#endif
