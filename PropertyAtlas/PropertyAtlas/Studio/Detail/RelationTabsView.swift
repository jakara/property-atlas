// PropertyAtlas/PropertyAtlas/Studio/Detail/RelationTabsView.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct RelationTabsView: View {
    let ref: EntityRef
    let datasetId: UUID
    let onSelectRelated: (EntityRef) -> Void

    @Environment(\.modelContext) private var context
    @State private var selectedLabel: String?

    var body: some View {
        let groups = EdgeStore.relations(of: ref, datasetId: datasetId, in: context)
        if groups.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(groups) { g in
                            let active = (selectedLabel ?? groups.first?.label) == g.label
                            Button {
                                selectedLabel = g.label
                            } label: {
                                Text("\(g.label) (\(g.items.count))").font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(active ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.12), in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                let shown = groups.first { $0.label == (selectedLabel ?? groups.first?.label) } ?? groups[0]
                ForEach(shown.items) { item in
                    Button { onSelectRelated(item.other) } label: {
                        HStack(spacing: 6) {
                            Text(EntityReader.name(item.other, in: context) ?? "—")
                                .font(.system(size: 12))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
#endif
