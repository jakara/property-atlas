#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct ThemeSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var themes: [Theme]
    @Query private var styleRules: [StyleRule]
    @State private var draft: [UUID: String] = [:]

    private var dsThemes: [Theme] {
        themes.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var dsRules: [StyleRule] {
        styleRules.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("主题").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addTheme() } label: { Label("新主题", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(dsThemes, id: \.id) { t in card(t) }
        }
    }

    private func card(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { t.name }, set: { t.name = $0
                    t.updatedAt = Date()
                })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { t.deleted = true
                    t.updatedAt = Date()
                } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                Stepper(value: Binding(get: { t.sortOrder }, set: { t.sortOrder = $0
                    t.updatedAt = Date()
                }), in: 0...999) { Text("排序 \(t.sortOrder)").font(.system(size: 12)) }
                Toggle("激活", isOn: Binding(get: { t.isActive }, set: { t.isActive = $0
                    t.updatedAt = Date()
                })).font(.system(size: 12))
                Toggle("图例", isOn: Binding(get: { t.showLegend }, set: { t.showLegend = $0
                    t.updatedAt = Date()
                })).font(.system(size: 12))
            }
            DisclosureGroup("样式规则 (\(t.styleRuleIds.count))") {
                ForEach(dsRules, id: \.id) { rule in
                    Toggle(rule.name, isOn: ruleBinding(t, rule.id)).font(.system(size: 11))
                }
            }.font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("defaultStylesJSON").font(.system(size: 10)).foregroundStyle(.secondary)
                TextEditor(text: jsonBinding(t)).font(.system(size: 11).monospaced()).frame(height: 70).border(.quaternary)
                if !isValidJSON(draft[t.id] ?? t.defaultStylesJSON) {
                    Text("⚠️ 无效 JSON,未保存").font(.system(size: 10)).foregroundStyle(.red)
                }
            }
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func ruleBinding(_ t: Theme, _ ruleId: UUID) -> Binding<Bool> {
        Binding(
            get: { t.styleRuleIds.contains(ruleId) },
            set: { on in
                if on { if !t.styleRuleIds.contains(ruleId) { t.styleRuleIds.append(ruleId) } }
                else { t.styleRuleIds.removeAll { $0 == ruleId } }
                t.updatedAt = Date()
            }
        )
    }

    private func jsonBinding(_ t: Theme) -> Binding<String> {
        Binding(
            get: { draft[t.id] ?? t.defaultStylesJSON },
            set: { s in
                draft[t.id] = s
                if s.isEmpty || isValidJSON(s) { t.defaultStylesJSON = s
                    t.updatedAt = Date()
                }
            }
        )
    }

    private func isValidJSON(_ s: String) -> Bool {
        if s.isEmpty { return true }
        guard let data = s.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private func addTheme() {
        let t = Theme(datasetId: datasetId, name: "新主题")
        t.sortOrder = (dsThemes.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(t)
    }
}
#endif
