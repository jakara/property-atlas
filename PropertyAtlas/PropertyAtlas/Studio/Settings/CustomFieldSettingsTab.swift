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
        VStack(alignment: .leading, spacing: 12) {
            GlassSegmented(
                options: entityTypes.map { (value: $0, label: $0) },
                selection: $entityType
            )
            SectionLabel(text: "自定义字段", trailing: "\(rows.count)")
            ForEach(rows, id: \.id) { d in card(d) }
            AddRow("新增自定义字段") { addDef() }
        }
    }

    private func card(_ d: CustomFieldDef) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("标签", text: Binding(get: { d.label }, set: { d.label = $0
                        d.updatedAt = Date()
                    }))
                    .glassField()
                    Button(role: .destructive) { d.deleted = true
                        d.updatedAt = Date()
                    } label: {
                        Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    Text("key").font(Studio.sans(11)).foregroundStyle(Studio.on2)
                    if newlyAddedIds.contains(d.id) {
                        TextField("字段标识", text: Binding(get: { d.key }, set: { d.key = $0
                            d.updatedAt = Date()
                        }))
                        .glassField()
                        .font(Studio.mono(13))
                    } else {
                        Text(d.key).font(Studio.mono(13)).foregroundStyle(Studio.on3)
                        Spacer()
                    }
                }
                HStack(spacing: 10) {
                    Picker("类型", selection: Binding(get: { d.type }, set: { d.type = $0
                        d.updatedAt = Date()
                    })) {
                        ForEach(fieldTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .font(Studio.sans(12)).tint(Studio.cool)
                    TextField("单位", text: Binding(get: { d.unit ?? "" }, set: { d.unit = $0.isEmpty ? nil : $0
                        d.updatedAt = Date()
                    }))
                    .glassField()
                    .frame(width: 86)
                }
                Toggle("卡片置顶显示", isOn: Binding(get: { d.pinnedToCard }, set: { d.pinnedToCard = $0
                    d.updatedAt = Date()
                }))
                .font(Studio.sans(13)).foregroundStyle(Studio.on).tint(Studio.cool)
            }
            .padding(.horizontal, 13).padding(.vertical, 12)
        }
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
