# P8b View-Driven Integration + 删旧 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** 把 Studio 渲染路径从旧 `Theme`/`FilterFieldConfig`/`FilterState`/`LegendCounter` 切换到 P7/P8a 的 `MapView`/`MapDimension`/`PrimaryFilter`/`NormalFilter`/`VisibilityResolver`/`DimensionLegendCounter`/`PaletteAssigner` 引擎;删除旧过滤/图例引擎;把 9 个全局字段从 `Theme` 剥离到 `MapView`。

**Architecture (本期定稿决策):**
- **务实单 active theme**:`MapView` 驱动一切(过滤/图例/染色/文案/相机/可见性)。每个 entity 的*基样式*仍用**单个** active theme 解析;active theme = active MapView 的启用图层里 **zIndex 最高且有 themeId** 的那层的 theme,回退 `dataset.activeThemeId`。`StyleResolver.resolvePin` 签名不变(P8a 已加 `groupFillHex`)。真正的"逐图层 theme"延后到独立阶段。
- **染色**:`PrimaryFilter.groupBy` 存在 → `PaletteAssigner` 按分组值取色 → 经 `groupFillHex` 传入 `resolvePin`(override 仍最高,见 P8a)。groupBy 不存在 → 走 theme 基样式(StyleRule 仍生效)。
- **图例**:groupBy → 一组彩色 chip(palette 色);每个 NormalFilter → 一组中性灰 chip + 视口/总数(spec:normal 不参与染色)。chip toggle → `DimensionFilterState`。
- **删字段**:`Theme` 删除 9 字段(`visibilityJSON`/`defaultEnabledLayerIds`/`drawEdgeLines`/`copyTitle`/`copySubtitle`/`copyWatermark`/`bgMapStyle`/`cameraPresetId`/`spotlightOnSelect`)→ schema 破坏性变更 → **清库重迁 smoke**。
- **保留**(本期不删):`FilterFieldConfig` @Model(migrator 仍用它派生 normalFilters;UI 不再用)、`LegendSwatch`(切换后变未用,留待 P9)、`LayerEvaluator`/`LayerQuery`/`LayerState`/`ZoomLevel`。
- **删除**:`FilterState`、`FilterPredicate`(先把静态 `display`/`key` 迁到 `ValueFormat`)、旧 `LegendCounter` + 它们的测试。

**Tech Stack:** SwiftUI · MapKit · SwiftData · Swift Testing · P7/P8a 引擎。

**前置**: spec `docs/superpowers/specs/2026-05-31-generic-filter-legend-color-redesign.md`;P7(MapDimension/PrimaryFilter/NormalFilter/DimensionFilterState/VisibilityResolver/DimensionLegendCounter 已合)、P8a(MapView/Layer.zIndex+themeId/PaletteAssigner/resolvePin groupFillHex/migrator seedMapViews 已合)。

**关键现状(已核实签名):**
- `StudioRootView` in `RootView.swift`(`#if targetEnvironment(macCatalyst)`),body 见现状;`themeContext: ThemeContext?`、`filterState: FilterState`、`legendItems→[LegendCounter.Item]`、`buildPins(...,filterPredicate:FilterPredicate,...)`、`buildAreaOverlays`、`buildEdgeLines(theme:)`、`visibilityFromTheme(_:)`、`fieldKeys(_:_:)`、`layersForDataset(_:)`。
- `ThemeContext`:`activeTheme`/`allThemes`/`switchTheme`/`datasetIdValue`(基于 `dataset.activeThemeId`)。
- `StudioToolbar`(theme 菜单)/`StudioOverlay`(吃 `themeContext`)。
- `LeftDrawerView`(legendRows:[LegendCounter.Row], filterState:FilterState, layerState, layers, currentZoom)→`LayersView`(留)+`LegendView`(rows:[LegendCounter.Row], filterState:FilterState)。
- `VisibilityResolver.visibleIds(candidates:[Candidate{id,entity,layerNames}], layerVisible:Set<UUID>, primary:PrimaryFilter, normals:[NormalFilter], filterState:DimensionFilterState, context:ModelContext?, datasetId:UUID?)->Set<UUID>`。
- `DimensionLegendCounter.rows(dimension:MapDimension, items:[Item{id,entity,coordinate,layerNames}], region:MKCoordinateRegion?, context:, datasetId:, swatch:(String)->String)->[Row{dimensionKey,value,swatchHex,viewport,total; id}]`。
- `MapDimension`(kind/fieldKey/fieldSource/edgeLabel/edgeDirection/edgeTargetField; `key`; `Input{entity,layerNames,context,datasetId}`; `@MainActor resolve(_:)->[String]`)。**注意**:`MapDimension.field` case 调 `FilterPredicate.display(...)` —— T0 之前不要删 FilterPredicate。
- `PrimaryFilter{conditions:[FilterCondition], groupBy:MapDimension?; matches(_:); groupValues(_:)}`、`NormalFilter{id,name,dimension; init(id:name:dimension:)}`。
- `DimensionFilterState{ isHidden(dimensionKey:value:); toggle(dimensionKey:value:); reset() }`。
- `LayerEvaluator{ Candidate{id,type,entity}; ActiveLayer{query,enabled,minZoom,maxZoom; isActive(at:)}; visibleIds(layers:zoom:candidates:)->Set<UUID>; private matchesAll(_:_:) }`、`LayerQuery{staticRefs,dynamicType,dynamicConditions,isMatchAll,coveredTypes; init(staticRefsJSON:dynamicQueryJSON:)}`。
- `PaletteAssigner.assign(values:[String], palette:[String])->[String:String]`、`PaletteAssigner.highContrast:[String]`。
- `StyleResolver.resolvePin(entity:theme:rules:palettes:groupFillHex:)`、`resolveArea(entity:theme:rules:palettes:)`。
- `Palette{ colorsHex:[String]; ... }`;`StyleEntity{ entityType:String; id:UUID; func field(_:)->AnyJSON? }`;`HexColor.parse(_:)`。
- migrator `seedPalettesThemesLayers(dataset:in:)`:建 4 palette(首个 `default-rainbow` 捕获为 `defaultPalette`)+ defaultLayer(zIndex=0/themeId=t1.id)+ 4 theme(t1-t4,各写 visibilityJSON/defaultEnabledLayerIds/copy*/…)+ 末尾 `dataset.activeThemeId=t1.id` + `seedMapViews(dataset:defaultLayerId:themes:palette:in:)`(每 theme 一个 MapView,copy* 等从 theme 拷)。

**新增文件:** `MapRender/ValueFormat.swift`、`MapRender/GroupColorResolver.swift`、`MapRender/MapViewContext.swift` + 测试。
**改:** `Models/Display/MapView.swift`、`DataKit/MapDimension.swift`、`MapRender/LayerEvaluator.swift`、`DataKit/LegacyMigrator.swift`、`RootView.swift`、`Studio/LeftDrawer/{LegendView,LeftDrawerView}.swift`、`Studio/{StudioToolbar,StudioOverlay}.swift`、`Models/Style/Theme.swift`、`CLAUDE.md`。
**删:** `States/FilterState.swift`、`States/FilterPredicate.swift`、`MapRender/LegendCounter.swift` + `PropertyAtlasTests/States/FilterStateTests.swift`、`PropertyAtlasTests/States/FilterPredicateTests.swift`、`PropertyAtlasTests/MapRender/LegendCounterTests.swift`。

> 所有 `xcodebuild` 从 worktree 的 `PropertyAtlas` 子目录运行。Swift Testing(非 XCTest)。提交 `git -c commit.gpgsign=false commit -am`。SourceKit "No such module 'Testing'"/"Cannot find type" 是陈旧索引噪声,以 `xcodebuild test` 为准。

---

### Task 0: MapView + visibilityJSON 字段 + migrator 拷贝

**Files:** Modify `PropertyAtlas/PropertyAtlas/Models/Display/MapView.swift`、`PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`; Test `PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`(追加)

- [ ] **Step 1: 写失败测试**(追加到 LegacyMigratorTests)

```swift
@Test func seededMapViewHasVisibilityJSON() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let ls = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
    ctx.insert(ls); try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let v = try #require(try ctx.fetch(FetchDescriptor<MapView>()).first { $0.isActive })
    // visibilityJSON 可解析为 [String:Bool] 且含 compound/school/poi/area 键
    let data = Data(v.visibilityJSON.utf8)
    let obj = try #require(try? JSONSerialization.jsonObject(with: data) as? [String: Bool])
    #expect(obj["school"] != nil)
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/LegacyMigratorTests 2>&1 | tail -30`
Expected: FAIL(`MapView` 无 `visibilityJSON` 成员 → 编译失败,或断言失败)。

- [ ] **Step 3: 实现** —— `MapView.swift` 在 `var normalFiltersJSON` 行后加字段:
```swift
var visibilityJSON: String = #"{"compound":true,"school":true,"poi":true,"area":true}"#
```
然后 `LegacyMigrator.swift` 的 `seedMapViews(...)` 循环里(建 `MapView` 后、`ctx.insert(v)` 前)加一行,从对应 theme 拷:
```swift
v.visibilityJSON = t.visibilityJSON
```
(此时 `Theme.visibilityJSON` 仍存在,T7 才删并改为直接写字面量。)

- [ ] **Step 4: 跑确认通过** + 全量 `LegacyMigratorTests`(20→21,全过)。
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(model): MapView.visibilityJSON + migrate from theme"`

---

### Task 1: LayerEvaluator.membership(每实体启用图层名)

**Files:** Modify `PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift`; Test `PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift`(追加)

`MapDimension.Input.layerNames` 与 `VisibilityResolver.Candidate.layerNames` 都需要"每个实体属于哪些启用图层"。新增 `membership` 返回 `[UUID:[String]]`。

- [ ] **Step 1: 写失败测试**(追加)
```swift
@Test func membershipMapsEntityToMatchingLayerNames() {
    // 动态层:type==school 且无条件 → 命中所有 school
    let q = LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: #"{"type":"school","conditions":[]}"#)
    let named = LayerEvaluator.NamedLayer(
        name: "教育",
        layer: LayerEvaluator.ActiveLayer(query: q, enabled: true, minZoom: nil, maxZoom: nil)
    )
    let sId = UUID()
    let cand = LayerEvaluator.Candidate(id: sId, type: "school",
        entity: StyleEntity(entityType: "school", id: sId, baseFields: [:], customFields: [:]))
    let m = LayerEvaluator.membership(layers: [named], zoom: 12, candidates: [cand])
    #expect(m[sId] == ["教育"])
}
```
> `LayerQuery` 的 dynamicQueryJSON 形状以现有 `LayerQueryTests` 为准;若键名不同,照搬测试里的真实 JSON。`StyleEntity` 构造以现有测试为准。

- [ ] **Step 2: 跑确认失败**(`-only-testing:PropertyAtlasTests/LayerEvaluatorTests`)

- [ ] **Step 3: 实现** —— 在 `LayerEvaluator` 内加:
```swift
struct NamedLayer {
    let name: String
    let layer: ActiveLayer
}

/// 每个 candidate → 命中的启用图层名集合(用于 MapDimension.layer 维度 + 可见集 layerNames)。
/// 语义对齐 visibleIds:match-all 层使所有 candidate 归属该层;受约束类型只有命中成员才归属。
static func membership(layers: [NamedLayer], zoom: Double, candidates: [Candidate]) -> [UUID: [String]] {
    let active = layers.filter { $0.layer.isActive(at: zoom) }
    var out: [UUID: [String]] = [:]
    for nl in active {
        let q = nl.layer.query
        if q.isMatchAll {
            for c in candidates { out[c.id, default: []].append(nl.name) }
            continue
        }
        let covered = q.coveredTypes
        let staticIds = Set(q.staticRefs.map(\.id))
        for c in candidates {
            let isMember: Bool
            if staticIds.contains(c.id) {
                isMember = true
            } else if let dType = q.dynamicType, c.type == dType {
                isMember = matchesAll(c.entity, q.dynamicConditions)
            } else if !covered.contains(c.type) {
                isMember = false   // 该层不覆盖此类型 → 不归属此层(membership 比 visibleIds 严格:只列真正成员)
            } else {
                isMember = false
            }
            if isMember { out[c.id, default: []].append(nl.name) }
        }
    }
    return out
}
```

- [ ] **Step 4: 跑确认通过** + 全量 `LayerEvaluatorTests`。
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(layer): LayerEvaluator.membership (entity→enabled layer names)"`

---

### Task 2: ValueFormat(迁出 FilterPredicate 静态工具)

**Files:** Create `PropertyAtlas/PropertyAtlas/MapRender/ValueFormat.swift`; Modify `PropertyAtlas/PropertyAtlas/DataKit/MapDimension.swift`; Test `PropertyAtlasTests/MapRender/ValueFormatTests.swift`

`FilterPredicate` 将于 T6 删除,但 `MapDimension.field` case 依赖其 `display(_:)`。先把纯静态工具迁到 `ValueFormat`,改 `MapDimension` 引用它。

- [ ] **Step 1: 写失败测试**(ValueFormatTests.swift)
```swift
import Testing
import Foundation
@testable import PropertyAtlas

struct ValueFormatTests {
    @Test func displayScalarKinds() {
        #expect(ValueFormat.display(.string("重点")) == "重点")
        #expect(ValueFormat.display(.int(3)) == "3")
        #expect(ValueFormat.display(.bool(true)) == "true")
        #expect(ValueFormat.display(nil) == "")
    }
    @Test func keyJoinsTypeAndField() {
        #expect(ValueFormat.key("school", "grade") == "school.grade")
    }
}
```

- [ ] **Step 2: 跑确认失败**(`-only-testing:PropertyAtlasTests/ValueFormatTests`)

- [ ] **Step 3: 实现**
新文件 `ValueFormat.swift`:
```swift
import Foundation

/// 标量 → 显示串 / 复合键。原 FilterPredicate 的纯静态工具迁移至此(FilterPredicate 将删除)。
enum ValueFormat {
    static func key(_ entityType: String, _ fieldKey: String) -> String {
        "\(entityType).\(fieldKey)"
    }

    static func display(_ v: AnyJSON?) -> String {
        switch v {
        case let .string(s): s
        case let .int(i): String(i)
        case let .double(d): String(d)
        case let .bool(b): b ? "true" : "false"
        default: ""
        }
    }
}
```
`MapDimension.swift` 第 57 行 `FilterPredicate.display(...)` → `ValueFormat.display(...)`。

- [ ] **Step 4: 跑确认通过** + `MapDimensionTests` 仍过(`-only-testing:PropertyAtlasTests/MapDimensionTests`)。
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "refactor(dim): extract ValueFormat from FilterPredicate; MapDimension uses it"`

---

### Task 3: GroupColorResolver(分组染色映射)

**Files:** Create `PropertyAtlas/PropertyAtlas/MapRender/GroupColorResolver.swift`; Test `PropertyAtlasTests/MapRender/GroupColorResolverTests.swift`

给定可见实体 + `groupBy` 维度 + palette,产出 `[实体id → fillHex]`(经 `PaletteAssigner` 同屏去重)。groupBy 为 nil → 空(走 theme 基样式)。

- [ ] **Step 1: 写失败测试**
```swift
import Testing
import Foundation
import SwiftData
@testable import PropertyAtlas

@MainActor
struct GroupColorResolverTests {
    private func item(_ id: UUID, grade: String) -> GroupColorResolver.Item {
        GroupColorResolver.Item(
            id: id,
            entity: StyleEntity(entityType: "school", id: id, baseFields: ["grade": .string(grade)], customFields: [:]),
            layerNames: []
        )
    }

    @Test func nilGroupByYieldsEmpty() {
        let m = GroupColorResolver.colors(items: [item(UUID(), grade: "重点")], groupBy: nil,
            palette: ["#111111"], context: nil, datasetId: nil)
        #expect(m.isEmpty)
    }

    @Test func distinctGroupValuesGetDistinctColors() {
        let a = UUID(); let b = UUID()
        let dim = MapDimension(kind: .field, fieldKey: "grade", fieldSource: "base")
        let m = GroupColorResolver.colors(
            items: [item(a, grade: "重点"), item(b, grade: "普通")],
            groupBy: dim, palette: ["#E41A1C", "#377EB8"], context: nil, datasetId: nil)
        #expect(m[a] != nil && m[b] != nil)
        #expect(m[a] != m[b])
    }
}
```
> `StyleEntity(entityType:id:baseFields:customFields:)` 构造以现有 ConditionEvaluator/测试为准;若签名不同,适配。

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**
```swift
import Foundation
import SwiftData

/// 分组染色:可见实体在 groupBy 维度的值集 → PaletteAssigner 取色 → 每实体 fillHex。
/// groupBy 为 nil 返回空(此时渲染走 theme 基样式)。多值取排序首值作染色键。
@MainActor
enum GroupColorResolver {
    struct Item {
        let id: UUID
        let entity: StyleEntity
        let layerNames: [String]
    }

    static func colors(
        items: [Item],
        groupBy: MapDimension?,
        palette: [String],
        context: ModelContext?,
        datasetId: UUID?
    ) -> [UUID: String] {
        guard let gb = groupBy, !palette.isEmpty else { return [:] }
        // 1) 收集每实体的(排序后)首个分组值 + 全体 distinct 值集
        var firstValue: [UUID: String] = [:]
        var distinct = Set<String>()
        for it in items {
            let input = MapDimension.Input(entity: it.entity, layerNames: it.layerNames, context: context, datasetId: datasetId)
            let vals = gb.resolve(input).sorted()
            guard let first = vals.first, !first.isEmpty else { continue }
            firstValue[it.id] = first
            distinct.insert(first)
        }
        // 2) 同屏去重分配
        let assign = PaletteAssigner.assign(values: Array(distinct), palette: palette)
        // 3) 映射回实体
        var out: [UUID: String] = [:]
        for (id, v) in firstValue {
            if let hex = assign[v] { out[id] = hex }
        }
        return out
    }
}
```

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(color): GroupColorResolver (groupBy values → PaletteAssigner → entity fill)"`

---

### Task 4: MapViewContext(替 ThemeContext 的视图驱动上下文)

**Files:** Create `PropertyAtlas/PropertyAtlas/MapRender/MapViewContext.swift`; Test `PropertyAtlasTests/MapRender/MapViewContextTests.swift`

封装 active MapView + 派生 active theme + 解码 primary/normal filter + 可见性 + 切换视图。

- [ ] **Step 1: 写失败测试**
```swift
import Testing
import Foundation
import SwiftData
@testable import PropertyAtlas

@MainActor
struct MapViewContextTests {
    @Test func activeViewAndDecodedFiltersAndThemeFallback() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let ds = Dataset(name: "T")
        ctx.insert(ds)
        let theme = Theme(datasetId: ds.id, name: "基础")
        ctx.insert(theme)
        ds.activeThemeId = theme.id
        let v = MapView(datasetId: ds.id, name: "学区视图")
        v.isActive = true
        v.primaryFilterJSON = #"{"conditions":[],"groupBy":{"kind":"field","fieldKey":"grade","fieldSource":"base"}}"#
        v.normalFiltersJSON = "[]"
        ctx.insert(v)
        try ctx.save()

        let mvc = MapViewContext(dataset: ds, modelContext: ctx)
        #expect(mvc.activeMapView?.name == "学区视图")
        #expect(mvc.primaryFilter.groupBy?.fieldKey == "grade")
        #expect(mvc.normalFilters.isEmpty)
        // 无图层 themeId → 回退 dataset.activeThemeId
        #expect(mvc.activeTheme?.id == theme.id)
        #expect(mvc.visibility["school"] == true)
    }

    @Test func switchViewSetsActive() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let ds = Dataset(name: "T"); ctx.insert(ds)
        let v1 = MapView(datasetId: ds.id, name: "A"); v1.isActive = true; v1.sortOrder = 0
        let v2 = MapView(datasetId: ds.id, name: "B"); v2.isActive = false; v2.sortOrder = 1
        ctx.insert(v1); ctx.insert(v2); try ctx.save()
        let mvc = MapViewContext(dataset: ds, modelContext: ctx)
        mvc.switchView(to: v2)
        #expect(mvc.activeMapView?.name == "B")
        #expect(v1.isActive == false)
    }
}
```
> `Dataset(name:)`、`Theme(datasetId:name:)` 构造以现有为准;若 init 不同,适配。

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**
```swift
import Foundation
import Observation
import SwiftData

/// 视图驱动上下文(取代 ThemeContext 的全局职责)。
/// 持有 active MapView,派生 active theme(启用图层里 zIndex 最高且有 themeId 的 theme,回退 dataset.activeThemeId),
/// 解码 primary/normal filter,暴露可见性 dict 与视图切换。
@MainActor
@Observable
final class MapViewContext {
    private let dataset: Dataset
    private let modelContext: ModelContext

    init(dataset: Dataset, modelContext: ModelContext) {
        self.dataset = dataset
        self.modelContext = modelContext
    }

    var datasetIdValue: UUID { dataset.id }

    var allMapViews: [MapView] {
        let dsId = dataset.id
        let fd = FetchDescriptor<MapView>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(fd)) ?? []
    }

    var activeMapView: MapView? {
        let views = allMapViews
        return views.first { $0.isActive } ?? views.first
    }

    func switchView(to view: MapView) {
        for v in allMapViews { v.isActive = (v.id == view.id) }
        dataset.updatedAt = Date()
    }

    /// active theme = active MapView 启用图层中 zIndex 最高且有 themeId 的层的 theme;回退 dataset.activeThemeId。
    var activeTheme: Theme? {
        if let mv = activeMapView {
            let enabled = Set(mv.enabledLayerIds)
            let dsId = dataset.id
            let lf = FetchDescriptor<Layer>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            let layers = ((try? modelContext.fetch(lf)) ?? [])
                .filter { enabled.contains($0.id) }
                .sorted { $0.zIndex > $1.zIndex }
            if let tid = layers.compactMap(\.themeId).first, let t = theme(id: tid) {
                return t
            }
        }
        if let aid = dataset.activeThemeId { return theme(id: aid) }
        return nil
    }

    private func theme(id: UUID) -> Theme? {
        let fd = FetchDescriptor<Theme>(predicate: #Predicate { $0.id == id && !$0.deleted })
        return try? modelContext.fetch(fd).first
    }

    var primaryFilter: PrimaryFilter {
        guard let json = activeMapView?.primaryFilterJSON,
              let pf = try? JSONDecoder().decode(PrimaryFilter.self, from: Data(json.utf8))
        else { return PrimaryFilter(conditions: [], groupBy: nil) }
        return pf
    }

    var normalFilters: [NormalFilter] {
        guard let json = activeMapView?.normalFiltersJSON,
              let nfs = try? JSONDecoder().decode([NormalFilter].self, from: Data(json.utf8))
        else { return [] }
        return nfs
    }

    var visibility: [String: Bool] {
        guard let json = activeMapView?.visibilityJSON,
              let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Bool]
        else { return ["compound": true, "school": true, "poi": true, "area": true] }
        return obj
    }
}
```

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(view): MapViewContext (active MapView + derived theme + decoded filters)"`

---

### Task 5: RootView + 抽屉 + 工具栏切换到视图驱动(集成核心)

**Files:** Modify `RootView.swift`、`Studio/LeftDrawer/LegendView.swift`、`Studio/LeftDrawer/LeftDrawerView.swift`、`Studio/StudioToolbar.swift`、`Studio/StudioOverlay.swift`

**这是原子切换任务**:一次性把 RootView 及其 UI 子件换到新引擎,结束时全 app 编译通过。无 SwiftUI 单测;靠**编译通过** + 既有引擎单测(VisibilityResolver/DimensionLegendCounter/GroupColorResolver/MapViewContext)+ T8 清库 smoke 验证。

> 旧 `FilterState`/`FilterPredicate`/`LegendCounter` 仍在(T6 才删),但本任务后 RootView/UI **不再引用**它们。

- [ ] **Step 1: 重写 `LegendView.swift`**(整文件替换)
```swift
// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LegendView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 一组图例(primary groupBy 或某个 normal filter):标题 + 维度键 + 行。
struct LegendSection: Identifiable {
    let title: String
    let dimensionKey: String
    let rows: [DimensionLegendCounter.Row]
    var id: String { dimensionKey }
}

struct LegendView: View {
    let sections: [LegendSection]
    @Bindable var filterState: DimensionFilterState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图例").font(.system(size: 12, weight: .bold))
            if sections.allSatisfy({ $0.rows.isEmpty }) {
                Text("拖动地图后显示").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(sections) { section in
                if !section.rows.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        ForEach(section.rows) { row in chip(section.dimensionKey, row) }
                    }
                }
            }
        }
    }

    private func chip(_ dimensionKey: String, _ row: DimensionLegendCounter.Row) -> some View {
        let hidden = filterState.isHidden(dimensionKey: dimensionKey, value: row.value)
        return Button {
            filterState.toggle(dimensionKey: dimensionKey, value: row.value)
        } label: {
            HStack(spacing: 6) {
                Circle().fill(Color(uiColor: HexColor.parse(row.swatchHex) ?? .gray)).frame(width: 12, height: 12)
                Text(row.value).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(row.viewport) / \(row.total)")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .opacity(hidden ? 0.35 : 1)
            .contentShape(Rectangle())
            .padding(.leading, 8)
        }.buttonStyle(.plain)
    }
}
#endif
```

- [ ] **Step 2: 重写 `LeftDrawerView.swift`**(整文件替换)
```swift
// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LeftDrawerView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LeftDrawerView: View {
    let legendSections: [LegendSection]
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var filterState: DimensionFilterState
    @Bindable var layerState: LayerState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LayersView(layers: layers, currentZoom: currentZoom, layerState: layerState)
                Divider().opacity(0.5)
                LegendView(sections: legendSections, filterState: filterState)
            }
            .padding(12)
        }
        .frame(width: 220)
        .frame(maxHeight: 640)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}
#endif
```

- [ ] **Step 3: 重写 `StudioToolbar.swift`**(View 选择器替 Theme 选择器)
```swift
#if targetEnvironment(macCatalyst)
import MapKit
import SwiftUI

struct StudioToolbar: View {
    @Bindable var viewContext: MapViewContext
    @Binding var aspect: CanvasAspect
    let onSnapshot: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu(viewContext.activeMapView?.name ?? "无视图") {
                ForEach(viewContext.allMapViews, id: \.id) { mv in
                    Button(mv.name) { viewContext.switchView(to: mv) }
                }
            }
            Menu("📐 \(aspect.rawValue)") {
                ForEach(CanvasAspect.allCases) { a in
                    Button(a.rawValue) { aspect = a }
                }
            }
            Divider().frame(height: 20)
            Button(action: onSnapshot) { Text("📸 截屏") }
                .keyboardShortcut("e", modifiers: .command)
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}
#endif
```

- [ ] **Step 4: 重写 `StudioOverlay.swift`**(吃 `viewContext`)
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioOverlay: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var watermark: String
    @Binding var aspect: CanvasAspect
    @Bindable var viewContext: MapViewContext

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                StudioToolbar(viewContext: viewContext, aspect: $aspect, onSnapshot: {})
                    .padding(.bottom, 24)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    StudioWatermark(text: watermark)
                }
                .padding(16)
            }
        }
    }
}
#endif
```

- [ ] **Step 5: 重写 `RootView.swift` 的 `StudioRootView`**(替换 `#if targetEnvironment(macCatalyst) struct StudioRootView … #else` 之间整块;`ExploreRootView`/`ToolbarView`/`Notification.Name` 不动)

```swift
#if targetEnvironment(macCatalyst)
struct StudioRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var datasets: [Dataset]
    @Query private var compounds: [Compound]
    @Query private var schools: [School]
    @Query private var pois: [POI]
    @Query private var areas: [Area]
    @Query private var styleRules: [StyleRule]
    @Query private var palettes: [Palette]
    @Query private var layersQuery: [Layer]

    @State private var filterState = DimensionFilterState()
    @State private var layerState = LayerState()
    @State private var viewContext: MapViewContext?
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var watermark: String = "@公众号名 · PropertyAtlas"
    @State private var aspect: CanvasAspect = .ratio16x9
    @State private var camera: MKMapCamera = .init(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 39.125, longitude: 117.205),
        fromDistance: 12000, pitch: 0, heading: 0
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var appState = AppState()
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    @State private var showCreateMenu = false

    var body: some View {
        let palettesById: [UUID: Palette] = Dictionary(uniqueKeysWithValues: palettes.map { ($0.id, $0) })
        let dsId = viewContext?.datasetIdValue ?? UUID()
        let activeMapView = viewContext?.activeMapView
        let activeTheme = viewContext?.activeTheme
        let activeRuleIds = Set(activeTheme?.styleRuleIds ?? [])
        let rulesForTheme = styleRules.filter { activeRuleIds.contains($0.id) }
        let visibility = viewContext?.visibility ?? ["compound": true, "school": true, "poi": true, "area": true]
        let primary = viewContext?.primaryFilter ?? PrimaryFilter(conditions: [], groupBy: nil)
        let normals = viewContext?.normalFilters ?? []

        // spotlight
        let relatedIds: [UUID] = appState.selectedRef.map {
            EdgeStore.relations(of: $0, datasetId: dsId, in: modelContext)
                .flatMap { $0.items.map(\.other.id) }
        } ?? []
        let highlight = SpotlightResolver.highlightedIds(
            selected: appState.selectedRef?.id, relatedIds: relatedIds,
            enabled: activeMapView?.spotlightOnSelect ?? false
        )

        let zoom = visibleRegion.map { ZoomLevel.from(region: $0) } ?? 12
        let _: Void = layerState.initializeIfNeeded(enabledIds: activeMapView?.enabledLayerIds ?? [])

        // ── 候选集(含坐标 + 图层归属)──
        let cands = buildCandidates(dsId: dsId, visibility: visibility)
        let namedLayers = layersForDataset(dsId).map {
            LayerEvaluator.NamedLayer(
                name: $0.name,
                layer: LayerEvaluator.ActiveLayer(
                    query: LayerQuery(staticRefsJSON: $0.staticRefsJSON, dynamicQueryJSON: $0.dynamicQueryJSON),
                    enabled: layerState.isEnabled($0.id), minZoom: $0.minZoom, maxZoom: $0.maxZoom
                )
            )
        }
        let evalCands = cands.map { LayerEvaluator.Candidate(id: $0.id, type: $0.type, entity: $0.entity) }
        let layerVisible = LayerEvaluator.visibleIds(
            layers: namedLayers.map(\.layer), zoom: zoom, candidates: evalCands
        )
        let membership = LayerEvaluator.membership(layers: namedLayers, zoom: zoom, candidates: evalCands)

        // ── 可见集(layer ∩ primary ∩ ¬chip 隐藏)──
        let visCands = cands.map {
            VisibilityResolver.Candidate(id: $0.id, entity: $0.entity, layerNames: membership[$0.id] ?? [])
        }
        let visibleIds = VisibilityResolver.visibleIds(
            candidates: visCands, layerVisible: layerVisible,
            primary: primary, normals: normals, filterState: filterState,
            context: modelContext, datasetId: dsId
        )

        // ── 分组染色 ──
        let palette = activeMapView?.paletteId.flatMap { palettesById[$0]?.colorsHex }
            ?? PaletteAssigner.highContrast
        let groupItems = cands
            .filter { visibleIds.contains($0.id) && $0.type != "area" }
            .map { GroupColorResolver.Item(id: $0.id, entity: $0.entity, layerNames: membership[$0.id] ?? []) }
        let groupColors = GroupColorResolver.colors(
            items: groupItems, groupBy: primary.groupBy, palette: palette,
            context: modelContext, datasetId: dsId
        )

        // ── 图例 sections(primary groupBy 彩色 + 每个 normal 灰)──
        let legendSections = buildLegendSections(
            cands: cands, visibleIds: visibleIds, membership: membership,
            primary: primary, normals: normals, palette: palette,
            groupColors: groupColors, dsId: dsId
        )

        // ── pins / overlays ──
        let pins = buildPins(
            cands: cands, visibleIds: visibleIds, groupColors: groupColors,
            theme: activeTheme, rules: rulesForTheme, palettes: palettesById, highlight: highlight
        )
        let (areaOverlays, styleMap) = buildAreaOverlays(
            areas: visibility["area"] == true ? areas.filter { $0.datasetId == dsId } : [],
            visibleIds: visibleIds, theme: activeTheme, rules: rulesForTheme, palettes: palettesById
        )
        let edgeLines = buildEdgeLines(labels: activeMapView?.drawEdgeLines ?? [], datasetId: dsId)
        let overlays = areaOverlays + edgeLines

        ZStack {
            MapContainerView(
                camera: $camera, overlays: overlays, annotations: pins,
                rendererFor: { overlay in
                    if let polygon = overlay as? MKPolygon, let style = styleMap[ObjectIdentifier(overlay)] {
                        return AreaOverlayRenderer(polygon: polygon, style: style)
                    }
                    return nil
                },
                onRegionChange: { visibleRegion = $0 },
                onSchoolSelect: { id in
                    if let id, let kind = idKind(for: id, in: pins) { appState.select(EntityRef(id: id, kind: kind)) }
                    else { appState.clearSelection() }
                },
                onLongPressCoordinate: { coord in
                    pendingCoordinate = coord
                    showCreateMenu = true
                }
            )
            .ignoresSafeArea()

            if let ctx = viewContext {
                StudioOverlay(
                    title: $title, subtitle: $subtitle, watermark: $watermark,
                    aspect: $aspect, viewContext: ctx
                )
            }

            HStack {
                Spacer()
                RightDrawer(appState: appState, datasetId: dsId)
                    .padding(.top, 80).padding(.trailing, 16).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .animation(.easeInOut(duration: 0.2), value: appState.selectedRef)

            HStack {
                LeftDrawerView(
                    legendSections: legendSections,
                    layers: layersForDataset(dsId),
                    currentZoom: zoom,
                    filterState: filterState,
                    layerState: layerState
                )
                .padding(.top, 80).padding(.leading, 16)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onChange(of: viewContext?.activeMapView?.id) { _, _ in
            layerState.resetForTheme(enabledIds: viewContext?.activeMapView?.enabledLayerIds ?? [])
            filterState.reset()
        }
        .confirmationDialog("新建实体", isPresented: $showCreateMenu, titleVisibility: .visible) {
            Button("+ 小区") { createPin(.compound) }
            Button("+ 学校") { createPin(.school) }
            Button("+ POI") { createPin(.poi) }
            Button("取消", role: .cancel) {}
        }
        .onAppear { ensureViewContext() }
        .onChange(of: datasets.first?.id) { _, _ in ensureViewContext() }
    }

    // MARK: - 候选

    private struct Cand {
        let id: UUID
        let type: String
        let name: String
        let entity: StyleEntity
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
    }

    private func buildCandidates(dsId: UUID, visibility: [String: Bool]) -> [Cand] {
        var out: [Cand] = []
        if visibility["compound"] == true {
            for c in compounds where !c.deleted && c.datasetId == dsId {
                out.append(.init(id: c.id, type: "compound", name: c.name, entity: c.styleEntity,
                                 coordinate: c.coordinate, hasCoordinate: c.latitude != 0 || c.longitude != 0))
            }
        }
        if visibility["school"] == true {
            for s in schools where !s.deleted && s.datasetId == dsId {
                out.append(.init(id: s.id, type: "school", name: s.name, entity: s.styleEntity,
                                 coordinate: s.coordinate, hasCoordinate: s.latitude != 0 || s.longitude != 0))
            }
        }
        if visibility["poi"] == true {
            for p in pois where !p.deleted && p.datasetId == dsId {
                out.append(.init(id: p.id, type: "poi", name: p.name, entity: p.styleEntity,
                                 coordinate: p.coordinate, hasCoordinate: p.latitude != 0 || p.longitude != 0))
            }
        }
        // areas 加入候选(供 layer 归属/可见集);无点坐标,buildPins 跳过
        if visibility["area"] == true {
            for a in areas where !a.deleted && a.datasetId == dsId {
                out.append(.init(id: a.id, type: "area", name: a.name, entity: a.styleEntity,
                                 coordinate: CLLocationCoordinate2D(), hasCoordinate: false))
            }
        }
        return out
    }

    // MARK: - 图例

    private func buildLegendSections(
        cands: [Cand], visibleIds: Set<UUID>, membership: [UUID: [String]],
        primary: PrimaryFilter, normals: [NormalFilter], palette: [String],
        groupColors: [UUID: String], dsId: UUID
    ) -> [LegendSection] {
        // 仅统计可见实体(含 area)
        let items = cands.filter { visibleIds.contains($0.id) }.map {
            DimensionLegendCounter.Item(id: $0.id, entity: $0.entity, coordinate: $0.coordinate,
                                        layerNames: membership[$0.id] ?? [])
        }
        var sections: [LegendSection] = []

        if let gb = primary.groupBy {
            // groupBy 维度的值 → palette 色(与 pin 一致):由全屏 distinct 值分配
            let distinct = items.flatMap { it -> [String] in
                gb.resolve(MapDimension.Input(entity: it.entity, layerNames: it.layerNames,
                                              context: modelContext, datasetId: dsId)).sorted().prefix(1).map { $0 }
            }
            let assign = PaletteAssigner.assign(values: Array(Set(distinct)), palette: palette)
            let rows = DimensionLegendCounter.rows(
                dimension: gb, items: items, region: visibleRegion,
                context: modelContext, datasetId: dsId,
                swatch: { assign[$0] ?? "#8E8E93" }
            )
            sections.append(LegendSection(title: legendTitle(for: gb, fallback: "分组"), dimensionKey: gb.key, rows: rows))
        }

        for nf in normals {
            let rows = DimensionLegendCounter.rows(
                dimension: nf.dimension, items: items, region: visibleRegion,
                context: modelContext, datasetId: dsId,
                swatch: { _ in "#8E8E93" }   // normal filter 不参与染色 → 中性灰
            )
            sections.append(LegendSection(title: nf.name, dimensionKey: nf.dimension.key, rows: rows))
        }
        return sections
    }

    private func legendTitle(for dim: MapDimension, fallback: String) -> String {
        switch dim.kind {
        case .field: return dim.fieldKey ?? fallback
        case .layer: return "图层"
        case .entityType: return "类型"
        case .edgeField: return dim.edgeLabel ?? fallback
        }
    }

    // MARK: - pins / overlays

    private func buildPins(
        cands: [Cand], visibleIds: Set<UUID>, groupColors: [UUID: String],
        theme: Theme?, rules: [StyleRule], palettes: [UUID: Palette], highlight: Set<UUID>?
    ) -> [MKAnnotation] {
        var result: [MKAnnotation] = []
        for c in cands where c.type != "area" && c.hasCoordinate && visibleIds.contains(c.id) {
            let style = StyleResolver.resolvePin(
                entity: c.entity, theme: theme, rules: rules, palettes: palettes,
                groupFillHex: groupColors[c.id]
            )
            let pin = PinAnnotation(entityId: c.id, entityType: c.type, name: c.name,
                                    coordinate: c.coordinate, style: style)
            if let highlight {
                pin.highlighted = highlight.contains(c.id)
                pin.dimmed = !highlight.contains(c.id)
            }
            result.append(pin)
        }
        return result
    }

    private func buildAreaOverlays(
        areas: [Area], visibleIds: Set<UUID>, theme: Theme?, rules: [StyleRule], palettes: [UUID: Palette]
    ) -> ([MKOverlay], [ObjectIdentifier: AreaStyle]) {
        var overlays: [MKOverlay] = []
        var map: [ObjectIdentifier: AreaStyle] = [:]
        for a in areas where !a.deleted && visibleIds.contains(a.id) {
            let style = StyleResolver.resolveArea(entity: a.styleEntity, theme: theme, rules: rules, palettes: palettes)
            if let r = AreaOverlayFactory.makeOverlay(for: a, style: style) {
                overlays.append(r.overlay)
                map[ObjectIdentifier(r.overlay)] = r.style
            }
        }
        return (overlays, map)
    }

    private func createPin(_ kind: EntityKind) {
        guard let coord = pendingCoordinate, let dsId = viewContext?.datasetIdValue else { return }
        let ref = EntityWriter.createPin(
            kind: kind, datasetId: dsId, name: "未命名",
            latitude: coord.latitude, longitude: coord.longitude, in: modelContext
        )
        appState.select(ref)
        appState.beginEditing()
    }

    private func idKind(for id: UUID, in pins: [MKAnnotation]) -> EntityKind? {
        for case let p as PinAnnotation in pins where p.entityId == id {
            return EntityKind(rawValue: p.entityType)
        }
        return nil
    }

    private func buildEdgeLines(labels: [String], datasetId: UUID) -> [MKOverlay] {
        guard !labels.isEmpty else { return [] }
        let labelSet = Set(labels)
        let fd = FetchDescriptor<Edge>(predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted })
        let edges = ((try? modelContext.fetch(fd)) ?? []).filter { labelSet.contains($0.label) }
        var segs: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        for e in edges {
            guard let a = EntityReader.coordinate(EntityRef(id: e.fromId, kind: EntityKind(rawValue: e.fromType) ?? .poi), in: modelContext),
                  let b = EntityReader.coordinate(EntityRef(id: e.toId, kind: EntityKind(rawValue: e.toType) ?? .poi), in: modelContext)
            else { continue }
            segs.append((a, b))
        }
        return EdgeLineFactory.polylines(from: segs)
    }

    private func ensureViewContext() {
        guard viewContext == nil, let ds = datasets.first(where: { !$0.deleted }) else { return }
        viewContext = MapViewContext(dataset: ds, modelContext: modelContext)
        title = viewContext?.activeMapView?.copyTitle ?? ""
        subtitle = viewContext?.activeMapView?.copySubtitle ?? ""
    }

    private func layersForDataset(_ dsId: UUID) -> [Layer] {
        layersQuery.filter { $0.datasetId == dsId && !$0.deleted }.sorted { $0.zIndex < $1.zIndex }
    }
}
#else
struct StudioRootView: View {
    var body: some View {
        Text("Studio Mode 仅在 Mac 端可用。")
    }
}
#endif
```
> 删掉旧的 `legendItems`/`fieldKeys`/`visibilityFromTheme` 方法(已被新私有方法取代)。`layersForDataset` 现按 `zIndex` 排序(渲染叠放序)。

- [ ] **Step 6: 编译**(整 app)

Run: `cd <worktree>/PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -25`
Expected: BUILD SUCCEEDED(旧 FilterState/LegendCounter 仍在但 RootView 不再引用)。若报 `c.styleEntity`/`a.styleEntity`/`Area.coordinate` 等签名不符,按真实成员适配。

- [ ] **Step 7: 跑既有引擎单测**(确认未回归)

Run: `cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/VisibilityResolverTests -only-testing:PropertyAtlasTests/DimensionLegendCounterTests -only-testing:PropertyAtlasTests/GroupColorResolverTests -only-testing:PropertyAtlasTests/MapViewContextTests 2>&1 | tail -20`
Expected: PASS。

- [ ] **Step 8: 提交** `git -c commit.gpgsign=false commit -am "feat(studio): swap RootView+drawer+toolbar to MapView/Dimension engine"`

---

### Task 6: 删除旧过滤/图例引擎

**Files:** Delete `States/FilterState.swift`、`States/FilterPredicate.swift`、`MapRender/LegendCounter.swift`、`PropertyAtlasTests/States/FilterStateTests.swift`、`PropertyAtlasTests/States/FilterPredicateTests.swift`、`PropertyAtlasTests/MapRender/LegendCounterTests.swift`

- [ ] **Step 1: 确认无残留引用**

Run: `cd <worktree> && grep -rn "FilterState\|FilterPredicate\|LegendCounter\b" PropertyAtlas/PropertyAtlas PropertyAtlasTests 2>/dev/null | grep -v "DimensionFilterState\|DimensionLegendCounter"`
Expected: 空(若有,先在该处改用新引擎/删除)。`LegendSwatch` 保留(未用但留待 P9)。

- [ ] **Step 2: 删除文件**
```bash
cd <worktree>/PropertyAtlas/PropertyAtlas && rm States/FilterState.swift States/FilterPredicate.swift MapRender/LegendCounter.swift
cd <worktree>/PropertyAtlas/PropertyAtlasTests && rm States/FilterStateTests.swift States/FilterPredicateTests.swift MapRender/LegendCounterTests.swift
```

- [ ] **Step 3: 编译 + 全量测试**

Run: `cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -20`
Expected: BUILD SUCCEEDED + 全过(删掉的 3 套件不再存在)。

- [ ] **Step 4: 提交** `git -c commit.gpgsign=false commit -am "refactor(studio): delete legacy FilterState/FilterPredicate/LegendCounter + tests"`

---

### Task 7: 剥离 Theme 9 字段 + migrator 改写(schema 破坏)

**Files:** Modify `Models/Style/Theme.swift`、`DataKit/LegacyMigrator.swift`; Test `PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

把 9 字段从 `Theme` 删除。migrator 不再往 `Theme` 写这些字段;改为在 `seedMapViews` 里把原本的 per-theme 字面量(visibility/copy/camera/bg/drawEdge/spotlight)**直接写到对应 MapView**。

- [ ] **Step 1: 读现状定位**

读 `LegacyMigrator.swift` 的 `seedPalettesThemesLayers`:记下每个 theme(t1-t4)当前对 9 字段的赋值(visibilityJSON 的 4 段不同字符串、defaultEnabledLayerIds、copyTitle/Subtitle、cameraPresetId、bgMapStyle、drawEdgeLines、spotlightOnSelect)。`seedMapViews` 当前从 `t.<field>` 拷这些值——删字段后无法再读 theme,需要把字面量内联到 view 创建处(按 theme 顺序/名字一一对应)。

- [ ] **Step 2: 改 migrator(先于删字段,保持可编译的中间态可跳过——本任务一次性改完再编译)**

在 `seedMapViews` 里,改为按 theme **索引/名字**赋字面量(不再 `v.xxx = t.xxx` 读已删字段)。建议:把每个 theme 的视图配置抽成本地数组,例如:
```swift
// 在 seedPalettesThemesLayers 内,建 themes 后,定义 per-view 配置(原 theme 上的 9 字段值搬到这里)
struct ViewSeed {
    let visibilityJSON: String
    let copyTitle: String?
    let copySubtitle: String?
    let copyWatermark: String?
    let bgMapStyle: String
    let drawEdgeLines: [String]
    let spotlight: Bool
}
let viewSeeds: [ViewSeed] = [
    // t1 …(把原 t1.visibilityJSON 等字面量搬来)
    // t2 …(原"学区分布图"/"2026 招生季"等)
    // t3 …, t4 …
]
```
然后 `seedMapViews(dataset:defaultLayerId:themes:palette:viewSeeds:cameraPresetId:in:)` 用 `viewSeeds[idx]` + `themes[idx].cameraPresetId`(cameraPresetId 仍在 Theme?——不,它要被删;改为也放进 ViewSeed 或单独传)。**cameraPresetId** 也移入 ViewSeed(`cameraPresetId: UUID?`)。
> 注意:`defaultEnabledLayerIds` 不需要——View 用 `enabledLayerIds = [defaultLayerId]` 已覆盖。删 Theme.defaultEnabledLayerIds 即可,无需搬。
> `seedMapViews` 里删除所有 `v.xxx = t.xxx`(读 theme 9 字段)的行,改用 viewSeeds[idx] / 传入的 cameraPresetId。保留 `v.name = t.name`、`v.enabledLayerIds`、`v.primaryFilterJSON`、`v.normalFiltersJSON`、`v.paletteId`、`v.sortOrder`、`v.isActive`。

同时删除 `seedPalethesThemesLayers` 里对 `t1..t4` 的 9 字段赋值行(visibilityJSON/defaultEnabledLayerIds/copy*/cameraPresetId/bgMapStyle/drawEdgeLines/spotlightOnSelect)。`styleRuleIds`/`defaultStylesJSON`/`name`/`sortOrder`/`showLegend`/`isActive` 保留。

- [ ] **Step 3: 删 Theme 字段** —— `Theme.swift` 删除这 9 行:
```
var cameraPresetId: UUID?
var visibilityJSON: String = …
var defaultEnabledLayerIds: [UUID] = []
var spotlightOnSelect: Bool = true
var drawEdgeLines: [String] = []
var bgMapStyle: String = "standard"
var copyTitle: String?
var copySubtitle: String?
var copyWatermark: String?
```
保留:`id/datasetId/name/isActive/styleRuleIds/defaultStylesJSON/showLegend/sortOrder/version/createdAt/updatedAt/deleted`。

- [ ] **Step 4: 修测试** —— `LegacyMigratorTests` 里任何断言 `theme.visibilityJSON`/`copyTitle` 等的用例,改为断言对应 `MapView` 字段。`seedsMapViewsWithDefaults`/`seededMapViewHasVisibilityJSON` 改为不依赖 theme 字段。grep 确认无测试再读已删 Theme 字段:
`cd <worktree> && grep -rn "\.visibilityJSON\|\.defaultEnabledLayerIds\|\.drawEdgeLines\|\.copyTitle\|\.copySubtitle\|\.copyWatermark\|\.bgMapStyle\|\.cameraPresetId\|\.spotlightOnSelect" PropertyAtlas/PropertyAtlasTests | grep -i theme`

- [ ] **Step 5: 编译 + 全量测试**

Run: `cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -25`
Expected: BUILD SUCCEEDED + 全过。
> grep 整库确认无生产码再读已删字段:`cd <worktree> && grep -rn "theme.*\.visibilityJSON\|activeTheme?\.copyTitle\|\.drawEdgeLines\|\.spotlightOnSelect\|\.defaultEnabledLayerIds\|\.cameraPresetId\|\.bgMapStyle" PropertyAtlas/PropertyAtlas`(应只剩 MapView 相关命中)。

- [ ] **Step 6: 提交** `git -c commit.gpgsign=false commit -am "refactor(model): strip 9 global fields from Theme → MapView (schema break)"`

---

### Task 8: 全量测试 + 清库重迁 smoke + CLAUDE.md

**Files:** Modify `CLAUDE.md`

- [ ] **Step 1: 全量单测**

Run: `cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 2: 清库重迁 smoke**(破坏性 —— schema 变更需验证迁移)

控制者(主 agent)执行,**非 subagent**:
1. 备份现有 store:找到 app 的 SwiftData store(`default.store` 等),拷贝到带时间戳的备份目录。
2. 删除 store 文件(`.store`/`.store-shm`/`.store-wal`)。
3. 用 worktree 的真实构建启动 **两次**(launch 1:seed JSON→Legacy* 模型;launch 2:LegacyMigrator→新 entity)。用 `xcodebuild -showBuildSettings | grep BUILT_PRODUCTS_DIR` 取 worktree 构建路径,避免 `open` 抓陈旧 DerivedData(见 memory: p5-smoke-remigrate-procedure)。
4. 验证:Studio 起得来;视图选择器列出 4 个 View;pin 显示(重/普颜色经 StyleRule);图例 chip 可隐藏;切换 View 重置图层/过滤。

> 此步骤需主 agent 与用户协作(用户授权删库)。subagent-driven 执行到此暂停,由主 agent 处理。

- [ ] **Step 3: 更新 CLAUDE.md** —— P8a 节点后加:
```markdown
> **P8b (2026-06-01) 完成后**: 视图驱动集成 + 删旧。RootView/抽屉/工具栏切到
> `MapViewContext`(active MapView + 派生 active theme = 启用图层 zIndex 最高且有 themeId 者,
> 回退 dataset.activeThemeId)。可见集走 `VisibilityResolver`,图例走 `DimensionLegendCounter`
> (primary groupBy 彩色 chip[PaletteAssigner] + 每 NormalFilter 灰 chip + 视口/总数),
> 染色走 `GroupColorResolver`→`resolvePin(groupFillHex:)`。`DimensionFilterState` 替 FilterState。
> 新增 `ValueFormat`(原 FilterPredicate.display/key)、`GroupColorResolver`、`MapViewContext`、
> `LayerEvaluator.membership`、`MapView.visibilityJSON`。**删**:FilterState/FilterPredicate/旧 LegendCounter + 测试。
> **Theme 删 9 字段**(visibilityJSON/defaultEnabledLayerIds/drawEdgeLines/copy*/bgMapStyle/cameraPresetId/
> spotlightOnSelect)→ 全部移到 MapView;migrator seed 直接写视图字面量。Theme 仅剩
> styleRuleIds/defaultStylesJSON/showLegend/name/sortOrder/isActive。保留(待 P9):FilterFieldConfig @Model、
> LegendSwatch、逐图层 theme(本期单 active theme)。后续 P9:Settings 编辑 UI + CloudKit .private + 删 Legacy*。
```
并把计划列表的 P8b 行标"已完成"。

- [ ] **Step 4: 提交** `git -c commit.gpgsign=false commit -am "docs(claude): note P8b view-driven integration completion"`

---

## Self-Review

- **Spec 覆盖**:§2(View 容器驱动 + Theme 下沉,本期单 active theme)、§4(PrimaryFilter conditions+groupBy / NormalFilter legend+count → VisibilityResolver+DimensionLegendCounter)、§5(染色优先级 override>groupBy palette>theme base,经 GroupColorResolver+groupFillHex)、§6(PaletteAssigner 同屏去重)、§7(可见集 layer∩primary∩¬chip)、§8(Theme 字段移 MapView、FilterFieldConfig 废弃但保留 @Model、PaletteResolver→PaletteAssigner、LegendCounter→DimensionLegendCounter、FilterState→DimensionFilterState)。延后:逐图层 theme、FilterFieldConfig/LegendSwatch @Model 删除(P9)、Settings UI(P9)、相邻空间不同色。
- **类型一致**:`LegendSection`(T5 定义,LeftDrawerView/LegendView 用)、`LayerEvaluator.NamedLayer`/`membership`(T1)、`GroupColorResolver.Item`/`colors`(T3)、`MapViewContext`(T4,RootView/Toolbar/Overlay 用)、`ValueFormat`(T2,MapDimension 用)、`MapView.visibilityJSON`(T0)、`resolvePin(groupFillHex:)`(P8a)。
- **占位扫描**:无 TBD;每任务完整代码。T7 的 viewSeeds 字面量需实现期从现有 migrator 抄真实值(已在 Step 1 要求定位)。
- **风险**:① RootView 是大原子切换,无 SwiftUI 单测 → 靠编译 + 引擎单测 + 清库 smoke。② `StyleEntity`/`Area.coordinate`/各实体 `.styleEntity` 成员若签名与示例不符,实现期适配。③ T7 schema 破坏 → 必须清库重迁(CloudKit .none,轻量迁移删列)。④ membership 语义:match-all 层使全员归属;受约束层只列真实成员(比 visibleIds 的"未覆盖类型默认可见"严格——但 layerNames 仅用于 dimension 投影 + chip,不影响 layerVisible 判定,故安全)。⑤ 图例 normal filter 用中性灰(spec:不参与染色);pin 颜色仍由 StyleRule/groupBy 决定,无回归。
