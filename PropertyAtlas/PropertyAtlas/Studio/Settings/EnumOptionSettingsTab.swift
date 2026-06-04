#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EnumOptionSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var options: [EnumOption]
    @State private var scope: String = "edge.label"
    @State private var newScope: String = ""

    private var scopes: [String] {
        let s = Set(options.filter { $0.datasetId == datasetId && !$0.deleted }.map(\.scope))
        return Array(s).sorted()
    }

    private var rows: [EnumOption] {
        options.filter { $0.datasetId == datasetId && $0.scope == scope && !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard("枚举 scope") {
                SettingsRow(title: "范围") {
                    Picker("范围", selection: $scope) {
                        ForEach(scopes, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden().tint(Studio.cool)
                }
                RowDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("新范围").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                    HStack(spacing: 8) {
                        TextField("如 school.category / edge.label", text: $newScope).glassField()
                        Button("用此范围") { if !newScope.isEmpty { scope = newScope
                            newScope = ""
                        } }
                        .buttonStyle(.tbtn(.ghost))
                    }
                }.padding(.horizontal, 13).padding(.bottom, 12)
            }

            SectionLabel(text: "值列表", trailing: "\(rows.count)")
            SettingsCard {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, opt in
                    if idx > 0 { RowDivider() }
                    optionRow(opt)
                }
            }
            AddRow("新增枚举值") { addOption() }
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }

    private func optionRow(_ opt: EnumOption) -> some View {
        HStack(spacing: 8) {
            ColorHexField(title: "色", hex: Binding(get: { opt.colorHex ?? "" }, set: { opt.colorHex = $0.isEmpty ? nil : ColorHexField.normalize($0)
                opt.updatedAt = Date()
            }))
            TextField("值", text: Binding(get: { opt.label }, set: { opt.label = $0
                opt.updatedAt = Date()
            })).glassField()
            Button(role: .destructive) { opt.deleted = true
                opt.updatedAt = Date()
            } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 13).padding(.vertical, 8)
    }

    private func addOption() {
        let s = scope.isEmpty ? "edge.label" : scope
        let o = EnumOption(
            datasetId: datasetId,
            scope: s,
            label: "新值",
            sortOrder: (rows.map(\.sortOrder).max() ?? 0) + 1,
            colorHex: nil
        )
        modelContext.insert(o)
    }
}
#endif
