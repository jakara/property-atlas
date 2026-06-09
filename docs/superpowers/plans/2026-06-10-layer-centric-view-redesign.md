# 图层中心化视图重设计 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「视图(MapView)聚合多图层 + 单 active」模型重构为「Layer = 单一实体类型 + 自持过滤/样式/染色,多图层同屏 OR、层内过滤 AND」。

**Architecture:** 合并 `MapView` 字段进 `Layer`(删 `MapView` @Model);成员由 `entityType + 过滤器`派生(删 `entity.layerId`);新 `LayerResolver` 取代 `VisibilityResolver`+`LayerEvaluator`,返回 `entity→命中图层` 映射(zIndex 最高);全局展示设置上提 `Dataset`;左抽屉多图层 toggle + 多段图例。保实体,删重建配置(启动幂等迁移 `LayerMigratorV3`)。

**Tech Stack:** SwiftUI · SwiftData · MapKit · Swift Testing · Mac Catalyst。

**Spec:** `docs/superpowers/specs/2026-06-10-layer-centric-view-redesign.md`

**关键事实(已确认):** spec 全部 4 节;保 `Layer` 名;`ViewEntityStyle`/`ViewStyleRule` 改键 `viewId`→`layerId`;道路 per-road 颜色走 `entity.styleFillHex`(override,链末端,保留);道路类内叠放仍用 `roadDrawPriority`(同层内按色排,与跨层 zIndex 正交);多图层 chip 隐藏态按 `layerId|dimKey` 命名空间共用单一 `DimensionFilterState`。

**构建命令(每个 build 步骤用):**
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas
xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' build 2>&1 | tail -5
```
期望末行:`** BUILD SUCCEEDED **`。注意:SourceKit 跨文件诊断(Cannot find X)是噪声,以 `BUILD SUCCEEDED` 为准。

**测试命令:**
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas
xcodebuild test -project PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -only-testing:PropertyAtlasTests/<TestType> 2>&1 | tail -15
```

---

## 阶段构成与「绿色」约定

模型 cutover 是原子的(删 `MapView` 同时改 ~117 处引用),无法逐文件保持可编译。本计划分 5 阶段:

- **Phase A(纯逻辑,加法,逐任务绿)**:Dataset 字段、Layer 字段、`LayerResolver`+测试、过滤器去 entityType。每个任务独立 build 绿。
- **Phase B(模型 cutover,作为一个单元绿)**:删 `MapView`、改键样式表、删 `entity.layerId`、重写 `RootView`/`LayerContext`/抽屉、重写 seed + 新迁移器。**B 内部任务按顺序做,build 仅在 B 末尾整体绿**(每个 B 任务结尾标注「(中间态,不单独 build)」或「(B 收口,build 绿)」)。
- **Phase C(设置 UI)**:图层 CRUD tab + 展示 tab。逐任务绿。
- **Phase D(迁移验证)**:清库重迁 smoke + 既有库验证。
- **Phase E(收尾)**:删死代码、删旧测试、最终 build+test 绿。

---

## File Structure

**新建:**
- `PropertyAtlas/PropertyAtlas/MapRender/LayerResolver.swift` — 可见集 + entity→图层映射(取代 `VisibilityResolver`+`LayerEvaluator`)。
- `PropertyAtlas/PropertyAtlas/DataKit/LayerMigratorV3.swift` — 启动幂等:删旧配置 + seed 5 默认图层 + 搬展示设置到 Dataset。
- `PropertyAtlas/PropertyAtlasTests/LayerResolverTests.swift`
- `PropertyAtlas/PropertyAtlasTests/LayerMigratorV3Tests.swift`
- `PropertyAtlas/PropertyAtlas/Studio/Settings/DisplaySettingsTab.swift` — dataset 级展示设置。

**改 @Model:**
- `Models/Display/Layer.swift` — 吸收 MapView 字段 + `entityType`;删 `isDefault`/`themeId`/`staticRefsJSON`/`dynamicQueryJSON`。
- `Models/Core/Dataset.swift` — +展示字段 + `layerModelV3` 闸。
- `Models/Display/ViewEntityStyle.swift`、`Models/Display/ViewStyleRule.swift` — `viewId`→`layerId`。
- `DataKit/ModelSchema.swift` — 删 `MapView.self`。

**删文件:**
- `Models/Display/MapView.swift`、`MapRender/VisibilityResolver.swift`、`MapRender/LayerEvaluator.swift`、`States/LayerState.swift`。
- `MapRender/MapViewContext.swift` → 重命名/重写为 `MapRender/LayerContext.swift`。

**重写:**
- `RootView.swift`(渲染管线)、`States/PrimaryFilter.swift`(去 entityType)、`DataKit/LegacyMigrator.swift`(seed)、`States/SeedImporter.swift`(run 路径 + 道路/边界 seed)、抽屉 `LeftDrawerView`/`LayersView`、`StudioToolbar`(删视图菜单)、设置 `SettingsSheet`/`ViewSettingsTab`/`LayerSettingsTab`/`ViewBasicSection`/`ViewFilterSections`/`ViewStyleSection`/`EntityDefaultStyleEditor`/`ViewConfigCodec`。

---

# Phase A — 纯逻辑基础(逐任务绿)

### Task A1: Dataset 增展示字段 + 迁移闸

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift`

- [ ] **Step 1: 加字段**

在 `Dataset` 现有字段后(`roadLinesSeededV1` 之后、`sortOrder` 之前)插入:

```swift
    // 全局展示设置(原 MapView 持有;多图层同屏后上提 dataset)
    var studioMapStyleRaw: String = "mutedLight"
    var bgMapStyle: String = "standard"
    var canvasAspectRaw: String = "16:9"
    var poiEnabled: Bool = false
    var poiCategoriesRaw: String = ""
    var spotlightOnSelect: Bool = true
    var drawEdgeLines: [String] = []
    var copyTitle: String?
    var copySubtitle: String?
    var copyWatermark: String?
    var watermarkQRData: Data?
    // 图层中心化重构迁移闸(LayerMigratorV3)
    var layerModelV3: Bool = false
```

- [ ] **Step 2: build 绿**

Run 构建命令。Expected: `** BUILD SUCCEEDED **`(纯加法,所有默认值,CloudKit 兼容)。

- [ ] **Step 3: commit**

```bash
cd /Users/fujie/projects/天津买房
git add PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift
git commit -m "feat(dataset): add global presentation fields + layerModelV3 gate"
```

---

### Task A2: Layer 吸收 MapView 字段 + entityType

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Models/Display/Layer.swift`

新模型保留旧 `Layer` 仍被引用的字段(`enabled`/`zIndex`/`sortOrder`/`minZoom`/`maxZoom`/`iconSF`/`colorHex`),**暂时保留** `isDefault`/`themeId`/`staticRefsJSON`/`dynamicQueryJSON`(Phase B 删,避免 A 阶段 break 现有 seed/RootView 引用),**新增**吸收字段。

- [ ] **Step 1: 改 Layer.swift**

```swift
import Foundation
import SwiftData

@Model
final class Layer {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var iconSF: String?
    var colorHex: String?
    // 新:图层 = 单一实体类型(创建时定死)
    var entityType: String = "compound"
    // 新:吸收自 MapView 的视图配置
    var primaryFilterJSON: String = #"{"conditions":[],"groupBy":null}"#
    var normalFiltersJSON: String = "[]"
    var hiddenChipsJSON: String = "{}"
    var paletteHex: [String] = []
    var showLegend: Bool = true
    // 既有
    var staticRefsJSON: String?       // deprecated, Phase B 删
    var dynamicQueryJSON: String?     // deprecated, Phase B 删
    var minZoom: Double?
    var maxZoom: Double?
    var isDefault: Bool = false       // deprecated, Phase B 删
    var enabled: Bool = true
    var sortOrder: Int = 0
    var zIndex: Int = 0
    var themeId: UUID?                // deprecated, Phase B 删
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), datasetId: UUID, name: String, entityType: String = "compound") {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.entityType = entityType
    }
}
```

- [ ] **Step 2: build 绿**

Run 构建命令。Expected: `** BUILD SUCCEEDED **`(init 加了带默认值的 `entityType` 形参,旧 `Layer(datasetId:name:)` 调用点不变)。

- [ ] **Step 3: commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Display/Layer.swift
git commit -m "feat(layer): absorb MapView view-config fields + entityType (additive)"
```

---

### Task A3: 过滤器去 entityType

`PrimaryFilter`/`NormalFilter` 的 `entityType` 字段在新模型冗余(类型由图层定)。删字段;解码保持向后兼容(忽略旧 JSON 的 entityType)。本任务会让 `VisibilityResolver`/`RootView`/`seedMapViews` 暂时引用不存在的成员——故同任务内**临时**用 `_ = ` 屏蔽?不行。改法:本任务只改 `PrimaryFilter.swift`,并就地修正**直接编译依赖**(`VisibilityResolver`、`RootView` 的 `primary.entityType`/`nf.entityType`、`LegacyMigrator.seedMapViews` 的 `entityType:` 实参)。这些代码 Phase B 会重写,这里只做「能编译」的最小改动。

**Files:**
- Modify: `States/PrimaryFilter.swift`
- Modify: `MapRender/VisibilityResolver.swift`
- Modify: `RootView.swift`
- Modify: `DataKit/LegacyMigrator.swift`

- [ ] **Step 1: PrimaryFilter.swift 删 entityType**

把 `PrimaryFilter` 改为:

```swift
struct PrimaryFilter: Codable, Equatable {
    var conditions: [FilterCondition]
    var groupBy: MapDimension?

    @MainActor
    func matches(_ input: MapDimension.Input) -> Bool {
        for c in conditions where !c.evaluate(input) { return false }
        return true
    }

    @MainActor
    func groupValues(_ input: MapDimension.Input) -> [String] {
        groupBy?.resolve(input) ?? []
    }
}

extension PrimaryFilter {
    enum CodingKeys: String, CodingKey { case conditions, groupBy }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        conditions = try c.decodeIfPresent([FilterCondition].self, forKey: .conditions) ?? []
        groupBy = try c.decodeIfPresent(MapDimension.self, forKey: .groupBy)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(conditions, forKey: .conditions)
        try c.encodeIfPresent(groupBy, forKey: .groupBy)
    }
}
```

`NormalFilter` 改为(删 entityType,保留容错解码):

```swift
struct NormalFilter: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var dimension: MapDimension

    init(id: UUID = UUID(), name: String, dimension: MapDimension) {
        self.id = id
        self.name = name
        self.dimension = dimension
    }
}

extension NormalFilter {
    enum CodingKeys: String, CodingKey { case id, name, dimension }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        dimension = try c.decode(MapDimension.self, forKey: .dimension)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(dimension, forKey: .dimension)
    }
}
```

- [ ] **Step 2: VisibilityResolver.swift 改为类型无关(临时,Phase B 删整个文件)**

把 `visibleIds`/`isHiddenByAnyChip` 里所有 `primary.entityType == t` 守卫去掉(主过滤器现对全部候选生效),`for nf in normals where nf.entityType == t` 改成 `for nf in normals`:

```swift
        for c in candidates {
            guard layerVisible.contains(c.id) else { continue }
            let input = MapDimension.Input(
                entity: c.entity, layerNames: c.layerNames, context: context, datasetId: datasetId,
                edgeProjection: edgeProjection, cache: cache
            )
            if !primary.matches(input) { continue }
            if isHiddenByAnyChip(input: input, primary: primary, normals: normals, filterState: filterState) { continue }
            out.insert(c.id)
        }
```
```swift
    private static func isHiddenByAnyChip(
        input: MapDimension.Input,
        primary: PrimaryFilter, normals: [NormalFilter], filterState: DimensionFilterState
    ) -> Bool {
        if let gb = primary.groupBy {
            for v in gb.resolve(input) where filterState.isHidden(dimensionKey: gb.key, value: v) { return true }
        }
        for nf in normals {
            for v in nf.dimension.resolve(input) where filterState.isHidden(dimensionKey: nf.dimension.key, value: v) { return true }
        }
        return false
    }
```
并删 `visibleIds` 签名里已不需要的 `t`(其调用 `isHiddenByAnyChip` 去掉 `t:` 实参)。

> 注:这会改变旧路径行为(主过滤现作用全类型),但旧路径 Phase B 即删,A 阶段只需编译+不崩。

- [ ] **Step 3: RootView.swift 改 entityType 引用(临时)**

`rebuildContent` 内 groupItems 过滤(约 749 行):
```swift
        let groupItems = cands
            .filter { visibleIds.contains($0.id) }
            .map { GroupColorResolver.Item(id: $0.id, entity: $0.entity, layerNames: membership[$0.id] ?? []) }
```
`buildLegendSpecs` 内对 `primary.entityType` / `nf.entityType` 的引用(约 804、813 行)改为传空串:
```swift
            let entries = entriesFor(visibleIds, gb, entityType: "", prefixOne: true)
```
```swift
            let entries = entriesFor(normalLegendIds, nf.dimension, entityType: "", prefixOne: false)
```

- [ ] **Step 4: LegacyMigrator.swift seedMapViews 去 entityType 实参**

`fieldFilter` 改为不传 entityType:
```swift
        func fieldFilter(_ name: String, _ key: String) -> NormalFilter {
            NormalFilter(name: name, dimension: MapDimension(kind: .field, fieldKey: key, fieldSource: "base"))
        }
        let normals: [NormalFilter] = [
            fieldFilter("精装类型", "finishType"),
            fieldFilter("阶段", "category"),
            fieldFilter("POI 类型", "category"),
            fieldFilter("区域类型", "category"),
            fieldFilter("等级", "grade"),
            fieldFilter("新房/二手", "isNewHouse"),
            fieldFilter("学制", "form"),
        ]
```

- [ ] **Step 5: build 绿**

Run 构建命令。Expected: `** BUILD SUCCEEDED **`。若报其它 `entityType` 残留引用,grep 修正:
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas/PropertyAtlas
grep -rn "\.entityType" --include="*.swift" States Studio | grep -i "primary\|normalFilter\|nf\."
```

- [ ] **Step 6: commit**

```bash
git add -A && git commit -m "refactor(filter): drop entityType from PrimaryFilter/NormalFilter"
```

---

### Task A4: `LayerResolver` + 测试

新解析器:输入候选(全 4 类)+ 活跃图层,输出 `entityId → 命中图层 id`(zIndex 最高)。取代 `VisibilityResolver`+`LayerEvaluator`(Phase B 删)。chip 隐藏键按 `layerId|dimKey` 命名空间。

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/LayerResolver.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/LayerResolverTests.swift`

- [ ] **Step 1: 写 LayerResolver.swift**

```swift
import Foundation
import SwiftData

/// 图层中心化可见性:每个候选实体落到「类型匹配 + 层内 AND 过滤通过 + chip 未隐藏」的
/// 启用图层中 zIndex 最高者。返回 entityId → 命中图层 id。多图层之间天然 OR(并集 = 映射 keys)。
@MainActor
enum LayerResolver {
    struct Candidate {
        let id: UUID
        let entity: StyleEntity
    }

    struct ActiveLayer {
        let id: UUID
        let name: String
        let entityType: String
        let zIndex: Int
        let enabled: Bool
        let minZoom: Double?
        let maxZoom: Double?
        let primary: PrimaryFilter
        let normals: [NormalFilter]

        func isActive(at zoom: Double) -> Bool {
            guard enabled else { return false }
            if let minZoom, zoom < minZoom { return false }
            if let maxZoom, zoom > maxZoom { return false }
            return true
        }
    }

    /// entityId → 命中图层 id(zIndex 最高)。未命中任何图层的实体不在结果里(= 不可见)。
    static func resolve(
        candidates: [Candidate],
        layers: [ActiveLayer],
        zoom: Double,
        filterState: DimensionFilterState,
        context: ModelContext?,
        datasetId: UUID?,
        edgeProjection: EdgeProjection? = nil,
        cache: DimResolveCache? = nil
    ) -> [UUID: UUID] {
        let active = layers.filter { $0.isActive(at: zoom) }
        guard !active.isEmpty else { return [:] }
        var winner: [UUID: (layerId: UUID, zIndex: Int)] = [:]
        for c in candidates {
            let type = c.entity.entityType
            for layer in active where layer.entityType == type {
                let input = MapDimension.Input(
                    entity: c.entity, layerNames: [layer.name], context: context, datasetId: datasetId,
                    edgeProjection: edgeProjection, cache: cache
                )
                guard layer.primary.matches(input) else { continue }
                if isHidden(input: input, layer: layer, filterState: filterState) { continue }
                if let existing = winner[c.id], existing.zIndex >= layer.zIndex { continue }
                winner[c.id] = (layer.id, layer.zIndex)
            }
        }
        return winner.mapValues { $0.layerId }
    }

    /// chip 隐藏:命名空间键 "\(layerId)|\(dimKey)"(多图层各自独立)。
    private static func isHidden(
        input: MapDimension.Input, layer: ActiveLayer, filterState: DimensionFilterState
    ) -> Bool {
        if let gb = layer.primary.groupBy {
            let key = "\(layer.id.uuidString)|\(gb.key)"
            for v in gb.resolve(input) where filterState.isHidden(dimensionKey: key, value: v) { return true }
        }
        for nf in layer.normals {
            let key = "\(layer.id.uuidString)|\(nf.dimension.key)"
            for v in nf.dimension.resolve(input) where filterState.isHidden(dimensionKey: key, value: v) { return true }
        }
        return false
    }
}
```

- [ ] **Step 2: 写测试 LayerResolverTests.swift**

需要构造 `StyleEntity`。`StyleEntity` 由各实体 `.styleEntity` 产生;测试里用真 @Model(in-memory container)最稳。参考既有 `StyleResolverChainTests.swift` 的 container 建法。

```swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerResolverTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(ModelSchema.allTypes), configurations: [config])
        return ModelContext(container)
    }

    private func compound(_ ctx: ModelContext, name: String, category: String = "") -> Compound {
        let c = Compound(datasetId: UUID(), name: name)
        c.category = category
        ctx.insert(c)
        return c
    }

    private func layer(
        id: UUID = UUID(), type: String, zIndex: Int = 0, enabled: Bool = true,
        conditions: [FilterCondition] = [], normals: [NormalFilter] = [],
        minZoom: Double? = nil, maxZoom: Double? = nil
    ) -> LayerResolver.ActiveLayer {
        LayerResolver.ActiveLayer(
            id: id, name: "L", entityType: type, zIndex: zIndex, enabled: enabled,
            minZoom: minZoom, maxZoom: maxZoom,
            primary: PrimaryFilter(conditions: conditions, groupBy: nil), normals: normals
        )
    }

    @Test func matchesByEntityTypeOnly() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A")
        let layers = [layer(type: "compound"), layer(type: "school")]
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)], layers: layers, zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result[c.id] != nil)
    }

    @Test func disabledLayerHidesEntity() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A")
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)],
            layers: [layer(type: "compound", enabled: false)], zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result.isEmpty)
    }

    @Test func andFilterNarrowsMembership() throws {
        let ctx = try makeContext()
        let road = compound(ctx, name: "road", category: "道路")
        let other = compound(ctx, name: "other", category: "住宅")
        let cond = FilterCondition(
            dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base"),
            op: .equals, value: .string("道路")
        )
        let result = LayerResolver.resolve(
            candidates: [.init(id: road.id, entity: road.styleEntity), .init(id: other.id, entity: other.styleEntity)],
            layers: [layer(type: "compound", conditions: [cond])], zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result[road.id] != nil)
        #expect(result[other.id] == nil)
    }

    @Test func highestZIndexWinsOnOverlap() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A")
        let low = UUID(), high = UUID()
        let layers = [
            layer(id: low, type: "compound", zIndex: 1),
            layer(id: high, type: "compound", zIndex: 5),
        ]
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)], layers: layers, zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result[c.id] == high)
    }

    @Test func zoomOutOfRangeHides() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A")
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)],
            layers: [layer(type: "compound", minZoom: 14)], zoom: 12,
            filterState: DimensionFilterState(), context: ctx, datasetId: nil
        )
        #expect(result.isEmpty)
    }

    @Test func hiddenChipNamespacedByLayer() throws {
        let ctx = try makeContext()
        let c = compound(ctx, name: "A", category: "住宅")
        let layerId = UUID()
        let nf = NormalFilter(name: "类型", dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base"))
        let state = DimensionFilterState()
        state.toggle(dimensionKey: "\(layerId.uuidString)|field:category", value: "住宅")
        let result = LayerResolver.resolve(
            candidates: [.init(id: c.id, entity: c.styleEntity)],
            layers: [layer(id: layerId, type: "compound", normals: [nf])], zoom: 12,
            filterState: state, context: ctx, datasetId: nil
        )
        #expect(result.isEmpty)
    }
}
```

> 若 `Compound` 没有 `category` 可空字段或 init 签名不同,先 `grep -n "init\|var category" PropertyAtlas/PropertyAtlas/Models/Entities/Compound.swift` 校正构造。

- [ ] **Step 3: 跑测试**

Run 测试命令 `-only-testing:PropertyAtlasTests/LayerResolverTests`。Expected: 6 passed。

- [ ] **Step 4: commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/LayerResolver.swift PropertyAtlas/PropertyAtlasTests/LayerResolverTests.swift
git commit -m "feat(render): add LayerResolver (entity→layer mapping, OR across layers)"
```

---

# Phase B — 模型 cutover(整阶段收口绿)

> B 内 5 个任务按序做。B1–B4 是中间态(单独不可编译);**B5 收口后整体 build 绿**。建议同一 subagent 连续完成 B1–B5 再交 build。

### Task B1: 删 MapView,改键样式表,删 entity.layerId,删旧 Layer 字段

**Files:**
- Delete: `Models/Display/MapView.swift`
- Modify: `Models/Display/Layer.swift`(删 deprecated 字段)
- Modify: `Models/Display/ViewEntityStyle.swift`、`Models/Display/ViewStyleRule.swift`(`viewId`→`layerId`)
- Modify: `DataKit/ModelSchema.swift`(删 `MapView.self`)
- Modify: 4 实体 `Models/Entities/{Compound,School,POI,Area}.swift`(删 `layerId` 列)

- [ ] **Step 1: 删 MapView.swift**

```bash
cd /Users/fujie/projects/天津买房
git rm PropertyAtlas/PropertyAtlas/Models/Display/MapView.swift
```

- [ ] **Step 2: Layer.swift 删 deprecated 字段**

删 `staticRefsJSON`、`dynamicQueryJSON`、`isDefault`、`themeId` 四行(A2 标 deprecated 的)。最终 Layer 字段:`id/datasetId/name/iconSF/colorHex/entityType/primaryFilterJSON/normalFiltersJSON/hiddenChipsJSON/paletteHex/showLegend/minZoom/maxZoom/enabled/sortOrder/zIndex/version/createdAt/updatedAt/deleted`。

- [ ] **Step 3: ViewEntityStyle.swift / ViewStyleRule.swift 改键**

两文件中 `var viewId: UUID = UUID()` → `var layerId: UUID = UUID()`,init 形参 `viewId:` → `layerId:`,赋值同改。

- [ ] **Step 4: ModelSchema.swift 删 MapView**

把 `Layer.self, MapView.self, ViewEntityStyle.self, ...` 行改为 `Layer.self, ViewEntityStyle.self, ViewStyleRule.self, ViewStyleCondition.self,`。

- [ ] **Step 5: 4 实体删 layerId 列**

```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas/PropertyAtlas/Models/Entities
grep -n "layerId" Compound.swift School.swift POI.swift Area.swift
```
删每个文件里的 `var layerId: UUID?` 一行。

(中间态,不单独 build)

---

### Task B2: `LayerContext`(取代 MapViewContext)+ 删旧 resolver/state

**Files:**
- Delete: `MapRender/VisibilityResolver.swift`、`MapRender/LayerEvaluator.swift`、`States/LayerState.swift`
- Rename+rewrite: `MapRender/MapViewContext.swift` → `MapRender/LayerContext.swift`

- [ ] **Step 1: 删三文件**

```bash
cd /Users/fujie/projects/天津买房
git rm PropertyAtlas/PropertyAtlas/MapRender/VisibilityResolver.swift \
       PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift \
       PropertyAtlas/PropertyAtlas/States/LayerState.swift
git mv PropertyAtlas/PropertyAtlas/MapRender/MapViewContext.swift \
       PropertyAtlas/PropertyAtlas/MapRender/LayerContext.swift
```

- [ ] **Step 2: 重写 LayerContext.swift**

```swift
import Foundation
import Observation
import SwiftData

/// 图层中心化上下文。持 dataset(全局展示设置源)+ 查询本 dataset 全部图层(enabled 直接读模型)。
@MainActor
@Observable
final class LayerContext {
    let dataset: Dataset
    private let modelContext: ModelContext

    init(dataset: Dataset, modelContext: ModelContext) {
        self.dataset = dataset
        self.modelContext = modelContext
    }

    var datasetIdValue: UUID { dataset.id }

    var allLayers: [Layer] {
        let dsId = dataset.id
        let fd = FetchDescriptor<Layer>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted },
            sortBy: [SortDescriptor(\.zIndex), SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(fd)) ?? []
    }

    func touch() { dataset.updatedAt = Date() }
}
```

(中间态,不单独 build)

---

### Task B3: RootView 渲染管线重写

这是 cutover 核心。RootView 用 `LayerContext`,候选不再按 visibility 门控,可见集 + 样式 + 染色 + 图例全部走「每图层」。`layerState` 删除(enabled 读 `Layer.enabled`,toggle 直接 mutate 模型)。

**Files:**
- Modify: `RootView.swift`

- [ ] **Step 1: @Query / @State 调整**

`StudioRootView` 顶部:删 `@State private var layerState`;`@State private var viewContext: MapViewContext?` → `@State private var layerCtx: LayerContext?`。`@Query private var layersQuery: [Layer]` 保留。

- [ ] **Step 2: 删 visibility / activeMV，展示设置改读 dataset**

删 `activeMV`/`touchMV`/`mapStyle`/`aspect`/`poi*` 中对 `activeMapView` 的引用,改读 `layerCtx?.dataset`。例:
```swift
    private var ds: Dataset? { layerCtx?.dataset }
    private func touchDS() { ds?.updatedAt = Date() }
    private var mapStyle: StudioMapStyle { StudioMapStyle.resolve(ds?.studioMapStyleRaw ?? "") }
    private var mapStyleBinding: Binding<StudioMapStyle> {
        Binding(get: { mapStyle }, set: { ds?.studioMapStyleRaw = $0.rawValue; touchDS() })
    }
    private var aspect: CanvasAspect { CanvasAspect(rawValue: ds?.canvasAspectRaw ?? "") ?? .ratio16x9 }
    private var aspectBinding: Binding<CanvasAspect> {
        Binding(get: { aspect }, set: { ds?.canvasAspectRaw = $0.rawValue; touchDS() })
    }
    private var selectedPOIOptions: Set<StudioPOIOption> {
        Set((ds?.poiCategoriesRaw ?? "").split(separator: ",").compactMap { StudioPOIOption(rawValue: String($0)) })
    }
    private var poiFilter: MKPointOfInterestFilter {
        guard ds?.poiEnabled ?? false else { return .excludingAll }
        let cats = selectedPOIOptions
        return cats.isEmpty ? .includingAll : MKPointOfInterestFilter(including: cats.map(\.category))
    }
    private var poiSignature: String { "\(mapStyle.rawValue)|\(ds?.poiEnabled ?? false)|\(ds?.poiCategoriesRaw ?? "")" }
    private var poiEnabledBinding: Binding<Bool> {
        Binding(get: { ds?.poiEnabled ?? false }, set: { ds?.poiEnabled = $0; touchDS() })
    }
    private var poiCategoriesBinding: Binding<Set<StudioPOIOption>> {
        Binding(get: { selectedPOIOptions },
                set: { ds?.poiCategoriesRaw = $0.map(\.rawValue).sorted().joined(separator: ","); touchDS() })
    }
```

- [ ] **Step 3: body 顶部输入推导改写**

替换 `body` 开头(原 162–186 行块)为:
```swift
        let dsId = layerCtx?.datasetIdValue ?? UUID()
        let zoom = visibleRegion.map { ZoomLevel.from(region: $0) } ?? 12
        let _: Void = refreshCacheIfNeeded(dsId: dsId, zoom: zoom)
        let legendSections = renderLegendSections(cache.legendSpecs, region: visibleRegion)
        let overlays = cache.overlays
        let markerAnnotations: [MKAnnotation] = searchMarker.map { [SearchMarkerFactory.annotation(for: $0)] } ?? []
        let annotations = viewportPins(cache.pins, region: visibleRegion) + markerAnnotations
```
删 `let activeMapView`/`visibility`/`primary`/`normals`/`layerState.initializeIfNeeded` 那几行。`StudioOverlay(... viewContext: ctx ...)` 改传 `layerCtx`(StudioOverlay 签名 Phase C 调整;此处先传,若 StudioOverlay 仍要 MapViewContext 则 Phase C 一并改——B 阶段把 StudioOverlay 的该形参类型也改成 `LayerContext`)。

- [ ] **Step 4: 候选构建去 visibility 门控**

`Cand` 结构删 `layerId` 字段。`buildCandidates` 改签名 `buildCandidates(dsId:entityById:)`,删所有 `if visibility[...] == true` 包裹(始终纳入 4 类),删 `.init(... layerId: ...)` 的 `layerId` 实参。

- [ ] **Step 5: rebuildContent 重写**

把 `rebuildContent` 改为(核心):
```swift
    private func rebuildContent(dsId: UUID, zoom: Double) {
        let layers = layerCtx?.allLayers ?? []
        let relatedIds: [UUID] = appState.selectedRef.map {
            EdgeStore.relations(of: $0, datasetId: dsId, in: modelContext).flatMap { $0.items.map(\.other.id) }
        } ?? []
        let highlight = SpotlightResolver.highlightedIds(
            selected: appState.selectedRef?.id, relatedIds: relatedIds,
            enabled: ds?.spotlightOnSelect ?? false
        )
        let entityById = buildEntityIndex(dsId: dsId)
        let cands = buildCandidates(dsId: dsId, entityById: entityById)
        let edgeProjection = buildEdgeProjection(dsId: dsId, entityById: entityById)
        let dimCache = DimResolveCache()

        let activeLayers: [LayerResolver.ActiveLayer] = layers.map {
            LayerResolver.ActiveLayer(
                id: $0.id, name: $0.name, entityType: $0.entityType, zIndex: $0.zIndex,
                enabled: $0.enabled, minZoom: $0.minZoom, maxZoom: $0.maxZoom,
                primary: ViewConfigCodec.decodePrimary($0.primaryFilterJSON),
                normals: ViewConfigCodec.decodeNormals($0.normalFiltersJSON)
            )
        }
        let resolveCands = cands.map { LayerResolver.Candidate(id: $0.id, entity: $0.entity) }
        let entityToLayer = LayerResolver.resolve(
            candidates: resolveCands, layers: activeLayers, zoom: zoom, filterState: filterState,
            context: modelContext, datasetId: dsId, edgeProjection: edgeProjection, cache: dimCache
        )
        let visibleIds = Set(entityToLayer.keys)
        let layerById = Dictionary(layers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        // 预取每图层的样式 + 规则
        let stylesByLayer = buildStylesByLayer(dsId: dsId, layerIds: layers.map(\.id))
        let rulesByLayer = buildRulesByLayer(dsId: dsId, layerIds: layers.map(\.id))

        // 分组染色:逐图层独立(各自 groupBy + paletteHex)
        var groupColors: [UUID: String] = [:]
        for layer in layers {
            let primary = ViewConfigCodec.decodePrimary(layer.primaryFilterJSON)
            guard primary.groupBy != nil else { continue }
            let palette = layer.paletteHex.isEmpty ? PaletteAssigner.highContrast : layer.paletteHex
            let items = cands
                .filter { entityToLayer[$0.id] == layer.id }
                .map { GroupColorResolver.Item(id: $0.id, entity: $0.entity, layerNames: [layer.name]) }
            let colors = GroupColorResolver.colors(
                items: items, groupBy: primary.groupBy, palette: palette,
                context: modelContext, datasetId: dsId, edgeProjection: edgeProjection, cache: dimCache
            )
            groupColors.merge(colors) { _, new in new }
        }

        let pins = buildPins(
            cands: cands, entityToLayer: entityToLayer, groupColors: groupColors,
            stylesByLayer: stylesByLayer, rulesByLayer: rulesByLayer, highlight: highlight
        )
        let selectedAreaId = appState.selectedRef?.kind == .area ? appState.selectedRef?.id : nil
        let dsAreas = areas.filter { $0.datasetId == dsId }
        let (areaOverlays, styleMap) = buildAreaOverlays(
            areas: dsAreas, entityToLayer: entityToLayer, stylesByLayer: stylesByLayer,
            rulesByLayer: rulesByLayer, groupColors: groupColors, layerById: layerById, forceId: selectedAreaId
        )
        let edgeLines = buildEdgeLines(labels: ds?.drawEdgeLines ?? [], datasetId: dsId)

        cache.pins = pins
        cache.overlays = areaOverlays + edgeLines
        cache.styleMap = styleMap
        cache.legendSpecs = buildLegendSpecs(
            cands: cands, entityToLayer: entityToLayer, layers: layers, dsId: dsId,
            edgeProjection: edgeProjection, dimCache: dimCache
        )
    }
```

- [ ] **Step 6: buildStylesByLayer / buildRulesByLayer**

替换 `buildViewStyles`/`buildViewStyleRules`(按 layerId、对全部图层预取):
```swift
    /// layerId → ViewEntityStyle(每图层一行)
    private func buildStylesByLayer(dsId: UUID, layerIds: [UUID]) -> [UUID: ViewEntityStyle] {
        let idSet = Set(layerIds)
        let fetch = FetchDescriptor<ViewEntityStyle>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
        let rows = ((try? modelContext.fetch(fetch)) ?? []).filter { idSet.contains($0.layerId) }
        return Dictionary(rows.map { ($0.layerId, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// layerId → [ResolvedStyleRule](priority 升序)
    private func buildRulesByLayer(dsId: UUID, layerIds: [UUID]) -> [UUID: [ResolvedStyleRule]] {
        let idSet = Set(layerIds)
        let ruleFetch = FetchDescriptor<ViewStyleRule>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted },
            sortBy: [SortDescriptor(\.priority)]
        )
        let rules = ((try? modelContext.fetch(ruleFetch)) ?? []).filter { idSet.contains($0.layerId) }
        var out: [UUID: [ResolvedStyleRule]] = [:]
        for rule in rules {
            let ruleId = rule.id
            let condFetch = FetchDescriptor<ViewStyleCondition>(
                predicate: #Predicate { $0.ruleId == ruleId && !$0.deleted },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            let conditions = ((try? modelContext.fetch(condFetch)) ?? []).map { c in
                ViewStyleConditionCodec.styleCondition(
                    field: c.field, op: StyleConditionOp(rawValue: c.op) ?? .equals,
                    valueString: c.valueString, valueList: c.valueList
                )
            }
            let resolved = ResolvedStyleRule(
                pinPartial: StyleFieldConvert.pinPartial(
                    shape: rule.shape, fillHex: rule.fillHex, strokeHex: rule.strokeHex,
                    glyph: rule.glyph, glyphHex: rule.glyphHex, size: rule.size, labelVisible: rule.labelVisible),
                areaPartial: StyleFieldConvert.areaPartial(
                    fillHex: rule.fillHex, fillOpacity: rule.fillOpacity,
                    strokeHex: rule.strokeHex, strokeWidth: rule.strokeWidth, labelVisible: rule.labelVisible),
                priority: rule.priority, enabled: rule.enabled, conditions: conditions
            )
            out[rule.layerId, default: []].append(resolved)
        }
        return out
    }
```

- [ ] **Step 7: buildPins / buildAreaOverlays 改签名(按命中图层取样式)**

```swift
    private func buildPins(
        cands: [Cand], entityToLayer: [UUID: UUID], groupColors: [UUID: String],
        stylesByLayer: [UUID: ViewEntityStyle], rulesByLayer: [UUID: [ResolvedStyleRule]],
        highlight: Set<UUID>?
    ) -> [MKAnnotation] {
        var result: [MKAnnotation] = []
        for c in cands where c.type != "area" && c.hasCoordinate {
            guard let lid = entityToLayer[c.id] else { continue }
            let style = StyleResolver.resolvePin(
                entity: c.entity, viewStyle: stylesByLayer[lid],
                rules: rulesByLayer[lid] ?? [], groupFillHex: groupColors[c.id]
            )
            let pin = PinAnnotation(entityId: c.id, entityType: c.type, name: c.name, coordinate: c.coordinate, style: style)
            if let highlight { pin.highlighted = highlight.contains(c.id); pin.dimmed = !highlight.contains(c.id) }
            result.append(pin)
        }
        return result
    }

    private func buildAreaOverlays(
        areas: [Area], entityToLayer: [UUID: UUID], stylesByLayer: [UUID: ViewEntityStyle],
        rulesByLayer: [UUID: [ResolvedStyleRule]], groupColors: [UUID: String],
        layerById: [UUID: Layer], forceId: UUID? = nil
    ) -> ([MKOverlay], [ObjectIdentifier: AreaStyle]) {
        var built: [(overlay: MKOverlay, style: AreaStyle, zIndex: Int)] = []
        for a in areas where !a.deleted {
            let lid = entityToLayer[a.id]
            guard lid != nil || a.id == forceId else { continue }
            let style = StyleResolver.resolveArea(
                entity: a.styleEntity, viewStyle: lid.flatMap { stylesByLayer[$0] },
                rules: lid.flatMap { rulesByLayer[$0] } ?? [], groupFillHex: groupColors[a.id]
            )
            if let r = AreaOverlayFactory.makeOverlay(for: a, style: style) {
                built.append((r.overlay, r.style, lid.flatMap { layerById[$0]?.zIndex } ?? 0))
            }
        }
        // 跨图层按 zIndex;同 zIndex(同层,如「路网」全部道路)用 roadDrawPriority 处理共线道路类色;再 stable。
        let stable = built.enumerated().sorted {
            let (a, b) = ($0.element, $1.element)
            if a.zIndex != b.zIndex { return a.zIndex < b.zIndex }
            let pa = roadDrawPriority(a.style.fillHex), pb = roadDrawPriority(b.style.fillHex)
            return pa != pb ? pa < pb : $0.offset < $1.offset
        }
        var overlays: [MKOverlay] = []
        var map: [ObjectIdentifier: AreaStyle] = [:]
        for item in stable {
            overlays.append(item.element.overlay)
            map[ObjectIdentifier(item.element.overlay)] = item.element.style
        }
        return (overlays, map)
    }
```
`roadDrawPriority` 保留不动。

- [ ] **Step 8: buildLegendSpecs 改为逐图层分段**

```swift
    private func buildLegendSpecs(
        cands: [Cand], entityToLayer: [UUID: UUID], layers: [Layer], dsId: UUID,
        edgeProjection: EdgeProjection? = nil, dimCache: DimResolveCache? = nil
    ) -> [LegendSpec] {
        func entries(_ ids: Set<UUID>, _ dim: MapDimension, layerName: String, prefixOne: Bool) -> [LegendSpec.Entry] {
            cands.filter { ids.contains($0.id) }.map { cand in
                let input = MapDimension.Input(
                    entity: cand.entity, layerNames: [layerName], context: modelContext, datasetId: dsId,
                    edgeProjection: edgeProjection, cache: dimCache)
                var values = dim.resolve(input)
                if prefixOne { values = values.sorted().prefix(1).map { $0 } }
                return LegendSpec.Entry(coordinate: cand.coordinate, values: values)
            }
        }
        var specs: [LegendSpec] = []
        for layer in layers where layer.showLegend {
            let memberIds = Set(entityToLayer.filter { $0.value == layer.id }.map(\.key))
            guard !memberIds.isEmpty else { continue }
            let primary = ViewConfigCodec.decodePrimary(layer.primaryFilterJSON)
            let normals = ViewConfigCodec.decodeNormals(layer.normalFiltersJSON)
            let palette = layer.paletteHex.isEmpty ? PaletteAssigner.highContrast : layer.paletteHex
            let ns = "\(layer.id.uuidString)|"
            if let gb = primary.groupBy {
                let e = entries(memberIds, gb, layerName: layer.name, prefixOne: true)
                let distinct = Array(Set(e.flatMap(\.values)))
                let assign = PaletteAssigner.assign(values: distinct, palette: palette)
                specs.append(LegendSpec(
                    title: "\(layer.name)·\(legendTitle(for: gb, fallback: "分组"))",
                    dimensionKey: ns + gb.key, togglable: false, dropZeroViewport: true,
                    swatch: assign, entries: e))
            }
            for nf in normals {
                // 普通过滤图例列全部可切换值 → 用「层内 primary 命中、不含 chip 隐藏」的成员集
                let e = entries(memberIds, nf.dimension, layerName: layer.name, prefixOne: false)
                specs.append(LegendSpec(
                    title: "\(layer.name)·\(nf.name)", dimensionKey: ns + nf.dimension.key,
                    togglable: true, dropZeroViewport: false, swatch: [:], entries: e))
            }
        }
        return specs
    }
```
> 注:`dimensionKey` 带 `layerId|` 前缀,与 `LayerResolver.isHidden` 一致;`toggleChip` 收到的也是带前缀的 key。`renderLegendSections`/`legendTitle` 不变(legendTitle 接 `MapDimension`,标题已在上面拼好)。普通过滤图例此处用 `memberIds`(已应用 chip 隐藏)会漏掉「已隐藏值」行;为保留可点亮,改用「不含 chip 隐藏」的成员集:在 rebuildContent 额外算一份 `entityToLayerNoChips`(filterState 传空 `DimensionFilterState()`)传入。**实现时**:rebuildContent 多算一个 `let entityToLayerNoChips = LayerResolver.resolve(..., filterState: DimensionFilterState(), ...)`,buildLegendSpecs 普通过滤用其成员集,groupBy 仍用 `entityToLayer`。

- [ ] **Step 9: 内容签名 contentSignature 重写**

签名删 `activeMapView`/`visibility`/`layerState`,改为遍历全部图层字段:
```swift
    private func refreshCacheIfNeeded(dsId: UUID, zoom: Double) {
        let sig = contentSignature(dsId: dsId, zoom: zoom)
        guard cache.sig != sig else { return }
        cache.sig = sig
        rebuildContent(dsId: dsId, zoom: zoom)
    }

    private func contentSignature(dsId: UUID, zoom: Double) -> Int {
        var hasher = Hasher()
        hasher.combine(dsId)
        hasher.combine(ds?.spotlightOnSelect ?? false)
        hasher.combine((ds?.drawEdgeLines ?? []).sorted().joined(separator: ","))
        let layers = layerCtx?.allLayers ?? []
        hasher.combine(layers.count)
        for l in layers {
            hasher.combine(l.id); hasher.combine(l.updatedAt); hasher.combine(l.enabled)
            hasher.combine(l.zIndex); hasher.combine(l.primaryFilterJSON); hasher.combine(l.normalFiltersJSON)
            hasher.combine(l.paletteHex.joined(separator: ",")); hasher.combine(l.showLegend)
        }
        // 样式表(全 dataset)
        let styleFetch = FetchDescriptor<ViewEntityStyle>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
        for row in (try? modelContext.fetch(styleFetch)) ?? [] {
            hasher.combine(row.layerId); hasher.combine(row.entityType); hasher.combine(row.updatedAt)
        }
        combineRuleSignature(&hasher, dsId: dsId)
        for (key, values) in filterState.hidden.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key); for v in values.sorted() { hasher.combine(v) }
        }
        let zoomMatters = layers.contains { $0.minZoom != nil || $0.maxZoom != nil }
        if zoomMatters { hasher.combine(Int(zoom)) }
        hasher.combine(appState.selectedRef?.id)
        combineVersion(&hasher, compounds, dsId)
        combineVersion(&hasher, schools, dsId)
        combineVersion(&hasher, pois, dsId)
        combineVersion(&hasher, areas, dsId)
        return hasher.finalize()
    }

    private func combineRuleSignature(_ hasher: inout Hasher, dsId: UUID) {
        let rules = viewStyleRules.filter { $0.datasetId == dsId && !$0.deleted }
        hasher.combine(rules.count)
        var rMax = Date.distantPast
        for r in rules { hasher.combine(r.priority); hasher.combine(r.enabled); if r.updatedAt > rMax { rMax = r.updatedAt } }
        hasher.combine(rMax)
        let ruleIds = Set(rules.map(\.id))
        let conds = viewStyleConditions.filter { ruleIds.contains($0.ruleId) && !$0.deleted }
        hasher.combine(conds.count)
        var cMax = Date.distantPast
        for c in conds { if c.updatedAt > cMax { cMax = c.updatedAt } }
        hasher.combine(cMax)
    }
```

- [ ] **Step 10: toggleLayer / toggleChip / restoreChips / createDrawer / ensureViewContext / layersForDataset**

```swift
    private func toggleLayer(_ id: UUID) {
        guard let layer = (layerCtx?.allLayers ?? []).first(where: { $0.id == id }) else { return }
        layer.enabled.toggle()
        layer.updatedAt = Date()
    }

    /// chip key 已带 "layerId|" 前缀(legend 拼好)。持久:写回该图层 hiddenChipsJSON(去前缀存)。
    private func toggleChip(_ dimKey: String, _ value: String) {
        filterState.toggle(dimensionKey: dimKey, value: value)
        let parts = dimKey.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let lid = UUID(uuidString: parts[0]),
              let layer = (layerCtx?.allLayers ?? []).first(where: { $0.id == lid }) else { return }
        // 收集该图层所有带前缀的隐藏键 → 去前缀存
        var dict: [String: [String]] = [:]
        let prefix = "\(lid.uuidString)|"
        for (k, set) in filterState.hidden where k.hasPrefix(prefix) {
            dict[String(k.dropFirst(prefix.count))] = Array(set).sorted()
        }
        layer.hiddenChipsJSON = (try? JSONHelpers.encode(dict)) ?? "{}"
        layer.updatedAt = Date()
    }

    /// 启动/数据变:从各图层 hiddenChipsJSON 还原(键加 "layerId|" 前缀)。
    private func restoreChips() {
        filterState.reset()
        var merged: [String: [String]] = [:]
        for layer in layerCtx?.allLayers ?? [] {
            guard let data = layer.hiddenChipsJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else { continue }
            for (k, v) in dict { merged["\(layer.id.uuidString)|\(k)"] = v }
        }
        filterState.load(merged)
    }
```
`createDrawer`/`createPin`/`finishAreaDraw`:去掉 `layerId` 概念——新建实体不再指派图层(成员派生)。`CreateEntitySheet` 改为只选 `kind`(entityType),不选图层;`EntityWriter.createPin(... layerId:)` 实参传 `nil` 或删该形参(见 B 阶段对 EntityWriter 的处理:若 `layerId` 形参仍在,传 nil;否则删)。**实现**:grep `EntityWriter.createPin` 签名,若有 `layerId` 形参,保留传 `nil`;`createDrawer` 简化为不传图层列表。

```swift
    @ViewBuilder
    private func createDrawer(dsId: UUID) -> some View {
        CreateEntitySheet(
            prefillName: createPrefillName,
            defaultKind: createPrefillName != nil ? .poi : .compound,
            onCreate: { kind, name in
                showCreateMenu = false
                createPin(kind, name: name)
            },
            onCancel: { showCreateMenu = false; createPrefillName = nil }
        )
    }

    private func createPin(_ kind: EntityKind, name: String = "") {
        guard let coord = pendingCoordinate, let dsId = layerCtx?.datasetIdValue else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ref = EntityWriter.createPin(
            kind: kind, datasetId: dsId, name: trimmed.isEmpty ? "未命名" : trimmed,
            latitude: coord.latitude, longitude: coord.longitude, layerId: nil, in: modelContext)
        searchMarker = nil; searchPlace = nil; showPlaceDetail = false; createPrefillName = nil
        appState.select(ref); appState.beginEditing()
    }
```
`ensureViewContext` → `ensureLayerContext`:
```swift
    private func ensureLayerContext() {
        guard layerCtx == nil, let ds = datasets.first(where: { !$0.deleted }) else { return }
        layerCtx = LayerContext(dataset: ds, modelContext: modelContext)
    }
```
`layersForDataset` 删(用 `layerCtx?.allLayers`)。`finishAreaDraw` 里 `layersForDataset(dsId).first(where: { $0.isDefault })?.id` → `nil`(新区域不指派图层;靠 category=道路/手动归类被某图层过滤命中)。

- [ ] **Step 11: body 中 onChange / 抽屉调用更新**

- `onChange(of: viewContext?.activeMapView?.id)` 块 → 删(无单 active 概念);保留 restoreChips 触发改挂 `onChange(of: layerCtx?.allLayers.count)` 或 `onAppear`。
- `onChange(of: viewContext?.activeMapView?.enabledLayerIds)` → 删。
- `.onAppear { ensureViewContext() ... }` → `ensureLayerContext()`。
- `.onChange(of: datasets.first?.id) { ... ensureViewContext() }` → `ensureLayerContext()`。
- `LeftDrawerView(...)` 调用:`layers: layerCtx?.allLayers ?? []`,删 `layerState:` 实参(见 B4 抽屉签名)。
- `SettingsSheet(viewContext: ctx ...)` / `StudioOverlay(... viewContext: ctx ...)`:形参类型改 `LayerContext`(B4/Phase C 同步)。

(中间态,不单独 build)

---

### Task B4: 抽屉 + StudioToolbar + Overlay/Settings 形参换 LayerContext

**Files:**
- Modify: `Studio/LeftDrawer/LeftDrawerView.swift`、`Studio/LeftDrawer/LayersView.swift`
- Modify: `Studio/StudioToolbar.swift`(删视图单选菜单)
- Modify: `Studio/StudioOverlay.swift`、`Studio/Settings/SettingsSheet.swift`(`viewContext: MapViewContext` → `layerCtx: LayerContext`,内部最小适配)

- [ ] **Step 1: LayersView 改为直接读 Layer.enabled**

删 `@Bindable var layerState`,toggle 通过 `onToggle`。`on` 改 `layer.enabled`:
```swift
struct LayersView: View {
    let layers: [Layer]
    let currentZoom: Double
    var onToggle: (UUID) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel(text: "图层").padding(.horizontal, 8).padding(.bottom, 4)
            ForEach(layers, id: \.id) { layer in row(layer) }
        }
    }

    private func row(_ layer: Layer) -> some View {
        let inZoom = zoomOK(layer)
        let on = layer.enabled
        let hasZoom = layer.minZoom != nil || layer.maxZoom != nil
        return HStack(spacing: 10) {
            if let icon = layer.iconSF {
                Image(systemName: icon).font(.system(size: 15))
                    .foregroundStyle(Studio.on2).frame(width: 26, height: 26)
                    .background(Studio.glassHover, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(layer.name).font(Studio.sans(13, .medium)).foregroundStyle(Studio.on).lineLimit(1)
                if hasZoom {
                    Text(zoomLabel(layer)).font(Studio.mono(10))
                        .foregroundStyle(inZoom ? Studio.on3 : Studio.warn)
                }
            }
            Spacer(minLength: 4)
            if hasZoom, !inZoom { ZoomFlag("越界") }
            Toggle("", isOn: Binding(get: { on }, set: { _ in onToggle(layer.id) }))
                .labelsHidden().tint(Studio.cool).controlSize(.mini)
        }
        .opacity(on ? 1 : 0.6).padding(.horizontal, 8).padding(.vertical, 6)
        .frame(minHeight: 40).contentShape(Rectangle())
    }
    // zoomOK / zoomLabel 不变
}
```

- [ ] **Step 2: LeftDrawerView 删 layerState**

删 `@Bindable var layerState`;`LayersView(layers:currentZoom:onToggle:)`。其余不变。RootView 调用同步去掉 `layerState:`。

- [ ] **Step 3: StudioToolbar 删视图单选菜单**

`grep -n "switchView\|allMapViews\|MapView\|viewContext" Studio/StudioToolbar.swift`,删视图切换 Menu(13–25 行附近),其依赖的 `viewContext` 若仅用于此则改/删。图层显隐已在左抽屉,不需顶栏视图选择。

- [ ] **Step 4: StudioOverlay / SettingsSheet 形参换名**

两文件中 `viewContext: MapViewContext` → `layerCtx: LayerContext`。内部凡 `viewContext.activeMapView.xxx`(展示设置)改读 `layerCtx.dataset.xxx`。`SettingsSheet` body 内具体 tab 内容 Phase C 重写,此处先让其编译(可临时把图层/视图 tab 内容替换为 `Text("迁移中")` 占位,Phase C 实现真 UI)。

> 说明:此占位是 Phase 间过渡,Phase C 必定替换,非交付占位。

(中间态,不单独 build)

---

### Task B5: seed 重写 + `LayerMigratorV3`(B 收口,build 绿)

**Files:**
- Modify: `DataKit/LegacyMigrator.swift`(`seedPalettesThemesLayers` → seed 5 图层,删 MapView seed;删 `backfillLayerIds`/`migratePrimaryArea` 中对 layerId 的写;`cleanupOrphans` 若引用 MapView 删)
- Create: `DataKit/LayerMigratorV3.swift`
- Modify: `States/SeedImporter.swift`(run 路径、道路/边界 seed 去 layerId、调 LayerMigratorV3)
- Modify: `DataKit/StyleConsolidationMigrator.swift`(`viewId`→`layerId`;Phase B 仅改键让其编译,真正搬运逻辑 Phase D 视情况保留/简化)

- [ ] **Step 1: LegacyMigrator.seedPalettesThemesLayers 改为 seed 5 图层**

把 `defaultLayer` + themes + `seedMapViews` 整段替换为新 5 图层 seed(保留 palettes + themes + StyleRule seed,因 StyleConsolidationMigrator 仍可能消化;但**新建图层不再用 themeId/isDefault**):

```swift
        // 新模型:每 dataset seed 5 个默认图层(单一实体类型 + 过滤器派生成员)
        let dsId = dataset.id
        func makeLayer(_ name: String, _ type: String, icon: String?, z: Int, enabled: Bool,
                       primary: PrimaryFilter = PrimaryFilter(conditions: [], groupBy: nil)) {
            let l = Layer(datasetId: dsId, name: name, entityType: type)
            l.iconSF = icon; l.zIndex = z; l.sortOrder = z; l.enabled = enabled
            l.paletteHex = defaultPalette?.colorsHex ?? []
            l.primaryFilterJSON = (try? JSONHelpers.encode(primary)) ?? #"{"conditions":[],"groupBy":null}"#
            l.normalFiltersJSON = (try? JSONHelpers.encode(defaultNormals(for: type))) ?? "[]"
            ctx.insert(l)
        }
        func catFilter(_ value: String) -> PrimaryFilter {
            PrimaryFilter(conditions: [FilterCondition(
                dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base"),
                op: .equals, value: .string(value))], groupBy: nil)
        }
        makeLayer("楼盘", "compound", icon: "building.2", z: 10, enabled: true)
        makeLayer("学校", "school", icon: "graduationcap", z: 20, enabled: true)
        makeLayer("POI", "poi", icon: "mappin", z: 30, enabled: false)
        makeLayer("行政区", "area", icon: "map", z: 1, enabled: true, primary: catFilter("行政区"))
        makeLayer("路网", "area", icon: "road.lanes", z: 2, enabled: true, primary: catFilter("道路"))
        dataset.activeThemeId = t1.id
```
新增辅助(文件内 private static):
```swift
    private static func defaultNormals(for type: String) -> [NormalFilter] {
        func f(_ name: String, _ key: String) -> NormalFilter {
            NormalFilter(name: name, dimension: MapDimension(kind: .field, fieldKey: key, fieldSource: "base"))
        }
        switch type {
        case "compound": return [f("精装类型", "finishType"), f("新房/二手", "isNewHouse")]
        case "school": return [f("阶段", "category"), f("等级", "grade"), f("学制", "form")]
        case "poi": return [f("POI 类型", "category")]
        case "area": return [f("区域类型", "category")]
        default: return []
        }
    }
```
删 `seedMapViews` 整个方法 + `ViewSeed` struct + `baseVisibility/onlyPOIAndArea/onlyCompound` 常量 + `defaultLayer.themeId/zIndex` 行。`seedSchoolStyleRules` 保留(StyleConsolidationMigrator 用)。

- [ ] **Step 2: LegacyMigrator 去 layerId 写 + cleanup**

`grep -n "layerId\|isDefault\|MapView\|backfillLayerIds\|\.themeId" DataKit/LegacyMigrator.swift`。
- `backfillLayerIds`:删整个方法(实体无 layerId 了)。
- 任何 `area.layerId = ...` / `.layerId =` 写:删。
- `cleanupOrphans`:若其列表含 `MapView.self` 删该项;若按 layerId 清孤儿则删该逻辑。

- [ ] **Step 3: SeedImporter 去 layerId + run 路径**

`seedDistrictBoundariesIfNeeded`:删 `defaultLayerId` 查找 + `area.layerId = defaultLayerId`(行政区由「行政区」图层按 category 过滤命中,无需指派)。
`seedRoadLinesIfNeeded`:删 `roadNetworkLayerId(...)` 调用 + `area.layerId = roadLayerId`;**保留** `area.category = "道路"` + `area.tags` + `area.styleFillHex = roadFillHex(...)`(道路归「路网」图层靠 category 过滤;per-road 颜色靠 styleFillHex override)。删 `roadNetworkLayerId` 方法。
`runIfNeeded`:两条路径都加 `LayerMigratorV3.run(in: context)`(在 StyleConsolidationMigrator 之后);删 `backfillLayerIds` 两处调用。

- [ ] **Step 4: 写 LayerMigratorV3.swift**

```swift
import Foundation
import SwiftData

/// 图层中心化重构启动幂等迁移。闸 = Dataset.layerModelV3。
/// 既有库:旧 seed 已建「默认/路网」图层(无 entityType 语义)+ 旧 MapView 已随 schema 破坏消失。
/// 本迁移确保每 dataset 有「楼盘/学校/POI/行政区/路网」5 图层(按 name 幂等),展示设置已在 Dataset(默认值即可)。
@MainActor
enum LayerMigratorV3 {
    static func run(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>(
            predicate: #Predicate { !$0.deleted && !$0.layerModelV3 }))) ?? []
        for ds in datasets {
            ensureLayers(ds: ds, in: context)
            ds.layerModelV3 = true
        }
        try? context.save()
    }

    private static func ensureLayers(ds: Dataset, in context: ModelContext) {
        let dsId = ds.id
        let existing = (try? context.fetch(FetchDescriptor<Layer>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted }))) ?? []
        let byName = Dictionary(existing.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

        func ensure(_ name: String, _ type: String, icon: String, z: Int, enabled: Bool, category: String?) {
            let primary: PrimaryFilter = category.map {
                PrimaryFilter(conditions: [FilterCondition(
                    dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base"),
                    op: .equals, value: .string($0))], groupBy: nil)
            } ?? PrimaryFilter(conditions: [], groupBy: nil)
            let primaryJSON = (try? JSONHelpers.encode(primary)) ?? #"{"conditions":[],"groupBy":null}"#
            if let l = byName[name] {
                // 既有图层(旧 seed 的「默认」「路网」)→ 补 entityType / 过滤器语义
                l.entityType = type
                if l.primaryFilterJSON.isEmpty || l.primaryFilterJSON == #"{"conditions":[],"groupBy":null}"# {
                    l.primaryFilterJSON = primaryJSON
                }
                l.updatedAt = Date()
            } else {
                let l = Layer(datasetId: dsId, name: name, entityType: type)
                l.iconSF = icon; l.zIndex = z; l.sortOrder = z; l.enabled = enabled
                l.primaryFilterJSON = primaryJSON
                context.insert(l)
            }
        }
        ensure("楼盘", "compound", icon: "building.2", z: 10, enabled: true, category: nil)
        ensure("学校", "school", icon: "graduationcap", z: 20, enabled: true, category: nil)
        ensure("POI", "poi", icon: "mappin", z: 30, enabled: false, category: nil)
        ensure("行政区", "area", icon: "map", z: 1, enabled: true, category: "行政区")
        ensure("路网", "area", icon: "road.lanes", z: 2, enabled: true, category: "道路")
    }
}
```
> 既有库里旧「默认」图层(name="默认")不在 5 名单内 → 保留但无语义(entityType 默认 compound,无过滤)。可选:迁移中把 name=="默认" 软删。**实现**:`ensureLayers` 末尾把 `byName["默认"]?.deleted = true`(它原是混类型兜底,新模型不需要)。

- [ ] **Step 5: StyleConsolidationMigrator 改键编译通过**

`grep -n "viewId\|MapView\|enabledLayerIds\|\.themeId\|resolveTheme" DataKit/StyleConsolidationMigrator.swift`。该文件大量依赖 `MapView`/`viewId`/`enabledLayerIds`/`themeId`,已不存在。**Phase B 处理**:把 `migrateViews`/`migrateStyleRules` 改为遍历 `Layer`(代替 `MapView`),`view.id` → `layer.id` 作为 `ViewEntityStyle.layerId`/`ViewStyleRule.layerId`;`resolveTheme(for view)` 简化为 `dataset.activeThemeId` 的 theme(删 enabledLayerIds/themeId 逻辑)。`migrateViews` 的「每图层补 4 类」改为「每图层补它自己的 entityType 1 行」(单类型):
```swift
    private static func migrateViews(in context: ModelContext) {
        let layers = (try? context.fetch(FetchDescriptor<Layer>(predicate: #Predicate { !$0.deleted }))) ?? []
        for layer in layers {
            let lid = layer.id
            let existing = (try? context.fetch(FetchDescriptor<ViewEntityStyle>(
                predicate: #Predicate { $0.layerId == lid && !$0.deleted }))) ?? []
            if !existing.isEmpty { continue }
            let theme = activeTheme(datasetId: layer.datasetId, in: context)
            let parsed = theme.flatMap { try? StyleDefaults.parseThemeDefaults($0.defaultStylesJSON) }
            let row = ViewEntityStyle(datasetId: layer.datasetId, layerId: lid, entityType: layer.entityType)
            applyParsedDefaults(parsed, entityType: layer.entityType, to: row)
            context.insert(row)
        }
    }
    private static func activeTheme(datasetId: UUID, in context: ModelContext) -> Theme? {
        guard let aid = (try? context.fetch(FetchDescriptor<Dataset>(
            predicate: #Predicate { $0.id == datasetId }))?.first)?.activeThemeId else { return nil }
        return themeById(aid, in: context)
    }
```
`migrateStyleRules` 同样把 `views`→`layers`、`view.id`→`layer.id`、`resolveTheme(for:)`→`activeTheme(datasetId:)`。删 `resolveTheme`/`applyPaletteAndLegend`(palette 现在 seed 直接写 Layer.paletteHex)。`migrateEntityOverrides` 不变(实体 override 列搬运,保留道路色路径——其实道路色由 seed 直接写 styleFillHex,override 搬运对既有库仍有效,保留)。

> StyleConsolidationMigrator 的存在意义在 Stage B 后会被删;这里只做「改键能编译 + 单类型补行」。

- [ ] **Step 6: build 绿(B 收口)**

Run 构建命令。逐个修剩余编译错误(grep `MapView`/`viewId`/`layerId`/`enabledLayerIds`/`isActive`/`visibilityJSON`/`activeMapView`/`layerState`/`switchView` 残留):
```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas/PropertyAtlas
grep -rn "MapView\|enabledLayerIds\|isActive\|visibilityJSON\|activeMapView\|layerState\|switchView\|\.layerId" --include="*.swift" . | grep -v "LayerContext\|LayerResolver"
```
Expected 最终: `** BUILD SUCCEEDED **`。

- [ ] **Step 7: commit(整个 Phase B 一次提交)**

```bash
cd /Users/fujie/projects/天津买房
git add -A
git commit -m "refactor(model): cutover to layer-centric model (merge MapView into Layer)

- Delete MapView @Model; Layer absorbs view config + entityType
- Drop entity.layerId; membership derived from entityType + filters
- LayerResolver replaces VisibilityResolver + LayerEvaluator
- MapViewContext -> LayerContext; presentation moves to Dataset
- RootView pipeline: per-layer styles/colors/legend, OR across layers
- Rekey ViewEntityStyle/ViewStyleRule viewId -> layerId
- Seed 5 default layers; add LayerMigratorV3 (layerModelV3 gate)"
```

---

# Phase C — 设置 UI(逐任务绿)

### Task C1: 图层设置 tab(CRUD + 单类型 + 层内配置)

**Files:**
- Modify: `Studio/Settings/SettingsSheet.swift`、`Studio/Settings/LayerSettingsTab.swift`
- Modify/合并: `Studio/Settings/ViewSettingsTab.swift`、`Studio/Settings/Components/ViewBasicSection.swift`、`ViewFilterSections.swift`、`ViewStyleSection.swift`、`EntityDefaultStyleEditor.swift`

> 先读这些文件取得现有结构:`for f in Studio/Settings/LayerSettingsTab.swift Studio/Settings/ViewSettingsTab.swift Studio/Settings/Components/ViewBasicSection.swift Studio/Settings/Components/ViewFilterSections.swift Studio/Settings/Components/ViewStyleSection.swift Studio/Settings/Components/EntityDefaultStyleEditor.swift; do echo "== $f =="; cat "$f"; done`

- [ ] **Step 1: SettingsSheet tab 列表**

把 tab 改为 `图层 / 枚举 / 相机 / 字段 / 展示`(5)。「视图」tab 并入「图层」。`SettingsSheet(layerCtx:)`。

- [ ] **Step 2: LayerSettingsTab 重写为图层 CRUD**

行为(读现有 LayerSettingsTab 模式后实现):
- 列出 `layerCtx.allLayers`,支持新建/删除(软删 `deleted=true`)/选中。
- **新建**:弹出 entityType 选择(compound/school/poi/area,4 选 1),建 `Layer(datasetId:name:entityType:)`;`entityType` 持久后**只读**。
- 选中图层后,编辑区分组:
  - 基本:name / iconSF / colorHex / enabled / zIndex / minZoom / maxZoom / showLegend。
  - 过滤(AND):`PrimaryFilterEditor`(复用现有 `DimensionPicker`/`FilterConditionRow`)——读写 `layer.primaryFilterJSON`(经 `ViewConfigCodec`)。groupBy 维度选择。
  - 普通过滤(图例 chip):编辑 `layer.normalFiltersJSON`(NormalFilter 列表,name + dimension)。
  - 调色板:`PaletteHexEditor` → `layer.paletteHex`。
  - 默认样式:`EntityDefaultStyleEditor`,但**只 1 组**(该图层的 entityType),读写 `ViewEntityStyle(layerId:entityType:)`(行在 setter 内懒建)。
  - 条件样式:`ViewStyleRulesSection`(该图层 entityType 的 `ViewStyleRule`,layerId 绑定)。
- 所有改动 `mutate + updatedAt`,SwiftData 自动保存。

> 维度/字段目录构造、DimensionPicker、PaletteHexEditor、EntityDefaultStyleEditor、ViewStyleRuleEditor 等组件均已存在,只需把「viewId」语义换为「当前选中 layer.id」、把「4 类」缩为「该 layer.entityType 1 类」、过滤 JSON 源从 MapView 换 Layer。

- [ ] **Step 3: build 绿 + 手测**

Run 构建命令。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4: commit**

```bash
git add -A && git commit -m "feat(settings): layer CRUD tab (single entityType + per-layer filters/style/palette)"
```

---

### Task C2: 展示设置 tab(dataset 级)

**Files:**
- Create: `Studio/Settings/DisplaySettingsTab.swift`
- Modify: `Studio/Settings/SettingsSheet.swift`

- [ ] **Step 1: DisplaySettingsTab**

读写 `layerCtx.dataset` 的:相机预设(cameraPresetId / 复用 CameraPreset 选择)、底图样式(studioMapStyleRaw / bgMapStyle)、Apple 地点(poiEnabled / poiCategoriesRaw)、导出文案(copyTitle/copySubtitle/copyWatermark)、水印 QR(watermarkQRData)、画幅(canvasAspectRaw)、spotlightOnSelect、drawEdgeLines。沿用原 `ViewBasicSection` 里这些控件(原绑 MapView,改绑 dataset)。

- [ ] **Step 2: 把 ViewBasicSection 的 dataset 级控件迁过来,删其 MapView 绑定**

`ViewBasicSection` 中属于展示设置的控件(底图/画幅/POI/文案/水印/spotlight/edgeLines)迁入 DisplaySettingsTab(绑 dataset);属于图层的(过滤/样式/调色/启用图层)已在 C1。`ViewBasicSection` 若清空则删文件 + 移除引用。

- [ ] **Step 3: build 绿 + commit**

```bash
git add -A && git commit -m "feat(settings): dataset-level display tab (camera/basemap/poi/export)"
```

---

# Phase D — 迁移验证

### Task D1: 清库重迁 + 既有库 smoke

> DB 编辑前确认 app 已退出(用户已退;若重开需再退)。Store 路径见 `docs/claude/swiftdata-store.md`。

- [ ] **Step 1: 确认 app 未运行**

```bash
pgrep -fl "PropertyAtlas.app" || echo "not running"
```
若在运行 → 停止,提示用户退出后再继续。

- [ ] **Step 2: 清库**

```bash
STORE=~/Library/Application\ Support/default.store
sqlite3 "$STORE" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true
rm -f ~/Library/Application\ Support/default.store*
```

- [ ] **Step 3: 启动 app(用户在 Xcode ⌘R,或) 命令行跑构建产物**

让用户 ⌘R 一次(首启动 seed + 迁移)。

- [ ] **Step 4: 验证(sqlite)**

```bash
STORE=~/Library/Application\ Support/default.store
sqlite3 "$STORE" "SELECT entityType, COUNT(*) FROM ZLAYER WHERE ZDELETED=0 GROUP BY entityType;"  # 列名以实际为准
sqlite3 "$STORE" "SELECT COUNT(*) FROM ZLAYER WHERE ZDELETED=0;"        # 期望 5(+可能软删的「默认」)
sqlite3 "$STORE" "SELECT COUNT(*) FROM ZVIEWENTITYSTYLE WHERE ZDELETED=0;" # 期望 5(每图层 1)
sqlite3 "$STORE" "SELECT COUNT(*) FROM ZCOMPOUND WHERE ZDELETED=0;"     # 不变
sqlite3 "$STORE" "SELECT COUNT(*) FROM ZAREA WHERE ZDELETED=0;"         # 不变(含道路+行政区)
sqlite3 "$STORE" "SELECT COUNT(*) FROM ZAREA WHERE ZCATEGORY='道路' AND ZSTYLEFILLHEX IS NOT NULL;" # 道路染色保留
```
列名(Z 前缀)以 `.schema ZLAYER` 实测为准。

- [ ] **Step 5: 验证(肉眼)**

 ⌘R 后:左抽屉 5 图层均可 toggle;同时开「楼盘」「学校」→ 两类同屏(OR);开「路网」道路显示且三环各色 + 射线绿 + 快速路紫;每个启用图层一段图例;关「行政区」→ 行政区消失;新建图层选 area + category 过滤 → 子集显示。

- [ ] **Step 6: 二次启动幂等**

再 ⌘R,Step 4 计数不变(`layerModelV3` 闸 + ensure 幂等)。

- [ ] **Step 7: commit(若验证中有修复)**

```bash
git add -A && git commit -m "fix(migration): layer-centric clean-DB remigrate verified"
```

---

# Phase E — 收尾

### Task E1: 删死代码 + 旧测试

**Files:**
- Modify/Delete: 旧 `MapView`/视图相关测试、`ViewConfigCodec`(若仍用则留)、`FieldKeyCatalog`(若引用 entityType)、`Studio/Editor/LayerPickerRow.swift`(若新建实体不再选层则删)

- [ ] **Step 1: grep 残留**

```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas
grep -rn "MapView\|enabledLayerIds\|visibilityJSON\|isActive\|layerState\|LayerEvaluator\|VisibilityResolver\|MapViewContext\|\.layerId\b\|isDefault\|\.themeId" --include="*.swift" PropertyAtlas PropertyAtlasTests | grep -v "LayerContext\|LayerResolver\|layerModelV3"
```
逐项删/改。

- [ ] **Step 2: 删/改受影响测试**

跑全测试,删引用已删类型的旧测试(如测 `VisibilityResolver`/`LayerEvaluator`/`MapView` seed 的)。新增/保留 `LayerResolverTests`、`LayerMigratorV3Tests`。

- [ ] **Step 3: 写 LayerMigratorV3Tests.swift**

```swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerMigratorV3Tests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(ModelSchema.allTypes), configurations: [config])
        return ModelContext(container)
    }

    @Test func seedsFiveLayersAndIsIdempotent() throws {
        let ctx = try makeContext()
        let ds = Dataset(name: "T"); ctx.insert(ds)
        LayerMigratorV3.run(in: ctx)
        let dsId = ds.id
        func layers() -> [Layer] {
            (try? ctx.fetch(FetchDescriptor<Layer>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted }))) ?? []
        }
        #expect(Set(layers().map(\.name)) == ["楼盘", "学校", "POI", "行政区", "路网"])
        #expect(ds.layerModelV3 == true)
        LayerMigratorV3.run(in: ctx) // 二次
        #expect(layers().count == 5)
    }

    @Test func roadLayerFiltersByCategory() throws {
        let ctx = try makeContext()
        let ds = Dataset(name: "T"); ctx.insert(ds)
        LayerMigratorV3.run(in: ctx)
        let dsId = ds.id
        let road = (try ctx.fetch(FetchDescriptor<Layer>(predicate: #Predicate { $0.datasetId == dsId })))
            .first { $0.name == "路网" }
        #expect(road?.entityType == "area")
        let pf = ViewConfigCodec.decodePrimary(road?.primaryFilterJSON ?? "")
        #expect(pf.conditions.count == 1)
    }
}
```

- [ ] **Step 4: 全测试 + build 绿**

```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas
xcodebuild test -project PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -20
```
Expected: 全 pass + `** BUILD SUCCEEDED **`。

- [ ] **Step 5: SwiftLint**

```bash
cd /Users/fujie/projects/天津买房 && swiftlint lint 2>&1 | tail -5
```
修文件超 300 行(Layer 设置 tab 若超 → 拆组件)。

- [ ] **Step 6: commit**

```bash
git add -A && git commit -m "chore: remove dead view-model code + update tests for layer-centric model"
```

- [ ] **Step 7: 更新 CLAUDE.md**

在 CLAUDE.md 文档列表加本 spec/plan,并加一段「图层中心化重构 (2026-06-10) 完成后」摘要(沿用既有 P 系列摘要格式)。commit `docs(claude): record layer-centric refactor`。

---

## Self-Review

**Spec coverage:**
- §1 核心模型:Layer 吸收(A2/B1)、Dataset 展示字段(A1)、样式表改键(B1)、删字段(B1) ✓
- §2 成员与过滤:LayerResolver(A4)、entityType+filter 派生 + entity.layerId 删(B1/B3)、OR/zIndex 取胜(A4/B3) ✓
- §3 样式/图例/UI:per-layer 样式(B3 buildStylesByLayer)、逐图层染色(B3)、多段图例(B3 buildLegendSpecs)、抽屉多 toggle(B4)、设置图层 tab + 展示 tab(C1/C2)、roadDrawPriority 保留 + zIndex 叠放(B3) ✓
- §4 迁移/seed/测试:LayerMigratorV3(B5)、seed 5 图层(B5)、清库验证(D1)、LayerResolver/迁移测试(A4/E1) ✓

**Placeholder scan:** B4 Step4 的 `Text("迁移中")` 是显式标注的 Phase 间过渡(C1/C2 替换),非交付占位。D1 sqlite 列名标注「以实测为准」。无其它 TBD。

**Type consistency:** `LayerResolver.ActiveLayer`/`Candidate`、`entityToLayer: [UUID:UUID]`、`buildStylesByLayer`/`buildRulesByLayer`、`LayerContext.allLayers`、`ViewEntityStyle.layerId`/`ViewStyleRule.layerId`、`ViewConfigCodec.decodePrimary/decodeNormals`、`PrimaryFilter(conditions:groupBy:)`(去 entityType)、chip 键 `layerId|dimKey` —— 各任务一致。

**已知风险/执行时校正:** ① `Compound.init`/`category` 字段签名(A4 测试)需 grep 校正;② `EntityWriter.createPin` 的 `layerId` 形参去留(B3 Step10)需 grep;③ C1 各设置组件(DimensionPicker/PaletteHexEditor/EntityDefaultStyleEditor/ViewStyleRuleEditor)现有签名需先读再接;④ sqlite Z 列名实测;⑤ StyleConsolidationMigrator 在 Stage B 后应删(本计划仅改键续命)。
