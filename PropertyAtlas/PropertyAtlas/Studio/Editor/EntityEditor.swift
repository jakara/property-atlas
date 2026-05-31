// PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EntityEditor: View {
    let ref: EntityRef
    let datasetId: UUID
    @Bindable var appState: AppState
    let onClose: () -> Void
    let onDelete: () -> Void
    let onSelectRelated: (EntityRef) -> Void

    @Environment(\.modelContext) private var context
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            ScrollView {
                Group {
                    switch appState.currentEditTab {
                    case .basic: EditorBasicTab(ref: ref, datasetId: datasetId)
                    case .relations: EditorRelationsTab(ref: ref, datasetId: datasetId, onSelectRelated: onSelectRelated)
                    case .media: EditorMediaTab(ref: ref)
                    case .custom: EditorCustomTab(ref: ref, datasetId: datasetId, showPrivate: false)
                    case .privateNotes: EditorCustomTab(ref: ref, datasetId: datasetId, showPrivate: true)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 760)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        .onAppear { name = EntityReader.name(ref, in: context) ?? "" }
        .onChange(of: ref) { _, _ in name = EntityReader.name(ref, in: context) ?? "" }
    }

    private var header: some View {
        HStack(spacing: 8) {
            TextField("名称", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .bold))
                .onSubmit { EntityWriter.setName(ref, name, in: context) }
            Menu {
                Button(role: .destructive) { onDelete() } label: { Label("删除", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle") }
            Button(action: { EntityWriter.setName(ref, name, in: context)
                onClose()
            }) {
                Image(systemName: "checkmark.circle.fill")
            }.buttonStyle(.plain)
        }
        .padding(10)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tab("基本", .basic)
            tab("关联", .relations)
            tab("媒体", .media)
            tab("自定义", .custom)
            tab("私密", .privateNotes)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
    }

    private func tab(_ title: String, _ value: AppState.EditTab) -> some View {
        let active = appState.currentEditTab == value
        return Button { appState.currentEditTab = value } label: {
            Text(title).font(.system(size: 11, weight: active ? .bold : .regular))
                .foregroundStyle(active ? Color.accentColor : .secondary)
        }.buttonStyle(.plain)
    }
}
#endif

#if targetEnvironment(macCatalyst)
struct EditorMediaTab: View { let ref: EntityRef
    var body: some View {
        EmptyView()
    }
}

struct EditorCustomTab: View { let ref: EntityRef
    let datasetId: UUID
    let showPrivate: Bool
    var body: some View {
        EmptyView()
    }
}
#endif
