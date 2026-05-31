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
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldTable
                    RelationTabsView(ref: ref, datasetId: datasetId, onSelectRelated: onSelectRelated)
                }
                .padding(12)
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 720)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(kindChip).font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.gray.opacity(0.2), in: Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(EntityReader.name(ref, in: context) ?? "—")
                    .font(.system(size: 15, weight: .bold))
            }
            Spacer()
            Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(.plain)
            Button(action: onClose) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain)
        }
        .padding(10)
    }

    private var kindChip: String {
        switch ref.kind {
        case .compound: "小区"
        case .school: "学校"
        case .poi: "POI"
        case .area: "片区"
        }
    }

    private var fieldTable: some View {
        let rows: [(String, String)] = EntityFieldSchema.fields(for: ref.kind).compactMap { f in
            guard let v = EntityReader.value(ref, key: f.key, in: context) else { return nil }
            let s = Self.display(v)
            return s.isEmpty ? nil : (f.label, s)
        }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.0) { label, value in
                HStack(alignment: .top, spacing: 6) {
                    Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    Text(value).font(.system(size: 12)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
