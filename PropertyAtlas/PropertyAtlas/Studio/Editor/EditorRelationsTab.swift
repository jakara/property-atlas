// PropertyAtlas/PropertyAtlas/Studio/Editor/EditorRelationsTab.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EditorRelationsTab: View {
    let ref: EntityRef
    let datasetId: UUID
    let onSelectRelated: (EntityRef) -> Void
    @Environment(\.modelContext) private var context
    @State private var showPicker = false
    @State private var refreshToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let groups = EdgeStore.relations(of: ref, datasetId: datasetId, in: context)
            ForEach(groups) { g in
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: g.label, trailing: "\(g.items.count)")
                    ForEach(g.items) { item in
                        relRow(item)
                    }
                }
            }
            AddRow("加关联") { showPicker = true }
        }
        .id(refreshToken)
        .sheet(isPresented: $showPicker) {
            RelationPicker(ref: ref, datasetId: datasetId) { target, label in
                EdgeStore.add(datasetId: datasetId, from: ref, to: target, label: label, in: context)
                refreshToken += 1
                showPicker = false
            } onCancel: { showPicker = false }
        }
    }

    private func relRow(_ item: EdgeStore.RelationItem) -> some View {
        let amber = item.other.kind == .school
        let tint = amber ? Studio.amber : Studio.cool
        let soft = amber ? Studio.amberSoft : Studio.coolSoft
        let sym = switch item.other.kind {
        case .school: "graduationcap"
        case .compound: "building.2"
        case .poi: "mappin"
        case .area: "map"
        }
        return HStack(spacing: 11) {
            Button { onSelectRelated(item.other) } label: {
                HStack(spacing: 11) {
                    Image(systemName: sym).font(.system(size: 16, weight: .regular))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(soft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(EntityReader.name(item.other, in: context) ?? "—")
                            .font(Studio.sans(14, .semibold)).foregroundStyle(Studio.on)
                        Text(item.other.kind.rawValue)
                            .font(Studio.sans(11)).foregroundStyle(Studio.on2)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
            Button {
                EdgeStore.removeEdge(item.edgeId, in: context)
                refreshToken += 1
            } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Studio.on3).frame(width: 28, height: 28)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(minHeight: 52)
        .background(Studio.glassHover.opacity(0.5), in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
    }
}

private struct RelationPicker: View {
    let ref: EntityRef
    let datasetId: UUID
    let onPick: (EntityRef, String) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var context
    @State private var kind: EntityKind = .compound
    @State private var query = ""
    @State private var label = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("加关联").font(Studio.sans(16, .semibold)).foregroundStyle(Studio.on)
                Spacer()
                Button("取消", action: onCancel).buttonStyle(.tbtn(.ghost))
            }
            GlassSegmented(
                options: EntityKind.allCases.map { ($0, $0.rawValue) },
                selection: $kind
            )
            TextField("搜索名称", text: $query).glassField()
            labelPicker
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(candidates(), id: \.id) { c in
                        Button {
                            guard !label.isEmpty else { return }
                            onPick(EntityRef(id: c.id, kind: kind), label)
                        } label: {
                            HStack {
                                Text(c.name).font(Studio.sans(14)).foregroundStyle(Studio.on)
                                Spacer()
                            }
                            .padding(.horizontal, 10).frame(minHeight: 40)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }.frame(height: 200)
        }
        .padding(16).frame(width: 360)
        .glassSurface(Studio.glassStrong, radius: Studio.rPanel, elevation: .pop)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
    }

    private var labelPicker: some View {
        let dsId = datasetId
        let fd = FetchDescriptor<EnumOption>(
            predicate: #Predicate { $0.datasetId == dsId && $0.scope == "edge.label" && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let opts = (try? context.fetch(fd)) ?? []
        return HStack(spacing: 8) {
            Picker("关系", selection: $label) {
                Text("选关系…").tag("")
                ForEach(opts, id: \.id) { Text($0.label).tag($0.label) }
            }
            .tint(Studio.cool)
            TextField("或新建", text: $label).glassField().frame(width: 100)
        }
    }

    private struct Candidate: Identifiable { let id: UUID
        let name: String
    }

    private func candidates() -> [Candidate] {
        let dsId = datasetId
        let q = query
        func map<T: PersistentModel>(_ list: [T], _ name: (T) -> String, _ id: (T) -> UUID) -> [Candidate] {
            list.map { Candidate(id: id($0), name: name($0)) }
                .filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) }
        }
        switch kind {
        case .compound:
            let fd = FetchDescriptor<Compound>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            return map((try? context.fetch(fd)) ?? [], { $0.name }, { $0.id })
        case .school:
            let fd = FetchDescriptor<School>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            return map((try? context.fetch(fd)) ?? [], { $0.name }, { $0.id })
        case .poi:
            let fd = FetchDescriptor<POI>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            return map((try? context.fetch(fd)) ?? [], { $0.name }, { $0.id })
        case .area:
            let fd = FetchDescriptor<Area>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            return map((try? context.fetch(fd)) ?? [], { $0.name }, { $0.id })
        }
    }
}
#endif
