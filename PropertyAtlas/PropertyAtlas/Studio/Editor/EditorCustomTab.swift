// PropertyAtlas/PropertyAtlas/Studio/Editor/EditorCustomTab.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EditorCustomTab: View {
    let ref: EntityRef
    let datasetId: UUID
    let showPrivate: Bool
    @Environment(\.modelContext) private var context
    @State private var privateText = ""

    var body: some View {
        if showPrivate {
            VStack(alignment: .leading, spacing: 6) {
                Label("私密备注（不进 export / 直播）", systemImage: "lock.fill")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                TextEditor(text: $privateText)
                    .font(.system(size: 12)).frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.gray.opacity(0.3)))
                    .onAppear { privateText = EntityReader.notes(ref, in: context).privateNotes ?? "" }
                    .onChange(of: privateText) { _, v in
                        EntityWriter.setPrivateNotes(ref, v.isEmpty ? nil : v, in: context)
                    }
            }
        } else {
            customFields
        }
    }

    private var customFields: some View {
        let dsId = datasetId
        let etype = ref.typeString
        let fd = FetchDescriptor<CustomFieldDef>(
            predicate: #Predicate { $0.datasetId == dsId && $0.entityType == etype && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let defs = (try? context.fetch(fd)) ?? []
        return VStack(alignment: .leading, spacing: 10) {
            if defs.isEmpty {
                Text("无自定义字段").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(defs, id: \.id) { def in
                HStack(alignment: .top, spacing: 6) {
                    Text(def.label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    CustomStringEditor(ref: ref, key: def.key)
                }
            }
        }
    }
}

private struct CustomStringEditor: View {
    let ref: EntityRef
    let key: String
    @Environment(\.modelContext) private var context
    @State private var text = ""

    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 12)).textFieldStyle(.roundedBorder)
            .onAppear { if case let .string(v) = EntityReader.value(ref, key: key, in: context) { text = v } }
            .onSubmit { write() }
    }

    private func write() {
        var dict: [String: AnyJSON] = EntityReader.customFieldsJSON(ref, in: context)
            .flatMap { try? JSONHelpers.decode($0) } ?? [:]
        dict[key] = text.isEmpty ? .null : .string(text)
        EntityWriter.setCustomFieldsJSON(ref, try? JSONHelpers.encode(dict), in: context)
    }
}
#endif
