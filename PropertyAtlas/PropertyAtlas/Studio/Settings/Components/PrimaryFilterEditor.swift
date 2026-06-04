#if targetEnvironment(macCatalyst)
import SwiftUI

struct PrimaryFilterEditor: View {
    @Binding var filter: PrimaryFilter
    let entityType: String
    let datasetId: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("主过滤(分组 + 条件)")
                .font(Studio.sans(13, .semibold))
                .foregroundStyle(Studio.on)
            // groupBy row
            Toggle("启用分组染色 (groupBy)", isOn: groupByEnabled)
                .font(Studio.sans(13))
                .foregroundStyle(Studio.on)
                .tint(Studio.cool)
            if filter.groupBy != nil {
                DimensionPicker(dimension: groupByBinding, entityType: entityType, datasetId: datasetId)
                    .padding(.leading, 8)
            }
            Rectangle().fill(Studio.glassLine).frame(height: 1)
            Text("条件 (AND)")
                .font(Studio.sans(10, .semibold))
                .textCase(.uppercase)
                .foregroundStyle(Studio.on3)
            ForEach(filter.conditions.indices, id: \.self) { i in
                FilterConditionRow(
                    condition: conditionBinding(i),
                    entityType: entityType,
                    datasetId: datasetId,
                    onDelete: { filter.conditions.remove(at: i) }
                )
            }
            AddRow("加条件") {
                filter.conditions.append(FilterCondition(dimension: MapDimension(kind: .field), op: .equals, value: .string("")))
            }
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
