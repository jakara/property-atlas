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
        VStack(alignment: .leading, spacing: 10) {
            Button { showPicker = true } label: { Label("加关联", systemImage: "plus.circle") }
                .font(.system(size: 12))
            let groups = EdgeStore.relations(of: ref, datasetId: datasetId, in: context)
            ForEach(groups) { g in
                VStack(alignment: .leading, spacing: 4) {
                    Text(g.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(g.items) { item in
                        HStack(spacing: 6) {
                            Button { onSelectRelated(item.other) } label: {
                                Text(EntityReader.name(item.other, in: context) ?? "—").font(.system(size: 12))
                            }.buttonStyle(.plain)
                            Spacer()
                            Button {
                                EdgeStore.removeEdge(item.edgeId, in: context)
                                refreshToken += 1
                            } label: { Image(systemName: "minus.circle").foregroundStyle(.red) }.buttonStyle(.plain)
                        }
                    }
                }
            }
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
        VStack(alignment: .leading, spacing: 10) {
            Text("加关联").font(.headline)
            Picker("类型", selection: $kind) {
                ForEach(EntityKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            TextField("搜索名称", text: $query).textFieldStyle(.roundedBorder)
            labelPicker
            ScrollView {
                ForEach(candidates(), id: \.id) { c in
                    Button {
                        guard !label.isEmpty else { return }
                        onPick(EntityRef(id: c.id, kind: kind), label)
                    } label: {
                        HStack { Text(c.name).font(.system(size: 12))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.vertical, 2)
                }
            }.frame(height: 200)
            HStack { Spacer()
                Button("取消", action: onCancel)
            }
        }
        .padding(16).frame(width: 360)
    }

    private var labelPicker: some View {
        let dsId = datasetId
        let fd = FetchDescriptor<EnumOption>(
            predicate: #Predicate { $0.datasetId == dsId && $0.scope == "edge.label" && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let opts = (try? context.fetch(fd)) ?? []
        return HStack {
            Picker("关系", selection: $label) {
                Text("选关系…").tag("")
                ForEach(opts, id: \.id) { Text($0.label).tag($0.label) }
            }
            TextField("或新建", text: $label).textFieldStyle(.roundedBorder).frame(width: 100)
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
