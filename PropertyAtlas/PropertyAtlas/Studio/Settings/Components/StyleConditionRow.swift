#if targetEnvironment(macCatalyst)
import SwiftUI

struct StyleConditionRow: View {
    @Binding var condition: StyleCondition
    let onDelete: () -> Void

    private let ops: [StyleConditionOp] = [.equals, .notEquals, .inOp, .contains, .gte, .lte, .exists]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("字段 key", text: fieldBinding).font(.system(size: 12).monospaced())
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            Picker("运算", selection: opBinding) {
                ForEach(ops, id: \.self) { Text($0.rawValue).tag($0) }
            }.font(.system(size: 12))
            if condition.op != .exists {
                AnyJSONValueField(value: valueBinding)
            }
        }
        .padding(8).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
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
