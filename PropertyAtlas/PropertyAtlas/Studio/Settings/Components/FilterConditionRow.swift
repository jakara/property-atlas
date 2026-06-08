#if targetEnvironment(macCatalyst)
import SwiftUI

struct FilterConditionRow: View {
    @Binding var condition: FilterCondition
    let entityType: String
    let datasetId: UUID
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context

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
                if !enumOptions.isEmpty, [.equals, .notEquals, .contains].contains(condition.op) {
                    // 字段是枚举 → 出枚举下拉(单值 op);其余 op(in/范围)仍自由输入
                    Picker("值", selection: enumValueBinding) {
                        Text("—").tag("")
                        ForEach(enumOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .font(Studio.sans(13))
                    .tint(Studio.cool)
                } else {
                    AnyJSONValueField(value: valueBinding)
                }
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

    /// 当前字段的枚举 scope(base 字段经 EntityFieldSchema、custom 经 entityType.key)。
    private var enumScope: String? {
        guard condition.dimension.kind == .field, let fk = condition.dimension.fieldKey else { return nil }
        return FieldKeyCatalog.fields(entityType: entityType, datasetId: datasetId, context: context)
            .first { $0.key == fk }?.enumScope
    }

    private var enumOptions: [String] {
        guard let scope = enumScope else { return [] }
        return FieldKeyCatalog.enumLabels(scope: scope, datasetId: datasetId, context: context)
    }

    private var enumValueBinding: Binding<String> {
        Binding(
            get: { if case let .string(s) = condition.value { return s }
                return ""
            },
            set: { valueBinding.wrappedValue = .string($0) }
        )
    }
}
#endif
