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
            VStack(alignment: .leading, spacing: 12) {
                LockNote("不进 export / 直播")
                VStack(alignment: .leading, spacing: 6) {
                    Text("备注").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                    TextEditor(text: $privateText)
                        .font(Studio.sans(14))
                        .foregroundStyle(Studio.on)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 7).padding(.vertical, 6)
                        .frame(minHeight: 160)
                        .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                                .strokeBorder(Studio.glassLine, lineWidth: 1)
                        }
                        .tint(Studio.cool)
                        .onAppear { privateText = EntityReader.notes(ref, in: context).privateNotes ?? "" }
                        .onChange(of: privateText) { _, v in
                            EntityWriter.setPrivateNotes(ref, v.isEmpty ? nil : v, in: context)
                        }
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
        return VStack(alignment: .leading, spacing: 12) {
            if defs.isEmpty {
                Text("无自定义字段").font(Studio.sans(13)).foregroundStyle(Studio.on2)
            }
            ForEach(defs, id: \.id) { def in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(def.label).font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                        Text(def.key).font(Studio.mono(10)).foregroundStyle(Studio.on3)
                    }
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
            .glassField()
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
