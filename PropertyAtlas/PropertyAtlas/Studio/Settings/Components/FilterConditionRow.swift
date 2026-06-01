#if targetEnvironment(macCatalyst)
import SwiftUI

struct FilterConditionRow: View {
    @Binding var condition: FilterCondition
    let entityType: String
    let datasetId: UUID
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("条件").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash").font(.system(size: 11)) }
                    .buttonStyle(.plain)
            }
            DimensionPicker(dimension: dimBinding, entityType: entityType, datasetId: datasetId)
            Picker("运算", selection: opBinding) {
                ForEach(ops, id: \.self) { Text($0.rawValue).tag($0) }
            }.font(.system(size: 12))
            if condition.op != .exists {
                AnyJSONValueField(value: valueBinding)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private let ops: [StyleConditionOp] = [.equals, .notEquals, .inOp, .contains, .gte, .lte, .exists]
    private var dimBinding: Binding<MapDimension> {
        Binding(get: { condition.dimension }, set: { condition = FilterCondition(dimension: $0, op: condition.op, value: condition.value) })
    }
    private var opBinding: Binding<StyleConditionOp> {
        Binding(get: { condition.op }, set: { condition = FilterCondition(dimension: condition.dimension, op: $0, value: condition.value) })
    }
    private var valueBinding: Binding<AnyJSON> {
        Binding(get: { condition.value }, set: { condition = FilterCondition(dimension: condition.dimension, op: condition.op, value: $0) })
    }
}
#endif
