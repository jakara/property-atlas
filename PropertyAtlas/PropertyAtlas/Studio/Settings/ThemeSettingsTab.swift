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
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "主题", trailing: "\(dsThemes.count)")
            ForEach(dsThemes, id: \.id) { t in card(t) }
            AddRow("新主题") { addTheme() }
        }
    }

    private func card(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            headerCard(t)
            rulesCard(t)
            jsonCard(t)
        }
        .padding(.bottom, 4)
    }

    private func headerCard(_ t: Theme) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    TextField("名称", text: Binding(get: { t.name }, set: { t.name = $0
                        t.updatedAt = Date()
                    }))
                    .glassField()
                    Button(role: .destructive) { t.deleted = true
                        t.updatedAt = Date()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 13).padding(.vertical, 11)
                RowDivider()
                SettingsRow(title: "排序") {
                    GlassStepper(value: Binding(get: { t.sortOrder }, set: { t.sortOrder = $0
                        t.updatedAt = Date()
                    }), range: 0...999)
                }
                RowDivider()
                SettingsRow(title: "激活", subtitle: "作为默认渲染主题") {
                    Toggle("", isOn: Binding(get: { t.isActive }, set: { t.isActive = $0
                        t.updatedAt = Date()
                    })).labelsHidden().tint(Studio.cool)
                }
                RowDivider()
                SettingsRow(title: "生成图例", subtitle: "自动按规则汇总") {
                    Toggle("", isOn: Binding(get: { t.showLegend }, set: { t.showLegend = $0
                        t.updatedAt = Date()
                    })).labelsHidden().tint(Studio.cool)
                }
            }
        }
    }

    private func rulesCard(_ t: Theme) -> some View {
        SettingsCard(
            "样式规则（多选）",
            trailing: AnyView(
                Text("已选 \(t.styleRuleIds.count)").font(Studio.sans(11, .medium)).foregroundStyle(Studio.cool)
            )
        ) {
            FlowChips(rules: dsRules, theme: t) { rule in
                toggleRule(t, rule.id)
            }
            .padding(.horizontal, 13).padding(.bottom, 12)
        }
    }

    private func jsonCard(_ t: Theme) -> some View {
        let raw = draft[t.id] ?? t.defaultStylesJSON
        let valid = isValidJSON(raw)
        return SettingsCard("defaultStylesJSON") {
            VStack(alignment: .leading, spacing: 7) {
                TextEditor(text: jsonBinding(t))
                    .font(Studio.mono(12))
                    .foregroundStyle(Studio.on)
                    .scrollContentBackground(.hidden)
                    .frame(height: 80)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                            .strokeBorder(Studio.glassLine, lineWidth: 1)
                    }
                HStack(spacing: 6) {
                    Image(systemName: valid ? "checkmark.circle" : "xmark.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Text(valid ? "JSON 合法" : "无效 JSON,未保存").font(Studio.sans(11))
                }
                .foregroundStyle(valid ? Studio.ok : Studio.bad)
            }
            .padding(.horizontal, 13).padding(.bottom, 13)
        }
    }

    private func toggleRule(_ t: Theme, _ ruleId: UUID) {
        if t.styleRuleIds.contains(ruleId) {
            t.styleRuleIds.removeAll { $0 == ruleId }
        } else {
            t.styleRuleIds.append(ruleId)
        }
        t.updatedAt = Date()
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

/// Wrapping chip group for style-rule multi-select (amber = brand/style).
private struct FlowChips: View {
    let rules: [StyleRule]
    let theme: Theme
    let toggle: (StyleRule) -> Void

    var body: some View {
        let cols = [GridItem(.adaptive(minimum: 96), spacing: 7, alignment: .leading)]
        LazyVGrid(columns: cols, alignment: .leading, spacing: 7) {
            ForEach(rules, id: \.id) { rule in
                StudioChip(
                    rule.name,
                    isOn: theme.styleRuleIds.contains(rule.id),
                    amber: true
                ) { toggle(rule) }
            }
        }
    }
}
#endif
