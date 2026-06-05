# Studio 搜索入口 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Studio Mode 加搜索入口:库内实体搜索(飞相机+选中)+ 外部 Apple 地点搜索(飞相机+临时标记+一键建 POI)。

**Architecture:** dock 🔍 按钮(⌘F)→ 玻璃浮层 `StudioSearchPanel`(分段「库内/外部」)。库内走纯逻辑 `EntitySearch`(单测);外部走 `ExternalPlaceSearch`(MKLocalSearch async + 防抖)。面板回调由 `RootView` 接:飞相机(设 `camera` @State)、`appState.select`、临时标记 `SearchMarker`(注入 annotations)、建实体复用增强后的 `CreateEntitySheet`。

**Tech Stack:** SwiftUI · MapKit(MKLocalSearch)· SwiftData(@Query)· Swift Testing · Mac Catalyst only(全 `#if targetEnvironment(macCatalyst)`)。

**Spec:** `docs/superpowers/specs/2026-06-05-studio-search-entry-design.md`

---

## 文件结构

新建:
- `PropertyAtlas/PropertyAtlas/MapRender/EntitySearch.swift` — 库内匹配纯逻辑(Task 1)
- `PropertyAtlas/PropertyAtlas/Studio/Search/ExternalPlaceSearch.swift` — MKLocalSearch 包装(Task 2)
- `PropertyAtlas/PropertyAtlas/Studio/Search/StudioSearchPanel.swift` — 面板 UI(Task 3)
- `PropertyAtlas/PropertyAtlas/Studio/Search/SearchMarker.swift` — 临时标记 + annotation 工厂(Task 4)
- `PropertyAtlas/PropertyAtlasTests/MapRender/EntitySearchTests.swift` — 单测(Task 1)

修改:
- `PropertyAtlas/PropertyAtlas/Studio/CreateEntitySheet.swift` — 加 `prefillName`/`defaultKind` + 名称 TextField(Task 5)
- `PropertyAtlas/PropertyAtlas/Studio/StudioToolbar.swift` — 加 🔍 按钮 + `showSearch` 绑定(Task 6)
- `PropertyAtlas/PropertyAtlas/Studio/StudioOverlay.swift` — 透传 `showSearch`(Task 6)
- `PropertyAtlas/PropertyAtlas/RootView.swift` — 状态/挂载面板/回调/标记注入/建实体(Task 6)

每个 Task 结束后 app 可编译。Task 1–5 各自独立;Task 6 端到端集成。

构建命令(每个 Task 验证用):
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head
```
测试命令:
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests 2>&1 | grep -iE "Test run with|TEST (SUCCEEDED|FAILED)|✘" | tail -5
```

> SourceKit 跨文件 "Cannot find X in scope" 诊断为已知 noise,以 `xcodebuild ... BUILD SUCCEEDED` 为准。

---

### Task 1: EntitySearch 纯逻辑 + 单测

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/EntitySearch.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/EntitySearchTests.swift`

- [ ] **Step 1: 写失败测试**

`PropertyAtlas/PropertyAtlasTests/MapRender/EntitySearchTests.swift`:
```swift
import CoreLocation
import Testing
@testable import PropertyAtlas

#if targetEnvironment(macCatalyst)
@MainActor
struct EntitySearchTests {
    private func mk(
        _ kind: EntityKind, _ name: String,
        aliases: [String] = [], address: String? = nil, category: String? = nil
    ) -> EntitySearch.Searchable {
        EntitySearch.Searchable(
            ref: EntityRef(id: UUID(), kind: kind), name: name, aliases: aliases,
            address: address, category: category,
            coordinate: CLLocationCoordinate2D(latitude: 39, longitude: 117), hasCoordinate: true
        )
    }

    @Test func emptyQueryReturnsEmpty() {
        let items = [mk(.compound, "万科城")]
        #expect(EntitySearch.search("", in: items).isEmpty)
        #expect(EntitySearch.search("   ", in: items).isEmpty)
    }

    @Test func namePrefixRanksAboveSubstring() {
        let items = [mk(.compound, "万科城"), mk(.compound, "城市花园")]
        let hits = EntitySearch.search("城", in: items)
        #expect(hits.count == 2)
        #expect(hits[0].name == "城市花园") // 前缀命中(rank 0)排前
    }

    @Test func matchesAlias() {
        let hits = EntitySearch.search("实小", in: [mk(.school, "实验小学", aliases: ["实小"])])
        #expect(hits.count == 1)
        #expect(hits[0].name == "实验小学")
    }

    @Test func matchesAddressAndCategory() {
        let items = [mk(.poi, "星巴克", address: "南京路1号", category: "咖啡")]
        #expect(EntitySearch.search("南京路", in: items).count == 1)
        #expect(EntitySearch.search("咖啡", in: items).count == 1)
    }

    @Test func caseInsensitive() {
        #expect(EntitySearch.search("apple", in: [mk(.poi, "Apple Store")]).count == 1)
    }

    @Test func limitTruncates() {
        let items = (0..<60).map { mk(.poi, "店\($0)") }
        #expect(EntitySearch.search("店", in: items, limit: 50).count == 50)
    }

    @Test func subtitleIncludesType() {
        let hits = EntitySearch.search("实验", in: [mk(.school, "实验小学", address: "河西区")])
        #expect(hits[0].subtitle == "学校 · 河西区")
    }
}
#endif
```

- [ ] **Step 2: 跑测试确认失败**

Run:
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests 2>&1 | grep -E "error:|Cannot find 'EntitySearch'" | head
```
Expected: 编译失败 `Cannot find 'EntitySearch' in scope`。

- [ ] **Step 3: 写实现**

`PropertyAtlas/PropertyAtlas/MapRender/EntitySearch.swift`:
```swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import Foundation

/// 库内实体搜索纯逻辑。匹配 name / aliases / address / category,带排序权重。
enum EntitySearch {
    struct Searchable {
        let ref: EntityRef
        let name: String
        let aliases: [String]
        let address: String?
        let category: String?
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
    }

    struct Hit: Identifiable {
        let ref: EntityRef
        let name: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
        var id: UUID { ref.id }
    }

    /// 大小写无关子串匹配。排序:name 前缀(0) > name 子串(1) > alias(2) > address/category(3);
    /// 同权按 name 本地化升序。空 query → []。
    static func search(_ query: String, in items: [Searchable], limit: Int = 50) -> [Hit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var ranked: [(rank: Int, hit: Hit)] = []
        for item in items {
            guard let rank = matchRank(q, item) else { continue }
            ranked.append((rank, makeHit(item)))
        }
        ranked.sort { lhs, rhs in
            lhs.rank != rhs.rank
                ? lhs.rank < rhs.rank
                : lhs.hit.name.localizedCompare(rhs.hit.name) == .orderedAscending
        }
        return ranked.prefix(limit).map { $0.hit }
    }

    private static func matchRank(_ q: String, _ item: Searchable) -> Int? {
        if let range = item.name.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            return range.lowerBound == item.name.startIndex ? 0 : 1
        }
        if item.aliases.contains(where: { $0.localizedCaseInsensitiveContains(q) }) { return 2 }
        if item.address?.localizedCaseInsensitiveContains(q) == true { return 3 }
        if item.category?.localizedCaseInsensitiveContains(q) == true { return 3 }
        return nil
    }

    private static func makeHit(_ item: Searchable) -> Hit {
        let detail = item.address ?? item.category
        let subtitle = detail.map { "\(typeLabel(item.ref.kind)) · \($0)" } ?? typeLabel(item.ref.kind)
        return Hit(
            ref: item.ref, name: item.name, subtitle: subtitle,
            coordinate: item.coordinate, hasCoordinate: item.hasCoordinate
        )
    }

    static func typeLabel(_ kind: EntityKind) -> String {
        switch kind {
        case .compound: "小区"
        case .school: "学校"
        case .poi: "POI"
        case .area: "片区"
        }
    }
}
#endif
```

- [ ] **Step 4: 跑测试确认通过**

Run: 测试命令(见顶部)。Expected: `Test run with <N> tests ... passed`,新增 7 个 EntitySearch 测试全过。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/EntitySearch.swift PropertyAtlas/PropertyAtlasTests/MapRender/EntitySearchTests.swift
git commit -m "feat(search): EntitySearch 库内匹配纯逻辑 + 单测"
```

---

### Task 2: ExternalPlaceSearch(MKLocalSearch 包装)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Search/ExternalPlaceSearch.swift`

无单测(网络层)。靠编译 + Task 6 手动验。

- [ ] **Step 1: 写实现**

`PropertyAtlas/PropertyAtlas/Studio/Search/ExternalPlaceSearch.swift`:
```swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit

/// Apple 地点搜索包装。spec §6.4:Apple MKLocalSearch 覆盖大陆主流地点,高德先不引入。
enum ExternalPlaceSearch {
    struct PlaceHit: Identifiable {
        let id = UUID()
        let name: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
    }

    static let fallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.125, longitude: 117.205),
        span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
    )

    /// naturalLanguageQuery + region 偏置。空 query → []。失败/无网 → 抛错。
    static func search(_ query: String, region: MKCoordinateRegion?) async throws -> [PlaceHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = q
        request.region = region ?? fallbackRegion
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.map { item in
            PlaceHit(
                name: item.name ?? "未命名",
                subtitle: subtitle(item.placemark),
                coordinate: item.placemark.coordinate
            )
        }
    }

    private static func subtitle(_ placemark: MKPlacemark) -> String {
        [placemark.locality, placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
#endif
```

- [ ] **Step 2: 跑构建确认通过**

Run: 构建命令。Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Search/ExternalPlaceSearch.swift
git commit -m "feat(search): ExternalPlaceSearch — MKLocalSearch async 包装"
```

---

### Task 3: StudioSearchPanel(面板 UI,库内 + 外部)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Search/StudioSearchPanel.swift`

依赖 Task 1(`EntitySearch`)+ Task 2(`ExternalPlaceSearch`)。本 Task 面板独立可编译,Task 6 才挂载。

- [ ] **Step 1: 写实现**

`PropertyAtlas/PropertyAtlas/Studio/Search/StudioSearchPanel.swift`:
```swift
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

    private struct TaskKey: Equatable { let scope: Scope; let query: String }

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
        guard !trimmed.isEmpty else { externalHits = []; return }
        try? await Task.sleep(nanoseconds: 300_000_000) // 防抖
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
        for c in compounds where c.datasetId == datasetId && !c.deleted {
            out.append(.init(
                ref: EntityRef(id: c.id, kind: .compound), name: c.name, aliases: c.aliases,
                address: c.address, category: nil, coordinate: c.coordinate,
                hasCoordinate: c.latitude != 0 || c.longitude != 0
            ))
        }
        for s in schools where s.datasetId == datasetId && !s.deleted {
            out.append(.init(
                ref: EntityRef(id: s.id, kind: .school), name: s.name, aliases: s.aliases,
                address: s.address, category: s.category, coordinate: s.coordinate,
                hasCoordinate: s.latitude != 0 || s.longitude != 0
            ))
        }
        for p in pois where p.datasetId == datasetId && !p.deleted {
            out.append(.init(
                ref: EntityRef(id: p.id, kind: .poi), name: p.name, aliases: p.aliases,
                address: p.address, category: p.category, coordinate: p.coordinate,
                hasCoordinate: p.latitude != 0 || p.longitude != 0
            ))
        }
        for a in areas where a.datasetId == datasetId && !a.deleted {
            out.append(.init(
                ref: EntityRef(id: a.id, kind: .area), name: a.name, aliases: a.aliases,
                address: nil, category: a.category, coordinate: CLLocationCoordinate2D(),
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
```

- [ ] **Step 2: 跑构建确认通过**

Run: 构建命令。Expected: `BUILD SUCCEEDED`(面板未挂载,仅编译)。

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Search/StudioSearchPanel.swift
git commit -m "feat(search): StudioSearchPanel 面板(库内 EntitySearch + 外部防抖)"
```

---

### Task 4: SearchMarker 临时标记 + annotation 工厂

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Search/SearchMarker.swift`

- [ ] **Step 1: 写实现**

`PropertyAtlas/PropertyAtlas/Studio/Search/SearchMarker.swift`:
```swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit

/// 外部搜索选中后的临时地图标记(非 @Model,运行时态)。
struct SearchMarker: Equatable {
    let coordinate: CLLocationCoordinate2D
    let name: String

    static func == (lhs: SearchMarker, rhs: SearchMarker) -> Bool {
        lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

enum SearchMarkerFactory {
    /// 区别于实体 pin 的哨兵类型/ID。onSchoolSelect 命中此 ID 时不做 select。
    static let markerType = "__searchMarker"
    static let markerId = UUID(uuidString: "00000000-0000-0000-0000-0000000000FF")!

    static func annotation(for marker: SearchMarker) -> PinAnnotation {
        let style = PinStyle(
            shape: .circle, fillHex: "#D9965A", strokeHex: "#FFFFFF",
            glyph: nil, glyphHex: "#FFFFFF", size: 18, labelVisible: true
        )
        return PinAnnotation(
            entityId: markerId, entityType: markerType, name: marker.name,
            coordinate: marker.coordinate, style: style
        )
    }
}
#endif
```

- [ ] **Step 2: 跑构建确认通过**

Run: 构建命令。Expected: `BUILD SUCCEEDED`。

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Search/SearchMarker.swift
git commit -m "feat(search): SearchMarker 临时标记 + annotation 工厂"
```

---

### Task 5: CreateEntitySheet 支持预填名称 + 默认类型

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/CreateEntitySheet.swift`

外部建实体需:名称预填、默认类型 POI(spec §6.4)。给 sheet 加名称 TextField + 两个可选参数,且 `onCreate` 增加 name 参数。默认行为(长按建实体)保持不变(name 空 → 调用方回退「未命名」)。

- [ ] **Step 1: 改 `CreateEntitySheet`**

`PropertyAtlas/PropertyAtlas/Studio/CreateEntitySheet.swift` 完整新内容:
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 长按地图 / 外部搜索新建实体:名称 + 选类型 + 选一个启用图层。
struct CreateEntitySheet: View {
    let enabledLayers: [(id: UUID, name: String)]
    let defaultLayerId: UUID?
    var prefillName: String?
    var defaultKind: EntityKind = .compound
    let onCreate: (EntityKind, UUID?, String) -> Void
    let onCancel: () -> Void

    @State private var kind: EntityKind = .compound
    @State private var layerId: UUID?
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建实体").font(Studio.sans(17, .bold)).foregroundStyle(Studio.on)

            Text("名称").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            TextField("未命名", text: $name).glassField()

            Text("类型").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            GlassSegmented(
                options: [(.compound, "小区"), (.school, "学校"), (.poi, "POI"), (.area, "片区")],
                selection: $kind
            )

            Text("归属图层").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            if enabledLayers.isEmpty {
                Text("无启用图层 → 进【默认】").font(Studio.sans(12)).foregroundStyle(Studio.on3)
            } else {
                VStack(spacing: 2) {
                    ForEach(enabledLayers, id: \.id) { l in
                        Button { layerId = l.id } label: {
                            HStack {
                                Text(l.name).font(Studio.sans(13)).foregroundStyle(Studio.on)
                                Spacer()
                                if (layerId ?? defaultLayerId) == l.id {
                                    Image(systemName: "checkmark").foregroundStyle(Studio.cool)
                                }
                            }
                            .padding(.horizontal, 10).frame(height: 38)
                            .background(
                                (layerId ?? defaultLayerId) == l.id ? Studio.glassHover : .clear,
                                in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button("取消") { onCancel() }.buttonStyle(.tbtn(.ghost))
                Button("建立") {
                    onCreate(kind, layerId ?? defaultLayerId, name)
                }.buttonStyle(.tbtn(.primary))
            }
        }
        .padding(18)
        .frame(width: 320)
        .background(Studio.glassStrong).background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Studio.rPanel, style: .continuous))
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear {
            kind = defaultKind
            name = prefillName ?? ""
        }
    }
}
#endif
```

> 注意:原文件末有 `.tint(Studio.cool)` 与 `#endif` 等收尾——以上为完整文件替换,若原文件 body 收尾不同,以本文件为准(保持 `.background/.clipShape/.environment/.tint` 链 + `.onAppear`)。

- [ ] **Step 2: 构建会因 RootView 旧 onCreate 调用而失败 — 这是预期**

Run: 构建命令。Expected: `error: ... onCreate` 参数不匹配(RootView `showCreateMenu` 里的旧 `onCreate: { kind, layerId in ... }` 现少一个参数)。Task 6 修复调用方。

> 若希望本 Task 独立绿,可临时把 RootView 调用处闭包改为 `{ kind, layerId, _ in createPin(kind, layerId: layerId) }`;但 Task 6 会重写该处,故此处允许红、紧接 Task 6。**为保证「每 Task 可编译」,本 Task 提交前先做下面 Step 3 的最小调用方适配。**

- [ ] **Step 3: 最小适配 RootView 调用方(令其编译)**

改 `PropertyAtlas/PropertyAtlas/RootView.swift` 中 `showCreateMenu` sheet 内的 `onCreate` 闭包:
```swift
                    onCreate: { kind, layerId, _ in
                        showCreateMenu = false
                        createPin(kind, layerId: layerId)
                    },
```
(name 暂忽略;Task 6 接预填。)

- [ ] **Step 4: 跑构建确认通过**

Run: 构建命令。Expected: `BUILD SUCCEEDED`。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/CreateEntitySheet.swift PropertyAtlas/PropertyAtlas/RootView.swift
git commit -m "feat(search): CreateEntitySheet 加名称预填 + defaultKind(onCreate 增 name)"
```

---

### Task 6: RootView + Toolbar 集成(端到端)

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/StudioToolbar.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/StudioOverlay.swift`
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`

- [ ] **Step 1: StudioToolbar 加 `showSearch` 绑定 + 🔍 按钮**

`PropertyAtlas/PropertyAtlas/Studio/StudioToolbar.swift` —— 给结构体加属性:
```swift
    @Binding var showSearch: Bool
```
位置:放在 `@Binding var showSafeFrame: Bool` 之后。

在 body 的 `HStack(spacing: 4)` 内、`// settings` 的 `Button` 之前插入搜索按钮:
```swift
            // search
            Button { showSearch.toggle() } label: {
                DockLabel(icon: "magnifyingglass", iconOnly: true)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
```

- [ ] **Step 2: StudioOverlay 透传 `showSearch`**

`PropertyAtlas/PropertyAtlas/Studio/StudioOverlay.swift` —— 加属性(放 `@Binding var showSafeFrame: Bool` 之后):
```swift
    @Binding var showSearch: Bool
```
改 `StudioToolbar(...)` 调用,补参数:
```swift
                    StudioToolbar(
                        viewContext: viewContext, aspect: $aspect,
                        onSnapshot: {}, showSettings: $showSettings, exportMode: $exportMode,
                        showSafeFrame: $showSafeFrame, showSearch: $showSearch
                    )
```

- [ ] **Step 3: RootView 加状态**

`PropertyAtlas/PropertyAtlas/RootView.swift` —— 在 `@State private var cache = StudioRenderCache()` 之后加:
```swift
    @State private var showSearch = false
    @State private var searchMarker: SearchMarker?
    @State private var createPrefillName: String?
```

- [ ] **Step 4: 传 `showSearch` 给 StudioOverlay**

找到 body 内 `StudioOverlay(...)` 调用,补参数(在 `showSafeFrame: $showSafeFrame` 后):
```swift
                StudioOverlay(
                    title: $title, subtitle: $subtitle, watermark: $watermark,
                    aspect: $aspect, viewContext: ctx, showSettings: $showSettings,
                    exportMode: $exportMode, showSafeFrame: $showSafeFrame, showSearch: $showSearch
                )
```

- [ ] **Step 5: 注入临时标记到 annotations**

找到 body 内 `let overlays = cache.overlays`,在其后加:
```swift
        let markerAnnotations: [MKAnnotation] = searchMarker.map { [SearchMarkerFactory.annotation(for: $0)] } ?? []
        let annotations = cache.pins + markerAnnotations
```
把 `MapContainerView(camera: $camera, overlays: overlays, annotations: cache.pins, ...)` 改为:
```swift
            MapContainerView(
                camera: $camera, overlays: overlays, annotations: annotations,
```

- [ ] **Step 6: onSchoolSelect 特判哨兵标记**

把 `onSchoolSelect` 闭包改为(命中 searchMarker 的哨兵 ID 时不动选中):
```swift
                onSchoolSelect: { id in
                    if id == SearchMarkerFactory.markerId { return }
                    if let id, let kind = idKind(for: id, in: cache.pins) {
                        appState.select(EntityRef(id: id, kind: kind))
                    } else {
                        appState.clearSelection()
                    }
                },
```

- [ ] **Step 7: 挂载搜索面板(dock 上方,出图模式隐藏)**

在 body 的 `ZStack { ... }` 内,`StudioOverlay(...)` 块之后、`if !exportMode { ...RightDrawer... }` 之前,加:
```swift
            if !exportMode, showSearch {
                VStack {
                    Spacer()
                    StudioSearchPanel(
                        datasetId: dsId,
                        visibleRegion: visibleRegion,
                        onPickEntity: { ref, coord, hasCoord in
                            appState.select(ref)
                            if hasCoord, let coord { flyTo(coord) }
                            showSearch = false
                        },
                        onPickExternal: { hit in
                            flyTo(hit.coordinate)
                            searchMarker = SearchMarker(coordinate: hit.coordinate, name: hit.name)
                        },
                        onCreateAtExternal: { hit in
                            pendingCoordinate = hit.coordinate
                            createPrefillName = hit.name
                            showSearch = false
                            showCreateMenu = true
                        },
                        onClose: { showSearch = false }
                    )
                    .padding(.bottom, 76)
                }
                .transition(.opacity)
            }
```

- [ ] **Step 8: 加 `flyTo` 辅助 + 更新 createPin/建实体 sheet**

在 `RootView` 的 `createPin` 方法附近加:
```swift
    private func flyTo(_ coord: CLLocationCoordinate2D) {
        camera = MKMapCamera(lookingAtCenter: coord, fromDistance: 2000, pitch: 0, heading: 0)
    }
```

改 `createPin` 签名以接收名称:
```swift
    private func createPin(_ kind: EntityKind, layerId: UUID?, name: String = "") {
        guard let coord = pendingCoordinate, let dsId = viewContext?.datasetIdValue else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ref = EntityWriter.createPin(
            kind: kind, datasetId: dsId, name: trimmed.isEmpty ? "未命名" : trimmed,
            latitude: coord.latitude, longitude: coord.longitude, layerId: layerId, in: modelContext
        )
        searchMarker = nil
        createPrefillName = nil
        appState.select(ref)
        appState.beginEditing()
    }
```

改 `showCreateMenu` sheet,接预填名称 + 默认 POI,并把 name 传入 createPin:
```swift
        .sheet(isPresented: $showCreateMenu) {
            if let dsId = viewContext?.datasetIdValue {
                let layers = layersForDataset(dsId)
                let defaultId = layers.first(where: { $0.isDefault })?.id
                let enabled = layers.filter { layerState.isEnabled($0.id) }.map { (id: $0.id, name: $0.name) }
                CreateEntitySheet(
                    enabledLayers: enabled,
                    defaultLayerId: defaultId,
                    prefillName: createPrefillName,
                    defaultKind: createPrefillName != nil ? .poi : .compound,
                    onCreate: { kind, layerId, name in
                        showCreateMenu = false
                        createPin(kind, layerId: layerId, name: name)
                    },
                    onCancel: { showCreateMenu = false
                        createPrefillName = nil
                    }
                )
                .presentationDetents([.medium])
            }
        }
```

- [ ] **Step 9: 切视图/数据集时清标记**

找到 body 末的 `.onChange(of: viewContext?.activeMapView?.id) { _, _ in ... }`,在其闭包体加一行 `searchMarker = nil`:
```swift
        .onChange(of: viewContext?.activeMapView?.id) { _, _ in
            layerState.resetForTheme(enabledIds: viewContext?.activeMapView?.enabledLayerIds ?? [])
            filterState.reset()
            searchMarker = nil
            showSearch = false
        }
```

- [ ] **Step 10: 跑构建确认通过**

Run: 构建命令。Expected: `BUILD SUCCEEDED`。

- [ ] **Step 11: 跑测试确认通过**

Run: 测试命令。Expected: `Test run with <N> tests ... passed`(无回归)。

- [ ] **Step 12: 手动验(在 Mac 跑 app)**

- dock 🔍(或 ⌘F)→ 面板弹出在 dock 上方。
- 库内:输中文名 → 实时结果;点结果 → 相机飞到该点 + 右抽屉 EntityCard;area 结果点击仅选中不飞。
- 外部:切「外部」→ 输地点(联网)→ 0.3s 后结果;点结果 → 飞过去 + amber 临时标记;点「＋」→ CreateEntitySheet(类型默 POI、名称预填)→ 建立后标记消失、选中新实体。
- 离线外部 → 「外部搜索失败,检查网络后重试」。
- 出图模式 → 🔍 与面板都不显。
- 切视图 → 标记清除、面板关闭。

- [ ] **Step 13: SwiftLint + Commit**

```bash
cd /Users/fujie/projects/天津买房 && swiftlint lint --quiet PropertyAtlas/PropertyAtlas/RootView.swift PropertyAtlas/PropertyAtlas/Studio/StudioToolbar.swift PropertyAtlas/PropertyAtlas/Studio/StudioOverlay.swift PropertyAtlas/PropertyAtlas/Studio/Search/StudioSearchPanel.swift 2>&1 | grep -v "should be between 3 and 40" | head
git add PropertyAtlas/PropertyAtlas/RootView.swift PropertyAtlas/PropertyAtlas/Studio/StudioToolbar.swift PropertyAtlas/PropertyAtlas/Studio/StudioOverlay.swift
git commit -m "feat(search): 集成搜索入口 — dock 🔍 + 飞相机/选中 + 临时标记 + 建 POI"
```

---

## Self-Review

**Spec coverage:**
- 入口形态 A(dock 🔍)→ Task 6 Step 1。✓
- 库内 EntitySearch(name/aliases/address/category + 排序 + 单测)→ Task 1。✓
- 库内数据源(@Query + datasetId 过滤)+ 选中飞相机+select → Task 3 `searchables()` + Task 6 `onPickEntity`/`flyTo`。✓
- area 无坐标仅选中 → `hasCoordinate=false` + `onPickEntity` 守卫。✓
- 外部 MKLocalSearch(region 偏置 + 防抖)→ Task 2 + Task 3 `runExternalIfNeeded`。✓
- 外部选中飞+临时标记 → Task 4 + Task 6 `onPickExternal`/marker 注入。✓
- 外部建 Pin(默认 POI + 预填)→ Task 5 + Task 6 `onCreateAtExternal`/createPin。✓
- 临时标记哨兵不被 select → Task 6 Step 6。✓
- 出图模式隐藏 → 面板在 `if !exportMode`;🔍 在 dock(已在 `!exportMode`)。✓
- 切视图清标记 → Task 6 Step 9。✓
- 错误/边界(空 query/无匹配/无网/空结果)→ Task 3 `localRows`/`externalRows` 各分支。✓

**Placeholder scan:** 无 TBD/TODO;所有 step 含完整代码。✓

**Type consistency:**
- `EntitySearch.Searchable`/`Hit` 字段在 Task 1 定义,Task 3 构造一致。✓
- `ExternalPlaceSearch.PlaceHit` 在 Task 2 定义,Task 3/6 用一致。✓
- `onPickEntity: (EntityRef, CLLocationCoordinate2D?, Bool)`、`onPickExternal: (PlaceHit)`、`onCreateAtExternal: (PlaceHit)`、`onClose: ()` —— Task 3 面板签名与 Task 6 调用一致。✓
- `onCreate: (EntityKind, UUID?, String)` —— Task 5 定义,Task 5 Step 3 临时适配 + Task 6 Step 8 正式接入一致。✓
- `createPin(_:layerId:name:)`、`flyTo(_:)`、`SearchMarkerFactory.markerId/annotation(for:)` 一致。✓

**Scope:** 单一功能(搜索入口),聚焦,适合单计划。✓
