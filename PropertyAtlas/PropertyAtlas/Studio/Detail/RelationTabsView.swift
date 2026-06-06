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
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(groups) { g in
                            let active = (selectedLabel ?? groups.first?.label) == g.label
                            pill("\(g.label) (\(g.items.count))", active: active) { selectedLabel = g.label }
                        }
                    }
                }
                let shown = groups.first { $0.label == (selectedLabel ?? groups.first?.label) } ?? groups[0]
                VStack(spacing: 2) {
                    ForEach(shown.items) { item in relRow(item) }
                }
            }
        }
    }

    private func pill(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(Studio.sans(13, .medium))
                .foregroundStyle(active ? Studio.on : Studio.on2)
                .padding(.horizontal, 13).frame(height: 30)
                .background(active ? Studio.glassRaised : Studio.glassHover, in: Capsule())
                .overlay {
                    if active { Capsule().strokeBorder(Studio.glassLine, lineWidth: 1) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func relRow(_ item: EdgeStore.RelationItem) -> some View {
        Button { onSelectRelated(item.other) } label: {
            HStack(spacing: 11) {
                Text(EntityReader.name(item.other, in: context) ?? "—")
                    .font(Studio.sans(14, .semibold)).foregroundStyle(Studio.on).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Studio.on3)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
