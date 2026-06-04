#if targetEnvironment(macCatalyst)
import SwiftUI

struct FilterConditionRow: View {
    @Binding var condition: FilterCondition
    let entityType: String
    let datasetId: UUID
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("条件")
                    .font(Studio.sans(10, .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Studio.on3)
                Spacer()
                // trailing delete x — `.cond .x` (28pt, bad on hover)
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Studio.on3)
                        .frame(width: 28, height: 28)
                        .background(Studio.glassHover, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .tint(Studio.bad)
            }
            DimensionPicker(dimension: dimBinding, entityType: entityType, datasetId: datasetId)
            // `.cond .mini.op` — cool semibold
            Picker("运算", selection: opBinding) {
                ForEach(ops, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .font(Studio.sans(13, .semibold))
            .tint(Studio.cool)
            if condition.op != .exists {
                AnyJSONValueField(value: valueBinding)
            }
        }
        .padding(10)
        .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous)
                .strokeBorder(Studio.glassLine, lineWidth: 1)
        }
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
