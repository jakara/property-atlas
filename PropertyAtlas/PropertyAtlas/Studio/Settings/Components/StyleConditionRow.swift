#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 单条 ViewStyleCondition 编辑:字段 + op + 值。
struct StyleConditionRow: View {
    @Bindable var condition: ViewStyleCondition
    let entityType: String
    let datasetId: UUID
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context

    private let ops: [StyleConditionOp] = [.equals, .notEquals, .inOp, .contains, .gte, .lte, .exists]

    private var fieldItems: [FieldKeyCatalog.FieldItem] {
        FieldKeyCatalog.fields(entityType: entityType, datasetId: datasetId, context: context)
    }

    private var currentOp: StyleConditionOp {
        StyleConditionOp(rawValue: condition.op) ?? .equals
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { condition.field },
                set: { condition.field = $0
                    condition.updatedAt = Date()
                }
            )) {
                Text("—").tag("")
                ForEach(fieldItems, id: \.key) { Text($0.label).tag($0.key) }
            }
            .labelsHidden().tint(Studio.cool).lineLimit(1).fixedSize(horizontal: true, vertical: false)

            Picker("", selection: Binding(
                get: { condition.op },
                set: { condition.op = $0
                    condition.updatedAt = Date()
                }
            )) {
                ForEach(ops, id: \.rawValue) { Text(opLabel($0)).tag($0.rawValue) }
            }
            .labelsHidden().tint(Studio.cool).lineLimit(1).fixedSize(horizontal: true, vertical: false)

            if currentOp == .inOp {
                TextField("值1,值2", text: Binding(
                    get: { condition.valueList.joined(separator: ",") },
                    set: {
                        condition.valueList = $0.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                        condition.updatedAt = Date()
                    }
                )).glassField()
            } else if currentOp != .exists {
                TextField("值", text: Binding(
                    get: { condition.valueString ?? "" },
                    set: { condition.valueString = $0.isEmpty ? nil : $0
                        condition.updatedAt = Date()
                    }
                )).glassField()
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle").font(.system(size: 12))
            }.buttonStyle(.plain)
        }
    }

    private func opLabel(_ op: StyleConditionOp) -> String {
        switch op {
        case .equals: "等于"
        case .notEquals: "不等于"
        case .inOp: "属于"
        case .contains: "包含"
        case .gte: "≥"
        case .lte: "≤"
        case .exists: "存在"
        }
    }
}
#endif
