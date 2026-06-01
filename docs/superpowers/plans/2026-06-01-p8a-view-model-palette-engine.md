# P8a View 模型 + 调色引擎(additive)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** 加 `View` @Model(全局视图容器)+ `Layer` 扩展(zIndex/themeId)+ `PaletteAssigner`(hash+同屏去重+curated palette)+ `StyleResolver` group-color(additive 参数)+ migrator seed View/per-layer-theme。**全 additive**:Theme 旧字段不动、`FilterFieldConfig` 不删、RootView 不改 → app 仍跑旧路径,新结构纯单测覆盖。P8b 再切 RootView + 删旧。

**Architecture:** 与旧路径并存。`View` 持有 enabledLayerIds + primaryFilterJSON(P7 `PrimaryFilter` 的 JSON)+ normalFiltersJSON(`[NormalFilter]` JSON)+ paletteId + copy/camera。`Layer` 加 zIndex(渲染叠放)+ themeId(layer→theme)。`PaletteAssigner.assign(values,palette)` 出 [值→色] 映射(FNV-1a + 线性探测去重)。`StyleResolver.resolvePin` 加 `groupFillHex:String?=nil`(默认不变;非 nil 时在 rules 后、override 前覆盖 fill)。

**Tech Stack:** SwiftData · Swift Testing · 复用 P7 `PrimaryFilter`/`NormalFilter`/`MapDimension` · `StableHash.fnv1a32` · `JSONHelpers`。

**前置**: spec `docs/superpowers/specs/2026-05-31-generic-filter-legend-color-redesign.md` §2/§5/§6/§8;P7 已合(MapDimension/PrimaryFilter/NormalFilter)。

**关键现状:**
- `StyleResolver.resolvePin(entity:theme:rules:palettes:)` —— 5 个调用点(RootView ×4 + LegendSwatch ×1)。加默认参数不破坏它们。
- `Layer`:已有 colorHex/iconSF/staticRefsJSON/dynamicQueryJSON/minZoom/maxZoom/isDefault/enabled/sortOrder。
- `Theme`:有 visibilityJSON/defaultEnabledLayerIds/drawEdgeLines/copy*/styleRuleIds/defaultStylesJSON。**P8a 不动 Theme 字段**。
- migrator stage 8 `seedPalettesThemesLayers` 建 4 palette + 1 defaultLayer + 4 theme(t1-t4)。
- `StableHash.fnv1a32(String)->UInt32`;`Palette(name:colorsHex:builtIn:)`;`JSONHelpers.encode/decode`。

**新增文件:** `Models/Display/MapView.swift`、`MapRender/PaletteAssigner.swift` + 测试;改 `Layer.swift`/`ModelSchema.swift`/`StyleResolver.swift`/`LegacyMigrator.swift`。

> 命名注意:SwiftUI 有 `View` 协议 → @Model 命名 `MapView`(避撞),概念仍是 spec 的 "View"。

---

### Task 0: MapView @Model + ModelSchema

**Files:** Create `PropertyAtlas/PropertyAtlas/Models/Display/MapView.swift`; Modify `DataKit/ModelSchema.swift`; Test `PropertyAtlasTests/Models/MapViewTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import SwiftData
@testable import PropertyAtlas

@MainActor
struct MapViewTests {
    @Test func persistsAndReadsBack() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let dsId = UUID()
        let v = MapView(datasetId: dsId, name: "学区视图")
        v.enabledLayerIds = [UUID()]
        v.primaryFilterJSON = #"{"conditions":[],"groupBy":null}"#
        v.normalFiltersJSON = "[]"
        v.isActive = true
        ctx.insert(v)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<MapView>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "学区视图")
        #expect(fetched.first?.enabledLayerIds.count == 1)
    }
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd /Users/fujie/projects/天津买房/.claude/worktrees/p8a-view-model-palette-engine/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/MapViewTests 2>&1 | tail -25`
Expected: FAIL(MapView 未定义)。

- [ ] **Step 3: 实现 MapView**

```swift
import Foundation
import SwiftData

/// 全局视图预设(spec 的 "View";命名 MapView 避撞 SwiftUI.View)。
/// 一个 dataset 可多个。持有启用图层 + PrimaryFilter + NormalFilter[] + palette + 文案。
@Model
final class MapView {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var enabledLayerIds: [UUID] = []
    var primaryFilterJSON: String = #"{"conditions":[],"groupBy":null}"#
    var normalFiltersJSON: String = "[]"
    var paletteId: UUID?
    var cameraPresetId: UUID?
    var bgMapStyle: String = "standard"
    var drawEdgeLines: [String] = []
    var copyTitle: String?
    var copySubtitle: String?
    var copyWatermark: String?
    var spotlightOnSelect: Bool = true
    var sortOrder: Int = 0
    var isActive: Bool = false
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), datasetId: UUID, name: String) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
    }
}
```

`ModelSchema.swift` 的 `allTypes` 里,`Layer.self, FilterFieldConfig.self,` 行后加 `MapView.self,`。

- [ ] **Step 4: 跑确认通过**(同 Step 2)
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(model): MapView @Model (global view container) + schema"`

---

### Task 1: Layer + zIndex + themeId

**Files:** Modify `PropertyAtlas/PropertyAtlas/Models/Display/Layer.swift`; Test `PropertyAtlasTests/Models/LayerTests.swift`(已存在则追加,否则新建)

- [ ] **Step 1: 写失败测试**

```swift
@MainActor
struct LayerZIndexThemeTests {
    @Test func zIndexAndThemeIdPersist() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let l = Layer(datasetId: UUID(), name: "教育")
        l.zIndex = 5
        let tid = UUID(); l.themeId = tid
        ctx.insert(l); try ctx.save()
        let f = try ctx.fetch(FetchDescriptor<Layer>()).first
        #expect(f?.zIndex == 5)
        #expect(f?.themeId == tid)
    }
}
```
> `Layer(datasetId:name:)` init 以现有为准;若 init 不同,适配。

- [ ] **Step 2: 跑确认失败**(`-only-testing:PropertyAtlasTests/LayerZIndexThemeTests`)

- [ ] **Step 3: 实现** —— `Layer.swift` 加两字段(default 不破坏现有):
```swift
var zIndex: Int = 0
var themeId: UUID?
```
(放 `sortOrder` 附近。zIndex 渲染叠放序;themeId 指向该层的 Theme。)

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(model): Layer + zIndex (render order) + themeId (layer→theme)"`

---

### Task 2: PaletteAssigner(hash + 同屏去重 + curated palette)

**Files:** Create `PropertyAtlas/PropertyAtlas/MapRender/PaletteAssigner.swift`; Test `.../PaletteAssignerTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
struct PaletteAssignerTests {
    let pal = ["#E41A1C", "#377EB8", "#4DAF4A", "#984EA3"]

    @Test func sameValueStableColor() {
        let m1 = PaletteAssigner.assign(values: ["重点", "普通"], palette: pal)
        let m2 = PaletteAssigner.assign(values: ["重点", "普通"], palette: pal)
        #expect(m1["重点"] == m2["重点"])
    }

    @Test func distinctValuesDistinctColorsWithinCapacity() {
        let m = PaletteAssigner.assign(values: ["a", "b", "c", "d"], palette: pal)
        #expect(Set(m.values()).count == 4)   // 4 值 ≤ 4 色 → 全异
    }

    @Test func wrapsBeyondCapacity() {
        let m = PaletteAssigner.assign(values: ["a", "b", "c", "d", "e"], palette: pal)
        #expect(m.count == 5)                  // 5 值 > 4 色 → 必有复用,但都有色
        #expect(m.values().allSatisfy { pal.contains($0) })
    }

    @Test func emptyPaletteYieldsEmpty() {
        #expect(PaletteAssigner.assign(values: ["a"], palette: []).isEmpty)
    }
}
```
> `Dictionary.values()` 写法按 Swift 实际:用 `Array(m.values)`。修正测试为 `Set(m.values).count` / `m.values.allSatisfy`。

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**

```swift
import Foundation

/// 分类配色:值→色。FNV-1a 选首选槽,同屏内线性探测避重(值数 ≤ palette 才保证全异),
/// 超容量才复用。同值稳定(纯函数于 sorted values + palette)。
enum PaletteAssigner {
    /// 8 色高对比内置板(ColorBrewer Set1 改,跳黄,白字可读)。供默认分类染色。
    static let highContrast: [String] = [
        "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3",
        "#FF7F00", "#A65628", "#F781BF", "#17BECF",
    ]

    static func assign(values: [String], palette: [String]) -> [String: String] {
        guard !palette.isEmpty else { return [:] }
        var used = Set<Int>()
        var map: [String: String] = [:]
        for v in values.sorted() {
            var idx = Int(StableHash.fnv1a32(v) % UInt32(palette.count))
            if used.count < palette.count {
                var probe = 0
                while used.contains(idx) && probe < palette.count {
                    idx = (idx + 1) % palette.count
                    probe += 1
                }
            }
            used.insert(idx)
            map[v] = palette[idx]
        }
        return map
    }
}
```

- [ ] **Step 4: 跑确认通过**(先把测试里的 `.values()` 改成 `.values`)
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(palette): PaletteAssigner hash+viewport-dedup + curated high-contrast palette"`

---

### Task 3: StyleResolver group-color(additive 参数)

**Files:** Modify `PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift`; Test `.../StyleResolverGroupColorTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
@MainActor
struct StyleResolverGroupColorTests {
    private func e(_ type: String, _ f: [String: AnyJSON] = [:]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: f, customFields: [:])
    }

    @Test func groupFillOverridesThemeButNotEntityOverride() {
        // 无 theme/rules:group fill 生效
        let s1 = StyleResolver.resolvePin(entity: e("school"), theme: nil, rules: [], palettes: [:], groupFillHex: "#123456")
        #expect(s1.fillHex == "#123456")
        // 实体 override 优先于 group
        let withOverride = e("school", ["__overrideStyleJSON": .string(#"{"fillHex":"#ABCDEF"}"#)])
        let s2 = StyleResolver.resolvePin(entity: withOverride, theme: nil, rules: [], palettes: [:], groupFillHex: "#123456")
        #expect(s2.fillHex == "#ABCDEF")
    }

    @Test func nilGroupFillKeepsOldBehavior() {
        let s = StyleResolver.resolvePin(entity: e("school"), theme: nil, rules: [], palettes: [:])
        #expect(s.fillHex == StyleDefaults.builtinPin(for: "school").fillHex)
    }
}
```

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现** —— `resolvePin` 加默认参数,在 rules 合并后、override 合并前应用:

```swift
static func resolvePin(
    entity: StyleEntity,
    theme: Theme?,
    rules: [StyleRule],
    palettes: [UUID: Palette],
    groupFillHex: String? = nil          // ← 新增
) -> PinStyle {
    let base = StyleDefaults.builtinPin(for: entity.entityType)
    var partial = PartialPinStyle()

    if let theme { /* ...原 theme defaults 合并不变... */ }

    let matching = rules.filter { StyleRuleMatcher.matches(rule: $0, entity: entity) }
    let ascending = matching.sorted { $0.priority < $1.priority }
    for rule in ascending {
        partial.merge(pinPartialFromRule(rule, entity: entity, palettes: palettes))
    }

    if let groupFillHex {                 // ← 新增:group 色覆盖 fill(在 override 前)
        partial.fillHex = groupFillHex
    }

    if let overrideJSON = entity.overrideJSON {
        partial.merge(pinOverridePartial(overrideJSON))   // override 仍最后,优先级最高
    }

    return partial.finalize(default: base)
}
```
> 仅加参数 + 4 行;其余逻辑原样。5 个现有调用点因默认值 nil 不受影响。

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(style): StyleResolver optional groupFillHex (categorical color, override wins)"`

---

### Task 4: migrator seed MapView + Layer zIndex/themeId

**Files:** Modify `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`; Test `PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`(追加)

迁移在 stage 8 末尾 **additive** 加:给 defaultLayer 设 zIndex+themeId、seed 每个 theme 对应一个 `MapView`(enabledLayers=defaultLayer、normalFilters 由 FilterFieldConfig 派生、primaryFilter 空 groupBy)。**不动**已有 palette/theme/layer seeding。

- [ ] **Step 1: 写失败测试**

```swift
@Test func seedsMapViewsWithDefaults() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let ls = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
    ctx.insert(ls); try ctx.save()
    try LegacyMigrator.run(in: ctx)

    let views = try ctx.fetch(FetchDescriptor<MapView>())
    #expect(!views.isEmpty)                                   // 至少 1 个 View
    #expect(views.contains { $0.isActive })                  // 有活跃 View
    let v = try #require(views.first { $0.isActive })
    #expect(!v.enabledLayerIds.isEmpty)                       // 启用了 layer
    #expect(v.paletteId != nil)                              // 指了 palette
    // primaryFilter JSON 可解码为 PrimaryFilter
    #expect((try? JSONHelpers.decode(v.primaryFilterJSON) as PrimaryFilter) != nil)
    // 默认 layer 有 themeId + zIndex 已设
    let layers = try ctx.fetch(FetchDescriptor<Layer>())
    #expect(layers.contains { $0.themeId != nil })
}
```
> `JSONHelpers.decode` 泛型解码以现有签名为准;若签名不同,改用 `JSONDecoder().decode(PrimaryFilter.self, from: data)`。

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现** —— `seedPalettesThemesLayers` 末尾(`dataset.activeThemeId = t1.id` 后)加:

```swift
// P8a: Layer zIndex + themeId(默认层挂活跃 theme)
defaultLayer.zIndex = 0
defaultLayer.themeId = t1.id

// P8a: seed MapView(每 theme 一个;normalFilters 由 FilterFieldConfig 派生)
try seedMapViews(dataset: dataset, defaultLayerId: defaultLayer.id,
                 themes: [t1, t2, t3, t4],
                 palette: palettes.first, in: ctx)   // palette: 取 default-rainbow
```
注:`palettes` 是本函数内建的数组,需在循环里捕获第一个 `Palette` 实例的 id。简单做法:在建 palette 时存 `var defaultPaletteId: UUID?`,第一个赋值。

新增辅助方法:
```swift
private static func seedMapViews(
    dataset: Dataset, defaultLayerId: UUID, themes: [Theme],
    palette: Palette?, in ctx: ModelContext
) throws {
    // NormalFilters 由已 seed 的 FilterFieldConfig 派生(同 dataset)
    let cfgs = try ctx.fetch(FetchDescriptor<FilterFieldConfig>())
        .filter { $0.datasetId == dataset.id && !$0.deleted }
        .sorted { $0.slot < $1.slot }
    let normals: [NormalFilter] = cfgs.map {
        NormalFilter(name: $0.label,
                     dimension: MapDimension(kind: .field, fieldKey: $0.fieldKey, fieldSource: $0.fieldSource))
    }
    let normalsJSON = (try? JSONHelpers.encode(normals)) ?? "[]"
    let emptyPrimary = PrimaryFilter(conditions: [], groupBy: nil)
    let primaryJSON = (try? JSONHelpers.encode(emptyPrimary)) ?? #"{"conditions":[],"groupBy":null}"#

    for (idx, t) in themes.enumerated() {
        let v = MapView(datasetId: dataset.id, name: t.name)
        v.enabledLayerIds = [defaultLayerId]
        v.primaryFilterJSON = primaryJSON
        v.normalFiltersJSON = normalsJSON
        v.paletteId = palette?.id
        v.cameraPresetId = t.cameraPresetId
        v.bgMapStyle = t.bgMapStyle
        v.drawEdgeLines = t.drawEdgeLines
        v.copyTitle = t.copyTitle
        v.copySubtitle = t.copySubtitle
        v.copyWatermark = t.copyWatermark
        v.spotlightOnSelect = t.spotlightOnSelect
        v.sortOrder = idx
        v.isActive = (idx == 0)
        ctx.insert(v)
    }
}
```
> `JSONHelpers.encode([NormalFilter])` / `encode(PrimaryFilter)`:确认 `JSONHelpers.encode` 接受 `Encodable`;若仅接受特定类型,用 `JSONEncoder()` 直接编码并转 String(`String(data:encoding:)`)。`NormalFilter`/`PrimaryFilter` 已 Codable(P7)。

- [ ] **Step 4: 跑确认通过 + 全量 LegacyMigratorTests**

Run: `... -only-testing:PropertyAtlasTests/LegacyMigratorTests 2>&1 | tail -30` — 全过(旧 theme/layer seed 测试仍过)。

- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(migrator): seed MapView per theme + Layer zIndex/themeId (additive)"`

---

### Task 5: 全量测试 + CLAUDE.md

**Files:** Modify `CLAUDE.md`

- [ ] **Step 1: 全量单测**

Run: `cd .../p8a-view-model-palette-engine/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -40`
Expected: 全 unit PASS(新 4 套件 + 旧全过)。**P8a additive,旧路径不变 → 无清库 smoke**(migrator 改动由 in-memory `seedsMapViewsWithDefaults` 覆盖)。

- [ ] **Step 2: 更新 CLAUDE.md**

P7 节点后加:
```markdown
> **P8a (2026-06-01) 完成后**: 视图容器 + 调色引擎(additive,未接 RootView)。
> `MapView` @Model(spec 的 "View";enabledLayerIds + primaryFilterJSON + normalFiltersJSON
> + paletteId + copy/camera)。`Layer` + zIndex(渲染叠放)+ themeId(layer→theme)。
> `PaletteAssigner.assign`(FNV-1a + 同屏线性探测去重 + 8 色高对比内置板 highContrast)。
> `StyleResolver.resolvePin` 加 `groupFillHex:String?=nil`(分类色覆盖 fill,override 仍最高)。
> migrator seed 每 theme 一个 MapView(normalFilters 由 FilterFieldConfig 派生)+ Layer zIndex/themeId。
> Theme 旧字段/FilterFieldConfig/RootView **未动** → P8b 切 View-driven + 删旧。
```
并在计划列表加 P8a 行。

- [ ] **Step 3: 提交** `git -c commit.gpgsign=false commit -am "docs(claude): note P8a view model + palette engine completion"`

---

## Self-Review

- **Spec 覆盖**:P8a = spec §2(View 容器)+ §6(PaletteAssigner + curated palette)+ §8(Layer zIndex/themeId、Theme 下沉的前半:新结构就位但不剥旧)+ §5(group-color 求值的 StyleResolver 钩子)。Theme 字段剥离 + RootView 切换 + UI + 删旧 → P8b。
- **类型一致**:`MapView` T0 定义 + schema;`Layer.zIndex/themeId` T1;`PaletteAssigner.assign/highContrast` T2;`resolvePin(...,groupFillHex:)` T3(5 调用点默认 nil 不破);migrator T4 用 `MapView`/`NormalFilter`/`PrimaryFilter`(P7)/`MapDimension`/`FilterFieldConfig`。
- **占位扫描**:无 TBD;每任务完整代码。
- **风险**:① `JSONHelpers.encode` 是否接受任意 `Encodable` 待 T4 确认(否则用 JSONEncoder)。② `MapView` 命名避 SwiftUI.View。③ additive:全程 app 跑旧路径,新结构仅单测;P8b 接入前 MapView/PaletteAssigner "未被 UI 使用" 但有测试,非死码。④ migrator 是否已有 MapView seed 的幂等(run 整体被 "Dataset 存在则跳过" 守卫,且 seedMapViews 仅在新建 dataset 时跑,无重复风险)。⑤ 无 schema 破坏性变更(MapView 新表 + Layer 加列,SwiftData 轻量迁移;CloudKit .none)。
