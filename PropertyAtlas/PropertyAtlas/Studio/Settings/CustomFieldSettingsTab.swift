#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct CustomFieldSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var defs: [CustomFieldDef]
    @State private var entityType: String = "compound"
    @State private var newlyAddedIds: Set<UUID> = []

    private let entityTypes = ["compound", "school", "poi", "area"]
    private let fieldTypes = ["string", "int", "double", "bool", "date", "multiline"]

    private var rows: [CustomFieldDef] {
        defs.filter { $0.datasetId == datasetId && $0.entityType == entityType && !$0.deleted }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("实体", selection: $entityType) {
                ForEach(entityTypes, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).font(.system(size: 12))
            HStack {
                Text("自定义字段").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addDef() } label: { Label("新字段", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(rows, id: \.id) { d in card(d) }
        }
    }

    private func card(_ d: CustomFieldDef) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("标签", text: Binding(get: { d.label }, set: { d.label = $0
                    d.updatedAt = Date()
                })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { d.deleted = true
                    d.updatedAt = Date()
                } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                Text("key").font(.system(size: 11)).foregroundStyle(.secondary)
                if newlyAddedIds.contains(d.id) {
                    TextField("字段标识", text: Binding(get: { d.key }, set: { d.key = $0
                        d.updatedAt = Date()
                    })).font(.system(size: 12).monospaced())
                } else {
                    Text(d.key).font(.system(size: 12).monospaced()).foregroundStyle(.secondary)
                }
            }
            HStack {
                Picker("类型", selection: Binding(get: { d.type }, set: { d.type = $0
                    d.updatedAt = Date()
                })) {
                    ForEach(fieldTypes, id: \.self) { Text($0).tag($0) }
                }.font(.system(size: 12))
                TextField("单位", text: Binding(get: { d.unit ?? "" }, set: { d.unit = $0.isEmpty ? nil : $0
                    d.updatedAt = Date()
                })).font(.system(size: 12)).frame(width: 70)
            }
            Toggle("卡片置顶显示", isOn: Binding(get: { d.pinnedToCard }, set: { d.pinnedToCard = $0
                d.updatedAt = Date()
            })).font(.system(size: 12))
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func addDef() {
        let nextOrder = (rows.map(\.sortOrder).max() ?? 0) + 1
        let key = "field_\(nextOrder)"
        let d = CustomFieldDef(datasetId: datasetId, entityType: entityType, key: key, label: "新字段")
        d.sortOrder = nextOrder
        modelContext.insert(d)
        newlyAddedIds.insert(d.id)
    }
}
#endif
