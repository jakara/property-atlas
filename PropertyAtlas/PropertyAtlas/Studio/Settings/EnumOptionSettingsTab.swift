#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

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
        VStack(alignment: .leading, spacing: 10) {
            Picker("范围", selection: $scope) {
                ForEach(scopes, id: \.self) { Text($0).tag($0) }
            }.font(.system(size: 12))
            HStack {
                TextField("新范围 (如 school.category / edge.label)", text: $newScope).font(.system(size: 12))
                Button("用此范围") { if !newScope.isEmpty { scope = newScope; newScope = "" } }.font(.system(size: 11))
            }
            Divider().opacity(0.4)
            ForEach(rows, id: \.id) { opt in
                HStack {
                    TextField("值", text: Binding(get: { opt.label }, set: { opt.label = $0; opt.updatedAt = Date() })).font(.system(size: 12))
                    ColorHexField(title: "色", hex: Binding(get: { opt.colorHex ?? "" }, set: { opt.colorHex = $0.isEmpty ? nil : ColorHexField.normalize($0); opt.updatedAt = Date() }))
                    Button(role: .destructive) { opt.deleted = true; opt.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
                }
            }
            Button { addOption() } label: { Label("加值", systemImage: "plus") }.font(.system(size: 12))
        }
    }

    private func addOption() {
        let s = scope.isEmpty ? "edge.label" : scope
        let o = EnumOption(datasetId: datasetId, scope: s, label: "新值",
                           sortOrder: (rows.map(\.sortOrder).max() ?? 0) + 1, colorHex: nil)
        modelContext.insert(o)
    }
}
#endif
