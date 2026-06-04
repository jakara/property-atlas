#if targetEnvironment(macCatalyst)
import SwiftUI

struct StyleConditionRow: View {
    @Binding var condition: StyleCondition
    let onDelete: () -> Void

    private let ops: [StyleConditionOp] = [.equals, .notEquals, .inOp, .contains, .gte, .lte, .exists]

    var body: some View {
        HStack(spacing: 6) {
            TextField("字段", text: fieldBinding)
                .glassField()
                .font(Studio.mono(13))
                .frame(maxWidth: .infinity)

            Picker("", selection: opBinding) {
                ForEach(ops, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .font(Studio.sans(13, .semibold))
            .tint(Studio.cool)
            .fixedSize()

            if condition.op != .exists {
                AnyJSONValueField(value: valueBinding)
                    .glassField()
                    .frame(maxWidth: .infinity)
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Studio.on3)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
        }
    }

    private var fieldBinding: Binding<String> {
        Binding(get: { condition.field }, set: { condition = StyleCondition(field: $0, op: condition.op, value: condition.value) })
    }

    private var opBinding: Binding<StyleConditionOp> {
        Binding(get: { condition.op }, set: { condition = StyleCondition(field: condition.field, op: $0, value: condition.value) })
    }

    private var valueBinding: Binding<AnyJSON> {
        Binding(get: { condition.value }, set: { condition = StyleCondition(field: condition.field, op: condition.op, value: $0) })
    }
}
#endif
