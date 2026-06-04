// PropertyAtlas/PropertyAtlas/Studio/Detail/EntityCard.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EntityCard: View {
    let ref: EntityRef
    let datasetId: UUID
    let onEdit: () -> Void
    let onClose: () -> Void
    let onSelectRelated: (EntityRef) -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(Studio.glassLine).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldTable
                    RelationTabsView(ref: ref, datasetId: datasetId, onSelectRelated: onSelectRelated)
                }
                .padding(14)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: 320)
        .frame(maxHeight: 720)
        .glassSurface(Studio.glass, radius: Studio.rPanel, elevation: .float)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                EntityBadge(kind: badgeKind)
                Spacer()
                iconBtn("pencil", action: onEdit)
                iconBtn("xmark", action: onClose)
            }
            Text(EntityReader.name(ref, in: context) ?? "—")
                .font(.system(size: 20, weight: .bold)).foregroundStyle(Studio.on)
                .padding(.top, 10)
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 10)
    }

    private func iconBtn(_ sym: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: sym).font(.system(size: 14, weight: .medium))
                .foregroundStyle(Studio.on2).frame(width: 32, height: 32)
                .background(Studio.glassHover, in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var badgeKind: EntityBadge.Kind {
        switch ref.kind {
        case .compound: .compound
        case .school: .school
        case .poi: .poi
        case .area: .zone
        }
    }

    private var fieldTable: some View {
        let rows: [(String, String)] = EntityFieldSchema.fields(for: ref.kind).compactMap { f in
            guard let v = EntityReader.value(ref, key: f.key, in: context) else { return nil }
            let s = Self.display(v)
            return s.isEmpty ? nil : (f.label, s)
        }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, pair in
                if idx > 0 { Rectangle().fill(Studio.glassLine).frame(height: 1) }
                FieldRow(key: pair.0, value: pair.1)
            }
        }
    }

    static func display(_ v: AnyJSON) -> String {
        switch v {
        case let .string(s): s
        case let .int(i): String(i)
        case let .double(d): String(d)
        case let .bool(b): b ? "是" : "否"
        default: ""
        }
    }
}
#endif
