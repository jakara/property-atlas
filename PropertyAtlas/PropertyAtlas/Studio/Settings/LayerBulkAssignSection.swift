#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 把命中条件(AND)的实体批量移入本图层。条件为瞬态(非持久 @Model)。
struct LayerBulkAssignSection: View {
    @Bindable var layer: Layer
    @Environment(\.modelContext) private var ctx
    @State private var rows: [BulkCond] = []

    var body: some View {
        SettingsCard("按条件赋值") {
            VStack(alignment: .leading, spacing: 10) {
                Text("把命中以下全部条件(AND)的「\(layer.entityType)」实体移入本图层。")
                    .font(Studio.sans(11)).foregroundStyle(Studio.on2)
                ForEach($rows) { $row in
                    BulkConditionRow(row: $row, entityType: layer.entityType, datasetId: layer.datasetId) {
                        rows.removeAll { $0.id == row.id }
                    }
                }
                Button { rows.append(BulkCond()) } label: { Label("加条件", systemImage: "plus") }
                    .buttonStyle(.tbtn(.ghost))
                HStack {
                    Text("命中 \(previewCount) 个").font(Studio.sans(12)).foregroundStyle(Studio.on2)
                    Spacer()
                    Button("赋值到本层") { apply() }
                        .buttonStyle(.tbtn(.primary))
                        .disabled(conditions.isEmpty)
                }
            }
            .padding(.horizontal, 13).padding(.bottom, 12)
        }
    }

    private var conditions: [StyleCondition] {
        rows.compactMap { $0.toCondition() }
    }

    private var previewCount: Int {
        LayerAssign.previewCount(
            entityType: layer.entityType,
            conditions: conditions,
            datasetId: layer.datasetId,
            in: ctx
        )
    }

    private func apply() {
        LayerAssign.bulkAssign(
            entityType: layer.entityType,
            conditions: conditions,
            toLayerId: layer.id,
            datasetId: layer.datasetId,
            in: ctx
        )
    }
}

/// 瞬态条件编辑模型(StyleCondition 是 immutable let,故用此可变结构编辑后转换)。
struct BulkCond: Identifiable {
    let id = UUID()
    var field: String = ""
    var op: StyleConditionOp = .equals
    var value: String = ""

    func toCondition() -> StyleCondition? {
        guard !field.isEmpty else { return nil }
        switch op {
        case .exists:
            return StyleCondition(field: field, op: op, value: .string(""))
        case .inOp:
            let items = value.split(separator: ",").map {
                AnyJSON.string($0.trimmingCharacters(in: .whitespaces))
            }
            return StyleCondition(field: field, op: op, value: .array(items))
        default:
            return StyleCondition(field: field, op: op, value: .string(value))
        }
    }
}

/// 单条瞬态条件行:字段 + op + 值。
struct BulkConditionRow: View {
    @Binding var row: BulkCond
    let entityType: String
    let datasetId: UUID
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context

    private let ops: [StyleConditionOp] = [.equals, .notEquals, .inOp, .contains, .gte, .lte, .exists]

    private var fieldItems: [FieldKeyCatalog.FieldItem] {
        FieldKeyCatalog.fields(entityType: entityType, datasetId: datasetId, context: context)
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $row.field) {
                Text("—").tag("")
                ForEach(fieldItems, id: \.key) { Text($0.label).tag($0.key) }
            }
            .labelsHidden().tint(Studio.cool).lineLimit(1).fixedSize(horizontal: true, vertical: false)

            Picker("", selection: $row.op) {
                ForEach(ops, id: \.self) { Text(opLabel($0)).tag($0) }
            }
            .labelsHidden().tint(Studio.cool).lineLimit(1).fixedSize(horizontal: true, vertical: false)

            if row.op == .inOp {
                TextField("值1,值2", text: $row.value).glassField()
            } else if row.op != .exists {
                TextField("值", text: $row.value).glassField()
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle").font(.system(size: 12))
            }.buttonStyle(.plain)
        }
    }

    private func opLabel(_ kind: StyleConditionOp) -> String {
        switch kind {
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
