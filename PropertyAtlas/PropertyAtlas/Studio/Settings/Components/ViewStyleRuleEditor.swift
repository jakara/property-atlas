#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 单条 ViewStyleRule 编辑:条件列表(AND)+ 样式属性 + enabled/priority/删除。
struct ViewStyleRuleEditor: View {
    @Bindable var rule: ViewStyleRule
    let datasetId: UUID
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context
    @State private var conditions: [ViewStyleCondition] = []

    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    var body: some View {
        StudioDisclosure("规则", summary: summaryText, open: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("条件(全部满足)").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                ForEach(conditions, id: \.id) { condition in
                    StyleConditionRow(
                        condition: condition, entityType: rule.entityType, datasetId: datasetId,
                        onDelete: { deleteCondition(condition) }
                    )
                }
                Button { addCondition() } label: { Label("加条件", systemImage: "plus") }
                    .buttonStyle(.tbtn(.ghost))
            }
            Divider().overlay(Studio.on2.opacity(0.2))
            if rule.entityType != "area" {
                shapePicker
            }
            ColorHexField(title: "填充色", hex: hexBinding(\.fillHex))
            ColorHexField(title: "描边色", hex: hexBinding(\.strokeHex))
            TextField("字符 / 图标", text: Binding(
                get: { rule.glyph ?? "" },
                set: { rule.glyph = $0.isEmpty ? nil : String($0.prefix(2))
                    rule.updatedAt = Date()
                }
            )).glassField().font(Studio.mono(13))
            Toggle("显示标签", isOn: Binding(
                get: { rule.labelVisible ?? false },
                set: { rule.labelVisible = $0
                    rule.updatedAt = Date()
                }
            ))
            HStack {
                Toggle("启用", isOn: Binding(
                    get: { rule.enabled },
                    set: { rule.enabled = $0
                        rule.updatedAt = Date()
                    }
                ))
                Spacer()
                Stepper("优先级 \(rule.priority)", value: Binding(
                    get: { rule.priority },
                    set: { rule.priority = $0
                        rule.updatedAt = Date()
                    }
                ), in: 0...999)
            }
            Button(role: .destructive, action: onDelete) {
                Label("删除规则", systemImage: "trash")
            }.buttonStyle(.tbtn(.dangerGhost))
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { conditions = fetchConditions() }
    }

    private var summaryText: String {
        conditions.isEmpty ? "无条件" : conditions.map(\.field).joined(separator: "+")
    }

    private var shapePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("形状").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(shapes, id: \.self) { shape in
                        StudioChip(shape, isOn: rule.shape == shape) {
                            rule.shape = (rule.shape == shape) ? nil : shape
                            rule.updatedAt = Date()
                        }
                    }
                }
            }
        }
    }

    private func hexBinding(_ keyPath: ReferenceWritableKeyPath<ViewStyleRule, String?>) -> Binding<String> {
        Binding(
            get: { rule[keyPath: keyPath] ?? "" },
            set: { rule[keyPath: keyPath] = $0.isEmpty ? nil : $0
                rule.updatedAt = Date()
            }
        )
    }

    private func fetchConditions() -> [ViewStyleCondition] {
        let ruleId = rule.id
        return (try? context.fetch(FetchDescriptor<ViewStyleCondition>(
            predicate: #Predicate { $0.ruleId == ruleId && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []
    }

    private func addCondition() {
        let condition = ViewStyleCondition(ruleId: rule.id, field: "", op: "equals")
        condition.sortOrder = conditions.count
        context.insert(condition)
        rule.updatedAt = Date()
        conditions = fetchConditions()
    }

    private func deleteCondition(_ condition: ViewStyleCondition) {
        condition.deleted = true
        condition.updatedAt = Date()
        rule.updatedAt = Date()
        conditions = fetchConditions()
    }
}
#endif
