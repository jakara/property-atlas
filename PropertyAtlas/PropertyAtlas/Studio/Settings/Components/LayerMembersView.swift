#if targetEnvironment(macCatalyst)
import CoreLocation
import SwiftData
import SwiftUI

/// 图层成员浏览:类型子tab(小区/学校/POI/区域)+ 搜索框 + 列表,限定本图层本类型。
/// 复用 `EntitySearch`(库内搜索纯逻辑);空 query 列全部,非空走搜索。
/// 行点击 → onSelect(详情),行尾铅笔 → onEdit(编辑);均带坐标供 flyTo。
struct LayerMembersView: View {
    let layerId: UUID
    let datasetId: UUID
    let onSelect: (EntityRef, CLLocationCoordinate2D?, Bool) -> Void
    let onEdit: (EntityRef, CLLocationCoordinate2D?, Bool) -> Void
    @Environment(\.modelContext) private var context
    @AppStorage("layerMembersKind") private var kindRaw: String = EntityKind.compound.rawValue
    private var kind: EntityKind {
        EntityKind(rawValue: kindRaw) ?? .compound
    }

    private var kindBinding: Binding<EntityKind> {
        Binding(get: { kind }, set: { kindRaw = $0.rawValue })
    }

    @AppStorage("layerMembersScrollId") private var scrollIdRaw: String = ""
    @State private var scrollId: UUID?
    @State private var query = ""

    private let kinds: [(value: EntityKind, label: String)] = [
        (.compound, "小区"), (.school, "学校"), (.poi, "POI"), (.area, "区域"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassSegmented(options: kinds, selection: kindBinding)
            TextField("搜索\(label)", text: $query).glassField()
            list
        }
        .onAppear { scrollId = UUID(uuidString: scrollIdRaw) }
        .onChange(of: scrollId) { _, newValue in
            scrollIdRaw = newValue?.uuidString ?? ""
        }
    }

    private var label: String {
        kinds.first { $0.value == kind }?.label ?? ""
    }

    @ViewBuilder private var list: some View {
        let hits = filtered(searchables(kind))
        if hits.isEmpty {
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "无成员" : "未找到")
                .font(Studio.sans(12)).foregroundStyle(Studio.on3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(hits.enumerated()), id: \.element.id) { idx, hit in
                        if idx > 0 { RowDivider() }
                        row(hit)
                            .id(hit.id)
                    }
                }
                .scrollTargetLayout()
            }
            .frame(maxHeight: 300)
            .scrollPosition(id: $scrollId)
            .background(Studio.glassInput, in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
        }
    }

    private func row(_ hit: EntitySearch.Hit) -> some View {
        HStack(spacing: 8) {
            Text(hit.name.isEmpty ? "未命名" : hit.name)
                .font(Studio.sans(13))
                .foregroundStyle(hit.name.isEmpty ? Studio.on3 : Studio.on)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { onEdit(hit.ref, hit.hasCoordinate ? hit.coordinate : nil, hit.hasCoordinate) } label: {
                Image(systemName: "pencil").font(.system(size: 13)).foregroundStyle(Studio.cool)
            }.buttonStyle(.plain)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Studio.on3)
        }
        .padding(.horizontal, 12).frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(hit.ref, hit.hasCoordinate ? hit.coordinate : nil, hit.hasCoordinate) }
    }

    /// 空 query → 列全部(按名排序);非空 → 复用 EntitySearch。
    private func filtered(_ items: [EntitySearch.Searchable]) -> [EntitySearch.Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return items
                .map { EntitySearch.Hit(
                    ref: $0.ref, name: $0.name, subtitle: "",
                    coordinate: $0.coordinate, hasCoordinate: $0.hasCoordinate
                ) }
                .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
        return EntitySearch.search(query, in: items)
    }

    // MARK: - Scoped searchables (concrete per kind)

    private func searchables(_ kind: EntityKind) -> [EntitySearch.Searchable] {
        switch kind {
        case .compound: compoundSearchables()
        case .school: schoolSearchables()
        case .poi: poiSearchables()
        case .area: areaSearchables()
        }
    }

    private func compoundSearchables() -> [EntitySearch.Searchable] {
        let dataset = datasetId
        let layer: UUID? = layerId
        let rows = (try? context.fetch(FetchDescriptor<Compound>(
            predicate: #Predicate { $0.datasetId == dataset && $0.layerId == layer && !$0.deleted }
        ))) ?? []
        return rows.map {
            .init(
                ref: EntityRef(id: $0.id, kind: .compound), name: $0.name, aliases: $0.aliases,
                address: $0.address, category: nil, coordinate: $0.coordinate,
                hasCoordinate: $0.latitude != 0 || $0.longitude != 0
            )
        }
    }

    private func schoolSearchables() -> [EntitySearch.Searchable] {
        let dataset = datasetId
        let layer: UUID? = layerId
        let rows = (try? context.fetch(FetchDescriptor<School>(
            predicate: #Predicate { $0.datasetId == dataset && $0.layerId == layer && !$0.deleted }
        ))) ?? []
        return rows.map {
            .init(
                ref: EntityRef(id: $0.id, kind: .school), name: $0.name, aliases: $0.aliases,
                address: $0.address, category: $0.category, coordinate: $0.coordinate,
                hasCoordinate: $0.latitude != 0 || $0.longitude != 0
            )
        }
    }

    private func poiSearchables() -> [EntitySearch.Searchable] {
        let dataset = datasetId
        let layer: UUID? = layerId
        let rows = (try? context.fetch(FetchDescriptor<POI>(
            predicate: #Predicate { $0.datasetId == dataset && $0.layerId == layer && !$0.deleted }
        ))) ?? []
        return rows.map {
            .init(
                ref: EntityRef(id: $0.id, kind: .poi), name: $0.name, aliases: $0.aliases,
                address: $0.address, category: $0.category, coordinate: $0.coordinate,
                hasCoordinate: $0.latitude != 0 || $0.longitude != 0
            )
        }
    }

    private func areaSearchables() -> [EntitySearch.Searchable] {
        let dataset = datasetId
        let layer: UUID? = layerId
        let rows = (try? context.fetch(FetchDescriptor<Area>(
            predicate: #Predicate { $0.datasetId == dataset && $0.layerId == layer && !$0.deleted }
        ))) ?? []
        return rows.map {
            .init(
                ref: EntityRef(id: $0.id, kind: .area), name: $0.name, aliases: $0.aliases,
                address: nil, category: $0.category, coordinate: CLLocationCoordinate2D(),
                hasCoordinate: false
            )
        }
    }
}
#endif
