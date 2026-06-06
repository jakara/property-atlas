#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 某视图某 entityType 的条件规则列表 + 加规则。
struct ViewStyleRulesSection: View {
    let datasetId: UUID
    let viewId: UUID
    let entityType: String
    @Environment(\.modelContext) private var context
    @State private var rules: [ViewStyleRule] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rules, id: \.id) { rule in
                ViewStyleRuleEditor(rule: rule, datasetId: datasetId, onDelete: { deleteRule(rule) })
            }
            Button { addRule() } label: { Label("加条件规则", systemImage: "plus.circle") }
                .buttonStyle(.tbtn(.ghost))
        }
        .onAppear { rules = fetchRules() }
    }

    private func fetchRules() -> [ViewStyleRule] {
        let viewID = viewId
        let entityT = entityType
        return (try? context.fetch(FetchDescriptor<ViewStyleRule>(
            predicate: #Predicate { $0.viewId == viewID && $0.entityType == entityT && !$0.deleted },
            sortBy: [SortDescriptor(\.priority)]
        ))) ?? []
    }

    private func addRule() {
        let rule = ViewStyleRule(datasetId: datasetId, viewId: viewId, entityType: entityType)
        rule.priority = (rules.map(\.priority).max() ?? 0) + 1
        context.insert(rule)
        rules = fetchRules()
    }

    private func deleteRule(_ rule: ViewStyleRule) {
        rule.deleted = true
        rule.updatedAt = Date()
        rules = fetchRules()
    }
}
#endif
