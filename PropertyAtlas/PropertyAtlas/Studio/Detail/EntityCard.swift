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
                VStack(alignment: .leading, spacing: 18) {
                    infoSection
                    relationSection
                }
                .padding(14)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: 720)
        .glassSurface(Studio.glass, radius: Studio.rPanel, elevation: .float)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                EntityBadge(kind: badgeKind)
                Text(EntityReader.name(ref, in: context) ?? "—")
                    .font(Studio.sans(20, .bold)).foregroundStyle(Studio.on)
                    .fixedSize(horizontal: false, vertical: true)
                if let sub = subtitle {
                    Text(sub).font(Studio.sans(12)).foregroundStyle(Studio.on3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                iconBtn("pencil", action: onEdit)
                iconBtn("xmark", action: onClose).keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 12)
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

    /// Secondary line under the name — derived from an existing category-like
    /// field if present, otherwise omitted gracefully.
    private var subtitle: String? {
        let candidateKeys = ["category", "finishType"]
        for key in candidateKeys {
            guard EntityFieldSchema.fields(for: ref.kind).contains(where: { $0.key == key }),
                  let v = EntityReader.value(ref, key: key, in: context) else { continue }
            let s = Self.display(v)
            if !s.isEmpty { return s }
        }
        return nil
    }

    // MARK: Info

    private var infoSection: some View {
        let rows: [(String, String)] = EntityFieldSchema.fields(for: ref.kind).compactMap { f in
            guard let v = EntityReader.value(ref, key: f.key, in: context) else { return nil }
            let s = Self.display(v)
            return s.isEmpty ? nil : (f.label, s)
        }
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "信息")
            if rows.isEmpty {
                Text("暂无信息").font(Studio.sans(13)).foregroundStyle(Studio.on3)
                    .padding(.horizontal, 13).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, pair in
                        if idx > 0 { RowDivider() }
                        FieldRow(key: pair.0, value: pair.1)
                            .padding(.horizontal, 13)
                    }
                }
                .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
            }
        }
    }

    // MARK: Relations

    private var relationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "关联")
            RelationTabsView(ref: ref, datasetId: datasetId, onSelectRelated: onSelectRelated)
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
