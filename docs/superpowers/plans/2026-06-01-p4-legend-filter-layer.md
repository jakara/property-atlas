# P4: Legend + Filter + Layer — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `2026-05-28-generic-map-tool-design.md` §5.6（Legend 自动生成）+ §5.7（FilterFieldConfig 过滤字段 + 视图内/全集双计数 + chip toggle）+ §5.8（Layer 图层 + zoom 触发），并用通用 Legend/Filter/Layer 取代 P2 移除的天津专用 `StudioLegend`/`PinFilter`，左抽屉重新出现图例与图层控制。

**Architecture:** 全部可测逻辑下沉到无 UI 服务：`ZoomLevel`（region→zoom）、`LayerQuery`（解析 static/dynamic 成员）、`LayerEvaluator`（enabled×zoom×成员 → 可见 id 集）、`FilterPredicate`（chip 隐显语义）、`LegendSwatch`（StyleResolver 求色样块）、`LegendCounter`（按 type×field×value 分组 + viewport/total 双计数，排除自身字段 filter）。`@Observable` 持有运行时态：`FilterState`、`LayerState`。Studio 左抽屉 `LeftDrawerView`(Legend + Layers section) 浮在 ZStack。`StudioRootView` 计算 `visibleEntities = visibility × Layer × Filter` 喂 pins/overlays，并把可见集 + region 喂 `LegendCounter`。

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData (iOS 17+), Swift Testing, MapKit, Mac Catalyst。

**前置（P1/P2/P3 已落地）:** `Layer`/`FilterFieldConfig`/`Theme`(visibilityJSON/defaultEnabledLayerIds) @Model；`StyleEntity.field(_)` + 4 个 `styleEntity` adapter；`StyleResolver.resolvePin`；`StyleCondition`(Codable: field/op/value:AnyJSON) + `ConditionEvaluator.matches`；`AnyJSON`/`JSONHelpers`；`EntityKind`/`EntityRef`；`AppState`；`MapContainerView(onRegionChange:)`；`MapKitView` 暴露 `regionDidChange`。P1 已种：`FilterFieldConfig`(compound:finishType/isNewHouse；school:category/grade/form；poi:category；area:category) + 默认 `Layer "全部"`(isDefault, dynamicQueryJSON=nil, staticRefsJSON=nil = match-all)。

**范围边界（明确不做，留后续 plan）:**
- Settings 全页编辑（§6.5 Datasets/Themes/StyleRules/Palettes/Layers编辑器/Enum/字段定义/Cameras/备份）→ P5。本 plan 只**读** P1 已种的 FilterFieldConfig/Layer 渲染，不做编辑 UI。新建/编辑 Layer、改 FilterFieldConfig slot 留 P5。
- CloudKit `.private` 切换 + 删 Legacy* @Model 文件 → P5。
- POI 外部搜索 / Area 绘制 / PhotosPicker / 取景态 → P3.5。

**约定:**
- Mac Catalyst 优先；左抽屉仅 `#if targetEnvironment(macCatalyst)`。
- `entityType` 全程 `"compound"/"school"/"poi"/"area"`。
- value 显示规范化 `FilterPredicate.display(_ v: AnyJSON?) -> String`：`.string(s)→s`、`.int(i)→String(i)`、`.bool(b)→ b ? "true":"false"`、nil/.null→`""`（空值不出 chip）。filter/counter/swatch 全用同一函数。
- match-all layer 定义：`staticRefsJSON` 与 `dynamicQueryJSON` 皆 nil/空 → 覆盖所有类型所有 entity（默认"全部"层）。

---

## 文件结构

**新建（无 UI 服务）:**
- `MapRender/ZoomLevel.swift` — `MKCoordinateRegion` → zoom level [0..21]
- `MapRender/LayerQuery.swift` — 解析 `staticRefsJSON`/`dynamicQueryJSON`，判 match-all，覆盖类型
- `MapRender/LayerEvaluator.swift` — enabled×zoom×成员 → 可见 entity id 集
- `States/FilterPredicate.swift` — 纯结构：chip 隐显判定 + value 规范化
- `States/FilterState.swift` — `@Observable` 运行时 filter 态（hidden values）
- `States/LayerState.swift` — `@Observable` 运行时 layer enable 态
- `MapRender/LegendSwatch.swift` — (type,field,value) → fillHex（合成 StyleEntity 过 StyleResolver）
- `MapRender/LegendCounter.swift` — type×field×value 分组 + viewport/total 双计数 + 排除自身字段 filter + 模型 struct

**新建（Studio UI）:**
- `Studio/LeftDrawer/LegendView.swift` — 按 type 折叠，每 field 一组，chip(swatch+label+双计数+hide)
- `Studio/LeftDrawer/LayersView.swift` — layer toggle 列表 + zoom 指示/灰显
- `Studio/LeftDrawer/LeftDrawerView.swift` — 容器（Legend + Layers section）

**修改:**
- `RootView.swift` — StudioRootView：持 `FilterState`/`LayerState`；算 `visibleEntities`(visibility×layer×filter)；喂 pins/overlays + Legend；左抽屉 leading 浮出
- `CLAUDE.md` — P4 节点

**删除（通用化，取代天津专用）:**
- `Studio/PinFilter.swift`
- `Studio/StudioLegend.swift`
- `Studio/SchoolDetailCard.swift`
- `Studio/LegacyStudioAccessors.swift`

---

## Task 0: ZoomLevel — region → zoom level

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/ZoomLevel.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/ZoomLevelTests.swift`

MapKit 无直接 zoom；由经度跨度推导：`zoom = log2(360 / longitudeDelta)`，clamp [0,21]。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/MapRender/ZoomLevelTests.swift
import MapKit
import Testing
@testable import PropertyAtlas

struct ZoomLevelTests {
    @Test func wholeWorldIsZoomZeroish() {
        let r = MKCoordinateRegion(center: .init(latitude: 0, longitude: 0),
                                   span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360))
        #expect(ZoomLevel.from(region: r) <= 1.0)
    }

    @Test func smallSpanIsHighZoom() {
        let r = MKCoordinateRegion(center: .init(latitude: 39.1, longitude: 117.2),
                                   span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        #expect(ZoomLevel.from(region: r) > 14)
    }

    @Test func clampsTo21() {
        let r = MKCoordinateRegion(center: .init(latitude: 0, longitude: 0),
                                   span: MKCoordinateSpan(latitudeDelta: 0.00001, longitudeDelta: 0.00001))
        #expect(ZoomLevel.from(region: r) <= 21)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/ZoomLevelTests 2>&1 | tail -8`
Expected: FAIL（`Cannot find 'ZoomLevel'`）

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/ZoomLevel.swift
import Foundation
import MapKit

enum ZoomLevel {
    /// 由经度跨度估算 zoom level [0..21]。lonDelta 越小 zoom 越高。
    static func from(region: MKCoordinateRegion) -> Double {
        let lonDelta = max(region.span.longitudeDelta, 1e-6)
        let z = log2(360.0 / lonDelta)
        return min(max(z, 0), 21)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/ZoomLevel.swift PropertyAtlas/PropertyAtlasTests/MapRender/ZoomLevelTests.swift
git -c commit.gpgsign=false commit -m "feat(render): ZoomLevel from region longitude span"
```

---

## Task 1: LayerQuery — 解析 static/dynamic 成员 + match-all

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/LayerQuery.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/LayerQueryTests.swift`

解析 `staticRefsJSON`（`[{"entityId":"...","entityType":"..."}]`）与 `dynamicQueryJSON`（`{"entityType":"school","conditions":[{field,op,value}]}`）。两者皆 nil/空 → match-all。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/MapRender/LayerQueryTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

struct LayerQueryTests {
    @Test func bothNilIsMatchAll() {
        let q = LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: nil)
        #expect(q.isMatchAll)
        #expect(q.coveredTypes.isEmpty)
    }

    @Test func parsesStaticRefs() {
        let json = ##"[{"entityId":"11111111-1111-1111-1111-111111111111","entityType":"compound"}]"##
        let q = LayerQuery(staticRefsJSON: json, dynamicQueryJSON: nil)
        #expect(!q.isMatchAll)
        #expect(q.staticRefs.count == 1)
        #expect(q.staticRefs.first?.kind == .compound)
        #expect(q.coveredTypes == Set(["compound"]))
    }

    @Test func parsesDynamicQueryTypeAndConditions() {
        let json = ##"{"entityType":"school","conditions":[{"field":"grade","op":"in","value":["重点","区重点"]}]}"##
        let q = LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: json)
        #expect(!q.isMatchAll)
        #expect(q.dynamicType == "school")
        #expect(q.dynamicConditions.count == 1)
        #expect(q.coveredTypes == Set(["school"]))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/LayerQueryTests 2>&1 | tail -8`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/LayerQuery.swift
import Foundation

struct LayerQuery {
    let staticRefs: [EntityRef]
    let dynamicType: String?
    let dynamicConditions: [StyleCondition]

    init(staticRefsJSON: String?, dynamicQueryJSON: String?) {
        var refs: [EntityRef] = []
        if let s = staticRefsJSON, !s.isEmpty,
           let arr: [[String: String]] = try? JSONHelpers.decode(s) {
            for item in arr {
                if let idStr = item["entityId"], let uuid = UUID(uuidString: idStr),
                   let typeStr = item["entityType"], let kind = EntityKind(rawValue: typeStr) {
                    refs.append(EntityRef(id: uuid, kind: kind))
                }
            }
        }
        staticRefs = refs

        var dType: String?
        var conds: [StyleCondition] = []
        if let d = dynamicQueryJSON, !d.isEmpty,
           let decoded: DynamicQueryDTO = try? JSONHelpers.decode(d) {
            dType = decoded.entityType
            conds = decoded.conditions ?? []
        }
        dynamicType = dType
        dynamicConditions = conds
    }

    private struct DynamicQueryDTO: Codable {
        let entityType: String
        let conditions: [StyleCondition]?
    }

    var isMatchAll: Bool { staticRefs.isEmpty && dynamicType == nil }

    /// match-all 返回空集（evaluator 特判）；否则返回该层覆盖的类型集。
    var coveredTypes: Set<String> {
        var set = Set(staticRefs.map { $0.typeString })
        if let dynamicType { set.insert(dynamicType) }
        return set
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/LayerQuery.swift PropertyAtlas/PropertyAtlasTests/MapRender/LayerQueryTests.swift
git -c commit.gpgsign=false commit -m "feat(render): LayerQuery parse static/dynamic members + match-all"
```

---

## Task 2: LayerEvaluator — 可见 entity id 集

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift`

§5.8 渲染逻辑：`enabledLayers = 启用 && zoom 命中`。对类型 T：若无 active 层覆盖 T → T 全可见；否则仅成员可见。match-all 层覆盖所有 T 且成员 = 全部。无任何 active 层 → 全可见。输入抽象 `Candidate {id,type,styleEntity}`（可测）。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerEvaluatorTests {
    private func cand(_ id: UUID, _ type: String, _ fields: [String: AnyJSON] = [:]) -> LayerEvaluator.Candidate {
        LayerEvaluator.Candidate(id: id, type: type,
            entity: StyleEntity(entityType: type, id: id, baseFields: fields, customFields: [:]))
    }

    @Test func noActiveLayersShowsAll() {
        let a = UUID(); let b = UUID()
        let visible = LayerEvaluator.visibleIds(layers: [], zoom: 10,
            candidates: [cand(a, "school"), cand(b, "compound")])
        #expect(visible == Set([a, b]))
    }

    @Test func matchAllLayerShowsAll() {
        let a = UUID()
        let l = LayerEvaluator.ActiveLayer(query: LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: nil),
                                           enabled: true, minZoom: nil, maxZoom: nil)
        let visible = LayerEvaluator.visibleIds(layers: [l], zoom: 10, candidates: [cand(a, "school")])
        #expect(visible == Set([a]))
    }

    @Test func dynamicLayerConstrainsItsTypeOnly() {
        let keptSchool = UUID(); let droppedSchool = UUID(); let compound = UUID()
        let json = ##"{"entityType":"school","conditions":[{"field":"grade","op":"equals","value":"重点"}]}"##
        let l = LayerEvaluator.ActiveLayer(query: LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: json),
                                           enabled: true, minZoom: nil, maxZoom: nil)
        let visible = LayerEvaluator.visibleIds(layers: [l], zoom: 10, candidates: [
            cand(keptSchool, "school", ["grade": .string("重点")]),
            cand(droppedSchool, "school", ["grade": .string("普通")]),
            cand(compound, "compound"),
        ])
        #expect(visible == Set([keptSchool, compound]))
    }

    @Test func zoomOutOfRangeDeactivatesLayer() {
        let a = UUID()
        let json = ##"{"entityType":"school","conditions":[]}"##
        let l = LayerEvaluator.ActiveLayer(query: LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: json),
                                           enabled: true, minZoom: 12, maxZoom: 21)
        let visible = LayerEvaluator.visibleIds(layers: [l], zoom: 8,
            candidates: [cand(a, "school", ["grade": .string("普通")])])
        #expect(visible == Set([a]))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/LayerEvaluatorTests 2>&1 | tail -10`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift
import Foundation

@MainActor
enum LayerEvaluator {
    struct Candidate {
        let id: UUID
        let type: String
        let entity: StyleEntity
    }

    struct ActiveLayer {
        let query: LayerQuery
        let enabled: Bool
        let minZoom: Double?
        let maxZoom: Double?

        func isActive(at zoom: Double) -> Bool {
            guard enabled else { return false }
            if let minZoom, zoom < minZoom { return false }
            if let maxZoom, zoom > maxZoom { return false }
            return true
        }
    }

    static func visibleIds(layers: [ActiveLayer], zoom: Double, candidates: [Candidate]) -> Set<UUID> {
        let active = layers.filter { $0.isActive(at: zoom) }
        guard !active.isEmpty else { return Set(candidates.map { $0.id }) }

        if active.contains(where: { $0.query.isMatchAll }) {
            return Set(candidates.map { $0.id })
        }

        var constrainedTypes = Set<String>()
        for l in active { constrainedTypes.formUnion(l.query.coveredTypes) }

        var memberIds = Set<UUID>()
        for l in active {
            for ref in l.query.staticRefs { memberIds.insert(ref.id) }
            if let dType = l.query.dynamicType {
                for c in candidates where c.type == dType {
                    if matchesAll(c.entity, l.query.dynamicConditions) { memberIds.insert(c.id) }
                }
            }
        }

        var visible = Set<UUID>()
        for c in candidates {
            if !constrainedTypes.contains(c.type) || memberIds.contains(c.id) {
                visible.insert(c.id)
            }
        }
        return visible
    }

    private static func matchesAll(_ entity: StyleEntity, _ conditions: [StyleCondition]) -> Bool {
        for c in conditions where !ConditionEvaluator.matches(entity: entity, condition: c) { return false }
        return true
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（4 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift PropertyAtlas/PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift
git -c commit.gpgsign=false commit -m "feat(render): LayerEvaluator visible-id set from enabled×zoom×members"
```

---

## Task 3: FilterPredicate — chip 隐显语义 + value 规范化

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/States/FilterPredicate.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/States/FilterPredicateTests.swift`

§5.7：chip 点击隐藏 `field=value` 的实例。AND 跨 slot（任一 slot 命中隐藏值 → 整体隐）。`hidden` 键 = `"\(entityType).\(fieldKey)"`。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/States/FilterPredicateTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct FilterPredicateTests {
    private func ent(_ type: String, _ fields: [String: AnyJSON]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: fields, customFields: [:])
    }

    @Test func displayNormalizesScalars() {
        #expect(FilterPredicate.display(.string("精装")) == "精装")
        #expect(FilterPredicate.display(.int(2020)) == "2020")
        #expect(FilterPredicate.display(.bool(true)) == "true")
        #expect(FilterPredicate.display(nil) == "")
    }

    @Test func emptyHiddenPassesAll() {
        let p = FilterPredicate(hidden: [:])
        #expect(p.passes(ent("school", ["category": .string("小学")]), fieldKeys: ["category"]))
    }

    @Test func hiddenValueFailsThatEntity() {
        let p = FilterPredicate(hidden: ["school.category": Set(["小学"])])
        #expect(!p.passes(ent("school", ["category": .string("小学")]), fieldKeys: ["category"]))
        #expect(p.passes(ent("school", ["category": .string("初中")]), fieldKeys: ["category"]))
    }

    @Test func andAcrossSlots() {
        let p = FilterPredicate(hidden: ["school.grade": Set(["普通"])])
        #expect(!p.passes(ent("school", ["category": .string("小学"), "grade": .string("普通")]),
                          fieldKeys: ["category", "grade"]))
    }

    @Test func excludeSelfFieldIgnoresOwnHidden() {
        let p = FilterPredicate(hidden: ["school.category": Set(["小学"])])
        #expect(p.passes(ent("school", ["category": .string("小学")]),
                         fieldKeys: ["category"], excludeFieldKey: "category"))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/FilterPredicateTests 2>&1 | tail -8`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/States/FilterPredicate.swift
import Foundation

struct FilterPredicate {
    /// key = "\(entityType).\(fieldKey)" → 被隐藏的 value 显示串集合
    let hidden: [String: Set<String>]

    static func key(_ entityType: String, _ fieldKey: String) -> String { "\(entityType).\(fieldKey)" }

    static func display(_ v: AnyJSON?) -> String {
        switch v {
        case let .string(s): return s
        case let .int(i): return String(i)
        case let .double(d): return String(d)
        case let .bool(b): return b ? "true" : "false"
        default: return ""
        }
    }

    /// fieldKeys = 该 entityType 配置的 filter 字段。AND 跨字段：任一字段值被隐 → 不通过。
    /// excludeFieldKey: 计数自身 chip 时排除该字段的 filter（§5.7）。
    func passes(_ entity: StyleEntity, fieldKeys: [String], excludeFieldKey: String? = nil) -> Bool {
        for fk in fieldKeys where fk != excludeFieldKey {
            let value = Self.display(entity.field(fk))
            if hidden[Self.key(entity.entityType, fk)]?.contains(value) == true { return false }
        }
        return true
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/States/FilterPredicate.swift PropertyAtlas/PropertyAtlasTests/States/FilterPredicateTests.swift
git -c commit.gpgsign=false commit -m "feat(state): FilterPredicate chip hide semantics + value display"
```

---

## Task 4: FilterState — @Observable 运行时 filter 态

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/States/FilterState.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/States/FilterStateTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/States/FilterStateTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct FilterStateTests {
    @Test func toggleHidesThenShows() {
        let s = FilterState()
        #expect(s.isHidden(entityType: "school", fieldKey: "category", value: "小学") == false)
        s.toggle(entityType: "school", fieldKey: "category", value: "小学")
        #expect(s.isHidden(entityType: "school", fieldKey: "category", value: "小学") == true)
        s.toggle(entityType: "school", fieldKey: "category", value: "小学")
        #expect(s.isHidden(entityType: "school", fieldKey: "category", value: "小学") == false)
    }

    @Test func predicateReflectsHidden() {
        let s = FilterState()
        s.toggle(entityType: "school", fieldKey: "category", value: "小学")
        #expect(s.predicate.hidden["school.category"]?.contains("小学") == true)
    }

    @Test func resetClearsAll() {
        let s = FilterState()
        s.toggle(entityType: "poi", fieldKey: "category", value: "地铁")
        s.reset()
        #expect(s.predicate.hidden.isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/FilterStateTests 2>&1 | tail -8`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/States/FilterState.swift
import Foundation
import Observation

@MainActor
@Observable
final class FilterState {
    private(set) var hidden: [String: Set<String>] = [:]

    func isHidden(entityType: String, fieldKey: String, value: String) -> Bool {
        hidden[FilterPredicate.key(entityType, fieldKey)]?.contains(value) == true
    }

    func toggle(entityType: String, fieldKey: String, value: String) {
        let k = FilterPredicate.key(entityType, fieldKey)
        var set = hidden[k] ?? []
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
        hidden[k] = set.isEmpty ? nil : set
    }

    func reset() { hidden = [:] }

    var predicate: FilterPredicate { FilterPredicate(hidden: hidden) }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/States/FilterState.swift PropertyAtlas/PropertyAtlasTests/States/FilterStateTests.swift
git -c commit.gpgsign=false commit -m "feat(state): FilterState observable hidden-value toggles"
```

---

## Task 5: LayerState — @Observable 运行时 layer enable 态

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/States/LayerState.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/States/LayerStateTests.swift`

切 theme 时由 `Theme.defaultEnabledLayerIds` 初始化；运行时 toggle 不回写 theme。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/States/LayerStateTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerStateTests {
    @Test func initFromDefaultsEnablesListed() {
        let a = UUID(); let b = UUID()
        let s = LayerState()
        s.initialize(enabledIds: [a])
        #expect(s.isEnabled(a))
        #expect(!s.isEnabled(b))
    }

    @Test func toggleFlips() {
        let a = UUID()
        let s = LayerState()
        s.initialize(enabledIds: [])
        s.toggle(a)
        #expect(s.isEnabled(a))
        s.toggle(a)
        #expect(!s.isEnabled(a))
    }

    @Test func initializeIfNeededOnlyAppliesOnce() {
        let a = UUID(); let b = UUID()
        let s = LayerState()
        s.initializeIfNeeded(enabledIds: [a])
        s.toggle(b)                                   // 运行时启 b
        s.initializeIfNeeded(enabledIds: [a])         // 不应覆盖
        #expect(s.isEnabled(b))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/LayerStateTests 2>&1 | tail -8`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/States/LayerState.swift
import Foundation
import Observation

@MainActor
@Observable
final class LayerState {
    private(set) var enabledIds: Set<UUID> = []
    private var initialized: Bool = false

    func initialize(enabledIds: [UUID]) {
        self.enabledIds = Set(enabledIds)
        initialized = true
    }

    /// 仅当尚未初始化时套用默认（防止运行时 toggle 被覆盖）。
    func initializeIfNeeded(enabledIds: [UUID]) {
        guard !initialized else { return }
        initialize(enabledIds: enabledIds)
    }

    /// 切 theme 时强制重置。
    func resetForTheme(enabledIds: [UUID]) {
        initialize(enabledIds: enabledIds)
    }

    func isEnabled(_ id: UUID) -> Bool { enabledIds.contains(id) }

    func toggle(_ id: UUID) {
        if enabledIds.contains(id) { enabledIds.remove(id) } else { enabledIds.insert(id) }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/States/LayerState.swift PropertyAtlas/PropertyAtlasTests/States/LayerStateTests.swift
git -c commit.gpgsign=false commit -m "feat(state): LayerState observable enabled-layer toggles"
```

---

## Task 6: LegendSwatch — (type,field,value) → fillHex

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/LegendSwatch.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/LegendSwatchTests.swift`

合成一个仅含 `field=value` 的 StyleEntity，过 `StyleResolver.resolvePin` 取 fillHex（legend 与地图同源）。

> **实现前确认**（避免签名漂移）：读 `Models/Style/StyleRule.swift` 确认 `StyleRule` init 形参（预期 `init(datasetId:name:entityType:)`，applies* 为 var）；读 `MapRender/PinStyle.swift` 确认 `PinStyle.fillHex` 为非可选 `String`。如不符，按实际调整下面测试/实现。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/MapRender/LegendSwatchTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct LegendSwatchTests {
    @Test func returnsBuiltinFillWhenNoRules() {
        let hex = LegendSwatch.fillHex(entityType: "school", fieldKey: "category", value: "小学",
                                       theme: nil, rules: [], palettes: [:])
        #expect(hex.hasPrefix("#"))
    }

    @Test func ruleFixedFillApplies() {
        let rule = StyleRule(datasetId: UUID(), name: "r", entityType: "school")
        rule.conditionsJSON = ##"[{"field":"category","op":"equals","value":"小学"}]"##
        rule.appliesFillMode = "fixed"
        rule.appliesFillHex = "#123456"
        let hex = LegendSwatch.fillHex(entityType: "school", fieldKey: "category", value: "小学",
                                       theme: nil, rules: [rule], palettes: [:])
        #expect(hex == "#123456")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/LegendSwatchTests 2>&1 | tail -8`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/LegendSwatch.swift
import Foundation

@MainActor
enum LegendSwatch {
    /// 合成只含目标字段的 entity，复用 StyleResolver 求 fill，保证 legend 与地图一致。
    static func fillHex(entityType: String, fieldKey: String, value: String,
                        theme: Theme?, rules: [StyleRule], palettes: [UUID: Palette]) -> String {
        let entity = StyleEntity(entityType: entityType, id: UUID(),
                                 baseFields: [fieldKey: .string(value)], customFields: [:])
        let style = StyleResolver.resolvePin(entity: entity, theme: theme, rules: rules, palettes: palettes)
        return style.fillHex
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（2 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/LegendSwatch.swift PropertyAtlas/PropertyAtlasTests/MapRender/LegendSwatchTests.swift
git -c commit.gpgsign=false commit -m "feat(render): LegendSwatch fillHex via StyleResolver synthetic entity"
```

---

## Task 7: LegendCounter — type×field×value 分组 + 双计数

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/LegendCounter.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/LegendCounterTests.swift`

§5.7：每 (type, fieldKey, value) 出一行；`total` = 同 type+value + 过 filter(排除自身字段) + 在 layerVisible；`viewport` = 同上 + 在 region bbox。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/MapRender/LegendCounterTests.swift
import CoreLocation
import Foundation
import MapKit
import Testing
@testable import PropertyAtlas

@MainActor
struct LegendCounterTests {
    private func item(_ id: UUID, _ type: String, _ fields: [String: AnyJSON],
                      _ lat: Double, _ lon: Double) -> LegendCounter.Item {
        LegendCounter.Item(id: id, type: type,
            entity: StyleEntity(entityType: type, id: id, baseFields: fields, customFields: [:]),
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }

    private let cfg = FilterFieldConfig(datasetId: UUID(), entityType: "school",
                                        fieldKey: "category", fieldSource: "base", label: "阶段", slot: 1)

    private func bbox(_ latC: Double, _ lonC: Double, _ d: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(center: .init(latitude: latC, longitude: lonC),
                           span: MKCoordinateSpan(latitudeDelta: d, longitudeDelta: d))
    }

    @Test func groupsByValueWithTotalCounts() {
        let items = [
            item(UUID(), "school", ["category": .string("小学")], 39.1, 117.1),
            item(UUID(), "school", ["category": .string("小学")], 39.1, 117.1),
            item(UUID(), "school", ["category": .string("初中")], 39.1, 117.1),
        ]
        let rows = LegendCounter.rows(items: items, configs: [cfg], region: bbox(39.1, 117.1, 1),
            filter: FilterPredicate(hidden: [:]), layerVisible: Set(items.map { $0.id }),
            swatch: { _, _, _ in "#000000" })
        #expect(rows.first { $0.value == "小学" }?.total == 2)
        #expect(rows.first { $0.value == "初中" }?.total == 1)
    }

    @Test func viewportExcludesOutsideBbox() {
        let inId = UUID(); let outId = UUID()
        let items = [
            item(inId, "school", ["category": .string("小学")], 39.1, 117.1),
            item(outId, "school", ["category": .string("小学")], 10.0, 10.0),
        ]
        let rows = LegendCounter.rows(items: items, configs: [cfg], region: bbox(39.1, 117.1, 0.5),
            filter: FilterPredicate(hidden: [:]), layerVisible: Set([inId, outId]),
            swatch: { _, _, _ in "#000000" })
        let r = rows.first { $0.value == "小学" }
        #expect(r?.total == 2)
        #expect(r?.viewport == 1)
    }

    @Test func selfFieldFilterExcludedFromOwnCount() {
        let items = [item(UUID(), "school", ["category": .string("小学")], 39.1, 117.1)]
        let rows = LegendCounter.rows(items: items, configs: [cfg], region: bbox(39.1, 117.1, 1),
            filter: FilterPredicate(hidden: ["school.category": Set(["小学"])]),
            layerVisible: Set(items.map { $0.id }), swatch: { _, _, _ in "#000000" })
        #expect(rows.first { $0.value == "小学" }?.total == 1)
    }

    @Test func layerInvisibleExcluded() {
        let visible = UUID(); let hidden = UUID()
        let items = [
            item(visible, "school", ["category": .string("小学")], 39.1, 117.1),
            item(hidden, "school", ["category": .string("小学")], 39.1, 117.1),
        ]
        let rows = LegendCounter.rows(items: items, configs: [cfg], region: bbox(39.1, 117.1, 1),
            filter: FilterPredicate(hidden: [:]), layerVisible: Set([visible]),
            swatch: { _, _, _ in "#000000" })
        #expect(rows.first { $0.value == "小学" }?.total == 1)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/LegendCounterTests 2>&1 | tail -12`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/LegendCounter.swift
import CoreLocation
import Foundation
import MapKit

@MainActor
enum LegendCounter {
    struct Item {
        let id: UUID
        let type: String
        let entity: StyleEntity
        let coordinate: CLLocationCoordinate2D
    }

    struct Row: Identifiable {
        let entityType: String
        let fieldKey: String
        let fieldLabel: String
        let slot: Int
        let value: String
        let swatchHex: String
        let viewport: Int
        let total: Int
        var id: String { "\(entityType).\(fieldKey).\(value)" }
    }

    static func rows(items: [Item], configs: [FilterFieldConfig], region: MKCoordinateRegion?,
                     filter: FilterPredicate, layerVisible: Set<UUID>,
                     swatch: (_ type: String, _ fieldKey: String, _ value: String) -> String) -> [Row] {
        var fieldKeysByType: [String: [String]] = [:]
        for c in configs where !c.deleted {
            fieldKeysByType[c.entityType, default: []].append(c.fieldKey)
        }

        let bbox = region.map { BBox(region: $0) }
        var out: [Row] = []

        for cfg in configs.filter({ !$0.deleted && $0.showInLegend }).sorted(by: { $0.slot < $1.slot }) {
            let typeKeys = fieldKeysByType[cfg.entityType] ?? []
            var totalByValue: [String: Int] = [:]
            var viewportByValue: [String: Int] = [:]
            for it in items where it.type == cfg.entityType {
                let value = FilterPredicate.display(it.entity.field(cfg.fieldKey))
                guard !value.isEmpty else { continue }
                guard layerVisible.contains(it.id) else { continue }
                guard filter.passes(it.entity, fieldKeys: typeKeys, excludeFieldKey: cfg.fieldKey) else { continue }
                totalByValue[value, default: 0] += 1
                if let bbox, bbox.contains(it.coordinate) {
                    viewportByValue[value, default: 0] += 1
                }
            }
            for value in totalByValue.keys.sorted() {
                out.append(Row(
                    entityType: cfg.entityType, fieldKey: cfg.fieldKey, fieldLabel: cfg.label,
                    slot: cfg.slot, value: value,
                    swatchHex: cfg.showSwatch ? swatch(cfg.entityType, cfg.fieldKey, value) : "#CCCCCC",
                    viewport: viewportByValue[value] ?? 0, total: totalByValue[value] ?? 0))
            }
        }
        return out
    }

    private struct BBox {
        let minLat, maxLat, minLon, maxLon: Double
        init(region: MKCoordinateRegion) {
            minLat = region.center.latitude - region.span.latitudeDelta / 2
            maxLat = region.center.latitude + region.span.latitudeDelta / 2
            minLon = region.center.longitude - region.span.longitudeDelta / 2
            maxLon = region.center.longitude + region.span.longitudeDelta / 2
        }
        func contains(_ c: CLLocationCoordinate2D) -> Bool {
            c.latitude >= minLat && c.latitude <= maxLat && c.longitude >= minLon && c.longitude <= maxLon
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（4 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/LegendCounter.swift PropertyAtlas/PropertyAtlasTests/MapRender/LegendCounterTests.swift
git -c commit.gpgsign=false commit -m "feat(render): LegendCounter grouped viewport/total counts"
```

---

## Task 8: LegendView — 折叠分组 + chip

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LegendView.swift`

按 entityType 分组，每 filter 字段一组，chip = swatch + value + `[viewport/total]` + hide。点 chip → `filterState.toggle`。build verify。

- [ ] **Step 1: 写 LegendView**

```swift
// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LegendView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LegendView: View {
    let rows: [LegendCounter.Row]
    @Bindable var filterState: FilterState

    private var byType: [(type: String, label: String)] {
        [("school", "学校"), ("compound", "小区"), ("poi", "POI"), ("area", "片区")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("图例").font(.system(size: 12, weight: .bold))
            if rows.isEmpty {
                Text("拖动地图后显示").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(byType, id: \.type) { t in
                let typeRows = rows.filter { $0.entityType == t.type }
                if !typeRows.isEmpty { typeSection(label: t.label, rows: typeRows) }
            }
        }
    }

    private func typeSection(label: String, rows: [LegendCounter.Row]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            let groups = Dictionary(grouping: rows, by: { $0.fieldLabel })
            ForEach(groups.keys.sorted(by: { slot(groups[$0]) < slot(groups[$1]) }), id: \.self) { fieldLabel in
                Text(fieldLabel).font(.system(size: 10)).foregroundStyle(.tertiary).padding(.leading, 4)
                ForEach(groups[fieldLabel] ?? []) { row in chip(row) }
            }
        }
    }

    private func slot(_ rows: [LegendCounter.Row]?) -> Int { rows?.first?.slot ?? 99 }

    private func chip(_ row: LegendCounter.Row) -> some View {
        let hidden = filterState.isHidden(entityType: row.entityType, fieldKey: row.fieldKey, value: row.value)
        return Button {
            filterState.toggle(entityType: row.entityType, fieldKey: row.fieldKey, value: row.value)
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

> `HexColor.parse` 在 `MapRender/PinAnnotationView.swift`（Mac Catalyst）已存在。

- [ ] **Step 2: Build verify**

Run: `xcodebuild build -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LegendView.swift
git -c commit.gpgsign=false commit -m "feat(studio): LegendView grouped chips with viewport/total + hide toggle"
```

---

## Task 9: LayersView — layer toggle 列表

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LayersView.swift`

layer toggle 列表 + zoom 范围指示；当前 zoom 不在范围 → 灰显提示。build verify。

- [ ] **Step 1: 写 LayersView**

```swift
// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LayersView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LayersView: View {
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var layerState: LayerState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("图层").font(.system(size: 12, weight: .bold))
            ForEach(layers, id: \.id) { layer in row(layer) }
        }
    }

    private func row(_ layer: Layer) -> some View {
        let inZoom = zoomOK(layer)
        let on = layerState.isEnabled(layer.id)
        return Button { layerState.toggle(layer.id) } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundStyle(on ? Color.accentColor : .secondary)
                if let icon = layer.iconSF { Image(systemName: icon).font(.system(size: 10)) }
                Text(layer.name).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 4)
                Text(zoomLabel(layer)).font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(inZoom ? .secondary : .orange)
            }
            .opacity(inZoom ? 1 : 0.5)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func zoomOK(_ l: Layer) -> Bool {
        if let mn = l.minZoom, currentZoom < mn { return false }
        if let mx = l.maxZoom, currentZoom > mx { return false }
        return true
    }

    private func zoomLabel(_ l: Layer) -> String {
        let mn = l.minZoom.map { String(Int($0)) } ?? "0"
        let mx = l.maxZoom.map { String(Int($0)) } ?? "21"
        return "\(mn)-\(mx)"
    }
}
#endif
```

- [ ] **Step 2: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LayersView.swift
git -c commit.gpgsign=false commit -m "feat(studio): LayersView toggle list with zoom-range indicator"
```

---

## Task 10: LeftDrawerView — 容器

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LeftDrawerView.swift`

Layers + Legend section 垂直堆叠，material 卡片。build verify。

- [ ] **Step 1: 写 LeftDrawerView**

```swift
// PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LeftDrawerView.swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct LeftDrawerView: View {
    let legendRows: [LegendCounter.Row]
    let layers: [Layer]
    let currentZoom: Double
    @Bindable var filterState: FilterState
    @Bindable var layerState: LayerState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LayersView(layers: layers, currentZoom: currentZoom, layerState: layerState)
                Divider().opacity(0.5)
                LegendView(rows: legendRows, filterState: filterState)
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

- [ ] **Step 2: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/LeftDrawer/LeftDrawerView.swift
git -c commit.gpgsign=false commit -m "feat(studio): LeftDrawerView hosting Layers + Legend sections"
```

---

## Task 11: StudioRootView 接线 — visibleEntities × Layer × Filter + Legend + 左抽屉

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`

**这是整合任务 — 先读现有 StudioRootView 全文再改。** 现有 body（P3）已有：themeContext、activeTheme、palettesById、rulesForTheme、visibility、buildPins(highlight:)、buildAreaOverlays、buildEdgeLines、RightDrawer、confirmationDialog、appState、visibleRegion、camera。本任务在其上加 Layer/Filter 可见性 + 左抽屉 + Legend。

- [ ] **Step 1: 加 state + @Query**

`StudioRootView` 内新增：
```swift
    @Query private var layersQuery: [Layer]
    @Query private var filterConfigs: [FilterFieldConfig]
    @State private var filterState = FilterState()
    @State private var layerState = LayerState()
```

- [ ] **Step 2: 加辅助方法**

```swift
    private func layersForDataset(_ dsId: UUID) -> [Layer] {
        layersQuery.filter { $0.datasetId == dsId && !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func legendItems() -> [LegendCounter.Item] {
        var out: [LegendCounter.Item] = []
        for c in compounds where !c.deleted {
            out.append(.init(id: c.id, type: "compound", entity: c.styleEntity, coordinate: c.coordinate))
        }
        for s in schools where !s.deleted {
            out.append(.init(id: s.id, type: "school", entity: s.styleEntity, coordinate: s.coordinate))
        }
        for p in pois where !p.deleted {
            out.append(.init(id: p.id, type: "poi", entity: p.styleEntity, coordinate: p.coordinate))
        }
        return out
    }

    private func fieldKeys(_ dsId: UUID, _ entityType: String) -> [String] {
        filterConfigs.filter { $0.datasetId == dsId && $0.entityType == entityType && !$0.deleted }.map { $0.fieldKey }
    }
```

- [ ] **Step 3: body 内计算 layer/filter 可见集 + legend**

在算 `pins`/`overlays` 之前插入：
```swift
        let zoom = visibleRegion.map { ZoomLevel.from(region: $0) } ?? 12
        let _ = layerState.initializeIfNeeded(enabledIds: activeTheme?.defaultEnabledLayerIds ?? [])
        let items = legendItems()
        let activeLayers = layersForDataset(dsId).map {
            LayerEvaluator.ActiveLayer(
                query: LayerQuery(staticRefsJSON: $0.staticRefsJSON, dynamicQueryJSON: $0.dynamicQueryJSON),
                enabled: layerState.isEnabled($0.id), minZoom: $0.minZoom, maxZoom: $0.maxZoom)
        }
        let layerCands = items.map { LayerEvaluator.Candidate(id: $0.id, type: $0.type, entity: $0.entity) }
        let layerVisible = LayerEvaluator.visibleIds(layers: activeLayers, zoom: zoom, candidates: layerCands)
        let predicate = filterState.predicate
        let legendRows = LegendCounter.rows(
            items: items, configs: filterConfigs.filter { $0.datasetId == dsId },
            region: visibleRegion, filter: predicate, layerVisible: layerVisible,
            swatch: { type, field, value in
                LegendSwatch.fillHex(entityType: type, fieldKey: field, value: value,
                                     theme: activeTheme, rules: rulesForTheme, palettes: palettesById) })
```

> `dsId` 取 `themeContext?.datasetIdValue ?? UUID()`（P3 已用）。`activeTheme`/`rulesForTheme`/`palettesById` 为 P3 已存在的本地 let。

`buildPins` 增参 `layerVisible: Set<UUID>`、`filterPredicate: FilterPredicate`、`datasetId: UUID`；三类 pin 构建处加守卫（compound 示例，school/poi 同）：
```swift
        for c in compounds where !c.deleted && (c.latitude != 0 || c.longitude != 0) {
            guard layerVisible.contains(c.id) else { continue }
            guard filterPredicate.passes(c.styleEntity, fieldKeys: fieldKeys(datasetId, "compound")) else { continue }
            ... // 原 PinAnnotation 构建 + highlight/dimmed 不变
        }
```
`buildAreaOverlays` 增参 `layerVisible: Set<UUID>`，对每 area 加 `guard layerVisible.contains(a.id) else { continue }`（area 不参与 filter）。

调用处传入新参数。

- [ ] **Step 4: ZStack 加左抽屉 + 切 theme 重置**

ZStack 内（RightDrawer 同级）：
```swift
            HStack {
                LeftDrawerView(legendRows: legendRows, layers: layersForDataset(dsId),
                               currentZoom: zoom, filterState: filterState, layerState: layerState)
                    .padding(.top, 80).padding(.leading, 16)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
```
切 theme 重置（监听 active theme id）：
```swift
        .onChange(of: themeContext?.activeTheme?.id) { _, _ in
            layerState.resetForTheme(enabledIds: themeContext?.activeTheme?.defaultEnabledLayerIds ?? [])
            filterState.reset()
        }
```

- [ ] **Step 5: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`（迭代至通过）

- [ ] **Step 6: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/RootView.swift
git -c commit.gpgsign=false commit -m "feat(studio): wire Layer+Filter visibility + Legend + LeftDrawer into StudioRootView"
```

---

## Task 12: 删除天津专用旧件 + LegacyStudioAccessors

**Files:**
- Delete: `PropertyAtlas/PropertyAtlas/Studio/PinFilter.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/StudioLegend.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/SchoolDetailCard.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/LegacyStudioAccessors.swift`

通用 Legend/Filter 已取代；P3 起这三件已 unreferenced（仅互相依赖 + LegacyStudioAccessors）。

- [ ] **Step 1: 确认无外部引用**

```bash
grep -rn "PinFilter\|StudioLegend\|SchoolDetailCard\|legacyTier\|legacyType\|legacyIsJiunian\|legacyDistrict\|legacyIs12Year\|legacyZoneId" PropertyAtlas/PropertyAtlas --include="*.swift" | grep -vE "Studio/PinFilter.swift|Studio/StudioLegend.swift|Studio/SchoolDetailCard.swift|Studio/LegacyStudioAccessors.swift"
```
Expected: empty。若有残余，先修 caller 再删。

- [ ] **Step 2: 删除**

```bash
git rm PropertyAtlas/PropertyAtlas/Studio/PinFilter.swift PropertyAtlas/PropertyAtlas/Studio/StudioLegend.swift PropertyAtlas/PropertyAtlas/Studio/SchoolDetailCard.swift PropertyAtlas/PropertyAtlas/Studio/LegacyStudioAccessors.swift
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(studio): remove Tianjin-specific PinFilter/StudioLegend/SchoolDetailCard + LegacyStudioAccessors"
```

---

## Task 13: smoke + CLAUDE.md P4 节点

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 全套单测**

```bash
xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' > /tmp/p4_test.log 2>&1; echo "EXIT=$?"
echo "passed:"; grep -ac "' passed on '" /tmp/p4_test.log
echo "failed:"; grep -ac "' failed (" /tmp/p4_test.log
```
Expected: 0 failed unit cases（UITests-Runner 环境超时可忽略，与 P2/P3 同）。

- [ ] **Step 2: Mac Catalyst 启动 smoke**

```bash
APP="/Users/fujie/Library/Developer/Xcode/DerivedData/PropertyAtlas-bprzusitconimnalstksmnielbtk/Build/Products/Debug-maccatalyst/PropertyAtlas.app"
open "$APP"; sleep 4
pgrep -x PropertyAtlas >/dev/null && echo "ALIVE" || echo "CRASH"; pkill -x PropertyAtlas
```
Expected: `ALIVE`。人工确认：左抽屉出现 Legend(分组 chip + 双计数) + Layers(toggle)；点 chip 对应 entity 隐显 + count 即时变；toggle layer 影响显示；拖地图 viewport count 刷新。

- [ ] **Step 3: 更新 CLAUDE.md**

Key Documents：把 `- P4-P5 计划: 待写` 替换为
```markdown
- 实施计划 P4 (已完成): `docs/superpowers/plans/2026-06-01-p4-legend-filter-layer.md`
- P5 计划: 待写
```

Critical Architecture 加 NOTE：
```markdown
> **P4 (2026-06-01) 完成后**: 左抽屉回归 — 通用 Legend(`LegendCounter` 按
> type×field×value 分组 + viewport/全集双计数, swatch 由 `LegendSwatch` 经
> StyleResolver 求, chip toggle 走 `FilterState`/`FilterPredicate`, AND 跨 slot)
> + Layers(`LayerEvaluator` enabled×zoom×成员 → 可见 id 集, `LayerState` 运行时态,
> `Theme.defaultEnabledLayerIds` 初始化)。可见集 = visibility × Layer × Filter。
> zoom 由 `ZoomLevel` 从 region 推。天津专用 `PinFilter`/`StudioLegend`/
> `SchoolDetailCard` + `LegacyStudioAccessors` 删除。延后: Settings 编辑页(Layer/
> FilterFieldConfig 编辑、新建)→ P5；CloudKit `.private` + 删 Legacy* @Model → P5。
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): note P4 legend + filter + layer completion"
```

---

## Self-Review 总结

**Spec 覆盖 vs §5.6 / §5.7 / §5.8:**
- §5.6 Legend 自动生成（颜色样块 + 数量）: Task 6/7/8
- §5.7 FilterFieldConfig 渲染 + chip toggle（AND 跨 slot, swatch 实时, viewport/total 双计数, 排除自身字段 filter）: Task 3/4/7/8/11
- §5.8 Layer（static∪dynamic 成员, zoom 触发, enable 态, Theme 初始化, 左抽屉 toggle, 灰显）: Task 1/2/5/9/11
- 旧 PinFilter 迁移（tiers/levels → school slot category/grade/form, 由已种 FilterFieldConfig）: Task 12

**明确延后:** Settings 编辑页（Layer 编辑器/新建、FilterFieldConfig slot 编辑、§6.5 全页）、CloudKit、R-tree spatial index、debounce 200ms 精细化（本期用 onChange(visibleRegion) 触发重算，未显式 debounce — 若卡顿 P5 加）、area 计数（中心点）。

**Placeholder 扫描:** 无 TBD。Task 11 以散文描述接入现有 RootView（基于 P3 已存在方法），其余 step 含完整 code。

**Type 一致性核对:** `ZoomLevel.from(region:)` / `LayerQuery(staticRefsJSON:dynamicQueryJSON:)` + isMatchAll/coveredTypes/staticRefs/dynamicType/dynamicConditions / `LayerEvaluator.{Candidate,ActiveLayer,visibleIds}` / `FilterPredicate.{display,key,passes(excludeFieldKey:)}` / `FilterState.{toggle,isHidden,reset,predicate}` / `LayerState.{initialize,initializeIfNeeded,resetForTheme,isEnabled,toggle}` / `LegendSwatch.fillHex` / `LegendCounter.{Item,Row,rows}` — 跨 task 一致。复用 P1/P2/P3：`StyleEntity.field`、`StyleCondition`、`ConditionEvaluator.matches`、`StyleResolver.resolvePin`、`PinStyle.fillHex`、`HexColor.parse`、`Theme.defaultEnabledLayerIds/visibilityJSON`、`FilterFieldConfig`/`Layer` 字段名按实际模型。Task 6 加"实现前确认 StyleRule init / PinStyle.fillHex"注记。

**已知 follow-up（P5）:** Layer 编辑器+新建、FilterFieldConfig slot 编辑、legend 折叠态持久化(expandedByDefault)、viewport 计数 debounce/缓存签名、area 中心点计数、§6.5 其余 Settings。

---

**End of P4 plan**
