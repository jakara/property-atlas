#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit
import SwiftData
import SwiftUI

/// dock 🔍 弹出的玻璃搜索面板。分段「库内 / 外部」。
/// 库内:EntitySearch 实时过滤当前数据集实体。外部:MKLocalSearch async + 0.3s 防抖。
struct StudioSearchPanel: View {
    enum Scope: Hashable { case local, external }

    let datasetId: UUID
    let visibleRegion: MKCoordinateRegion?
    let onPickEntity: (EntityRef, CLLocationCoordinate2D?, Bool) -> Void
    let onPickExternal: (ExternalPlaceSearch.PlaceHit) -> Void
    let onCreateAtExternal: (ExternalPlaceSearch.PlaceHit) -> Void
    let onClose: () -> Void

    @Query private var compounds: [Compound]
    @Query private var schools: [School]
    @Query private var pois: [POI]
    @Query private var areas: [Area]

    @State private var scope: Scope = .local
    @State private var query = ""
    @State private var externalHits: [ExternalPlaceSearch.PlaceHit] = []
    @State private var searching = false
    @State private var externalError: String?

    private struct TaskKey: Equatable { let scope: Scope
        let query: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            GlassSegmented(options: [(Scope.local, "库内"), (Scope.external, "外部")], selection: $scope)
            TextField(scope == .local ? "搜索小区/学校/POI/片区" : "搜索地点(需联网)", text: $query)
                .glassField()
            results
        }
        .padding(16).frame(width: 360)
        .glassSurface(Studio.glassStrong, radius: Studio.rPanel, elevation: .pop)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .task(id: TaskKey(scope: scope, query: query)) { await runExternalIfNeeded() }
    }

    private var header: some View {
        HStack {
            Text("搜索").font(Studio.sans(16, .semibold)).foregroundStyle(Studio.on)
            Spacer()
            Button("关闭", action: onClose).buttonStyle(.tbtn(.ghost))
        }
    }

    private var results: some View {
        ScrollView {
            VStack(spacing: 2) {
                if scope == .local { localRows } else { externalRows }
            }
        }
        .frame(height: 240)
    }

    @ViewBuilder private var localRows: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hits = EntitySearch.search(query, in: searchables())
        if trimmed.isEmpty {
            hint("输入关键词搜索库内地点")
        } else if hits.isEmpty {
            hint("未找到")
        } else {
            ForEach(hits) { hit in
                Button {
                    onPickEntity(hit.ref, hit.hasCoordinate ? hit.coordinate : nil, hit.hasCoordinate)
                } label: {
                    row(title: hit.name, subtitle: hit.subtitle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var externalRows: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let externalError {
            hint(externalError)
        } else if searching {
            hint("搜索中…")
        } else if trimmed.isEmpty {
            hint("输入地点名(需联网)")
        } else if externalHits.isEmpty {
            hint("未找到地点")
        } else {
            ForEach(externalHits) { hit in
                HStack(spacing: 6) {
                    Button { onPickExternal(hit) } label: {
                        row(title: hit.name, subtitle: hit.subtitle)
                    }
                    .buttonStyle(.plain)
                    Button { onCreateAtExternal(hit) } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18)).foregroundStyle(Studio.cool)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                }
            }
        }
    }

    private func runExternalIfNeeded() async {
        guard scope == .external else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        externalError = nil
        guard !trimmed.isEmpty else { externalHits = []
            return
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        searching = true
        defer { searching = false }
        do {
            externalHits = try await ExternalPlaceSearch.search(trimmed, region: visibleRegion)
        } catch {
            if !Task.isCancelled {
                externalError = "外部搜索失败,检查网络后重试"
                externalHits = []
            }
        }
    }

    private func searchables() -> [EntitySearch.Searchable] {
        var out: [EntitySearch.Searchable] = []
        for compound in compounds where compound.datasetId == datasetId && !compound.deleted {
            out.append(.init(
                ref: EntityRef(id: compound.id, kind: .compound), name: compound.name, aliases: compound.aliases,
                address: compound.address, category: nil, coordinate: compound.coordinate,
                hasCoordinate: compound.latitude != 0 || compound.longitude != 0
            ))
        }
        for school in schools where school.datasetId == datasetId && !school.deleted {
            out.append(.init(
                ref: EntityRef(id: school.id, kind: .school), name: school.name, aliases: school.aliases,
                address: school.address, category: school.category, coordinate: school.coordinate,
                hasCoordinate: school.latitude != 0 || school.longitude != 0
            ))
        }
        for poi in pois where poi.datasetId == datasetId && !poi.deleted {
            out.append(.init(
                ref: EntityRef(id: poi.id, kind: .poi), name: poi.name, aliases: poi.aliases,
                address: poi.address, category: poi.category, coordinate: poi.coordinate,
                hasCoordinate: poi.latitude != 0 || poi.longitude != 0
            ))
        }
        for area in areas where area.datasetId == datasetId && !area.deleted {
            out.append(.init(
                ref: EntityRef(id: area.id, kind: .area), name: area.name, aliases: area.aliases,
                address: nil, category: area.category, coordinate: CLLocationCoordinate2D(),
                hasCoordinate: false
            ))
        }
        return out
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(Studio.sans(12)).foregroundStyle(Studio.on3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10).padding(.vertical, 12)
    }

    private func row(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Studio.sans(14)).foregroundStyle(Studio.on).lineLimit(1)
                Text(subtitle).font(Studio.sans(11)).foregroundStyle(Studio.on3).lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10).frame(minHeight: 42).contentShape(Rectangle())
    }
}
#endif
