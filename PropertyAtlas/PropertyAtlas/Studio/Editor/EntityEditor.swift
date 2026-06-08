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
    /// 区域专用:进入多边形重绘(替换原几何)。非区域为 nil。
    var onRedrawPolygon: (() -> Void)?

    @Environment(\.modelContext) private var context
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Studio.glassLine).frame(height: 1)
            tabBar
            Rectangle().fill(Studio.glassLine).frame(height: 1)
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
                .padding(14)
            }
        }
        .frame(width: 340)
        .frame(maxHeight: 760)
        .glassSurface(radius: Studio.rPanel)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { name = EntityReader.name(ref, in: context) ?? "" }
        .onChange(of: ref) { _, _ in name = EntityReader.name(ref, in: context) ?? "" }
    }

    private var badgeKind: EntityBadge.Kind {
        switch ref.kind {
        case .compound: .compound
        case .school: .school
        case .poi: .poi
        case .area: .zone
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                EntityBadge(kind: badgeKind)
                Spacer()
                Menu {
                    if ref.kind == .area, let onRedrawPolygon {
                        Button { onRedrawPolygon() } label: { Label("重绘多边形", systemImage: "pencil.and.outline") }
                    }
                    Button { MacColorPanel.close() } label: { Label("关闭取色器", systemImage: "eyedropper") }
                    Button(role: .destructive) { onDelete() } label: { Label("删除", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Studio.on2).frame(width: 32, height: 32)
                        .background(Studio.glassHover, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
                }.menuStyle(.borderlessButton).fixedSize()
                Button {
                    EntityWriter.setName(ref, name, in: context)
                    onClose()
                } label: { Text("完成") }
                    .buttonStyle(.tbtn(.cool))
            }
            TextField("名称", text: $name)
                .textFieldStyle(.plain)
                .font(Studio.sans(20, .bold))
                .foregroundStyle(Studio.on)
                .onSubmit { EntityWriter.setName(ref, name, in: context) }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tab("基本", .basic)
                tab("关联", .relations)
                tab("媒体", .media)
                tab("自定义", .custom)
                tab("私密", .privateNotes)
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 8)
    }

    private func tab(_ title: String, _ value: AppState.EditTab) -> some View {
        let active = appState.currentEditTab == value
        return Button { appState.currentEditTab = value } label: {
            Text(title).font(Studio.sans(13, .medium))
                .foregroundStyle(active ? Studio.on : Studio.on2)
                .padding(.horizontal, 13).frame(height: 30)
                .background(active ? Studio.glassRaised : Studio.glassHover, in: Capsule())
                .overlay { if active { Capsule().strokeBorder(Studio.glassLine, lineWidth: 1) } }
                .contentShape(Capsule())
        }.buttonStyle(.plain)
    }
}
#endif
