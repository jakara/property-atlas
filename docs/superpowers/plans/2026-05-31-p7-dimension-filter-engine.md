# P7 Dimension + Filter 引擎 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 建通用维度抽象 `Dimension`(layer/entityType/field/edgeField 四源)+ `FilterCondition`/`PrimaryFilter`/`NormalFilter` 值类型 + 维度版可见集求值 + 维度版图例计数。**纯逻辑、纯新增、全单测**;不动 UI / RootView / 旧 `FilterFieldConfig`-`FilterPredicate`-`LegendCounter` 路径(P8 切换时再删)。

**Architecture:** P7 与旧过滤路径**并存**(additive),各自有测试。引擎是纯函数 + 值类型,配置(PrimaryFilter/NormalFilter)作参数传入(P8 才持久化到 `View`)。`Dimension.edgeField` 复用 P6 的 `EdgeStore.relatedFieldValues`。

**Tech Stack:** SwiftData · Swift Testing · 复用 `StyleEntity.field` / `StyleConditionOp` / `EdgeStore.relatedFieldValues` / `EntityKind`。

**前置**: spec `docs/superpowers/specs/2026-05-31-generic-filter-legend-color-redesign.md` §3-§7;P6 已合(`EdgeStore.relatedFieldValues` + `EdgeDirection`)。

**关键现状(供对照,P7 不改它们):**
- `StyleEntity {entityType, id, field(key)->AnyJSON?}`(`MapRender/ConditionEvaluator.swift`)
- `StyleConditionOp {equals,notEquals,inOp="in",contains,gte,lte,exists}`(同文件)
- `EdgeStore.relatedFieldValues(of:edgeLabel:direction:targetField:datasetId:in:)->[String]` + `EdgeDirection{downstream,upstream,either}`
- `EntityKind(rawValue:)` ∈ {compound,school,poi,area}
- 旧 `FilterPredicate.display(AnyJSON?)->String`(复用其字符串化规则)

**新增文件:**
- `DataKit/Dimension.swift`
- `States/FilterCondition.swift`
- `States/PrimaryFilter.swift`(含 NormalFilter)
- `States/DimensionFilterState.swift`
- `MapRender/DimensionLegendCounter.swift`
- `MapRender/VisibilityResolver.swift`
- 对应 6 个测试文件

---

### Task 0: Dimension 值类型 + resolve

**Files:** Create `PropertyAtlas/PropertyAtlas/DataKit/Dimension.swift`; Test `PropertyAtlas/PropertyAtlasTests/DataKit/DimensionTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import SwiftData
@testable import PropertyAtlas

@MainActor
struct DimensionTests {
    private func entity(type: String, fields: [String: AnyJSON]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: fields, customFields: [:])
    }

    @Test func fieldDimensionResolvesValue() {
        let e = entity(type: "compound", fields: ["finishType": .string("精装")])
        let d = Dimension(kind: .field, fieldKey: "finishType")
        #expect(d.resolve(.init(entity: e, layerNames: [], context: nil, datasetId: nil)) == ["精装"])
    }

    @Test func entityTypeDimensionResolvesType() {
        let e = entity(type: "school", fields: [:])
        let d = Dimension(kind: .entityType)
        #expect(d.resolve(.init(entity: e, layerNames: [], context: nil, datasetId: nil)) == ["school"])
    }

    @Test func layerDimensionUsesProvidedNames() {
        let e = entity(type: "poi", fields: [:])
        let d = Dimension(kind: .layer)
        #expect(d.resolve(.init(entity: e, layerNames: ["商业", "教育"], context: nil, datasetId: nil)) == ["商业", "教育"])
    }

    @Test func fieldDimensionEmptyWhenMissing() {
        let e = entity(type: "compound", fields: [:])
        let d = Dimension(kind: .field, fieldKey: "finishType")
        #expect(d.resolve(.init(entity: e, layerNames: [], context: nil, datasetId: nil)).isEmpty)
    }
}
```

- [ ] **Step 2: 跑确认失败**

Run: `cd /Users/fujie/projects/天津买房/.claude/worktrees/p7-dimension-filter-engine/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/DimensionTests 2>&1 | tail -25`
Expected: FAIL(Dimension 未定义)。

- [ ] **Step 3: 实现**

```swift
import Foundation
import SwiftData

enum DimensionKind: String, Codable, CaseIterable {
    case layer, entityType, field, edgeField
}

struct Dimension: Codable, Hashable {
    var kind: DimensionKind
    // field
    var fieldKey: String?
    var fieldSource: String?        // "base" | "custom"(信息性,resolve 不区分)
    // edgeField
    var edgeLabel: String?
    var edgeDirection: String?      // "downstream" | "upstream" | "either"
    var edgeTargetField: String?    // nil = 对端实体名

    init(kind: DimensionKind, fieldKey: String? = nil, fieldSource: String? = nil,
         edgeLabel: String? = nil, edgeDirection: String? = nil, edgeTargetField: String? = nil) {
        self.kind = kind
        self.fieldKey = fieldKey
        self.fieldSource = fieldSource
        self.edgeLabel = edgeLabel
        self.edgeDirection = edgeDirection
        self.edgeTargetField = edgeTargetField
    }

    /// 稳定 key,用于 FilterState 分键 / legend 分组标识。
    var key: String {
        switch kind {
        case .layer: return "layer"
        case .entityType: return "entityType"
        case .field: return "field:\(fieldKey ?? "")"
        case .edgeField: return "edge:\(edgeLabel ?? ""):\(edgeDirection ?? "downstream"):\(edgeTargetField ?? "name")"
        }
    }

    struct Input {
        let entity: StyleEntity
        let layerNames: [String]        // 调用方预算的该实体所属 layer 名集
        let context: ModelContext?      // edgeField 用
        let datasetId: UUID?
    }

    /// 投影实体在此维度的值(可多值;去空)。
    @MainActor
    func resolve(_ input: Input) -> [String] {
        switch kind {
        case .layer:
            return input.layerNames.filter { !$0.isEmpty }
        case .entityType:
            return [input.entity.entityType]
        case .field:
            guard let fk = fieldKey else { return [] }
            let s = FilterPredicate.display(input.entity.field(fk))
            return s.isEmpty ? [] : [s]
        case .edgeField:
            guard let label = edgeLabel, let ctx = input.context, let dsId = input.datasetId,
                  let kind = EntityKind(rawValue: input.entity.entityType) else { return [] }
            let dir: EdgeDirection = {
                switch edgeDirection {
                case "upstream": return .upstream
                case "either": return .either
                default: return .downstream
                }
            }()
            return EdgeStore.relatedFieldValues(
                of: EntityRef(id: input.entity.id, kind: kind),
                edgeLabel: label, direction: dir, targetField: edgeTargetField,
                datasetId: dsId, in: ctx
            )
        }
    }
}
```
> 复用 `FilterPredicate.display`(旧文件,未删)统一字符串化。`StyleEntity` init 是 `(entityType:id:baseFields:customFields:)`(见 ConditionEvaluator.swift)。

- [ ] **Step 4: 跑确认通过**(同 Step 2)
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(dimension): Dimension value type + 4-source resolve"`

---

### Task 1: FilterCondition + evaluate

**Files:** Create `PropertyAtlas/PropertyAtlas/States/FilterCondition.swift`; Test `.../FilterConditionTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
@MainActor
struct FilterConditionTests {
    private func entity(type: String, fields: [String: AnyJSON] = [:]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: fields, customFields: [:])
    }
    private func input(_ e: StyleEntity, layers: [String] = []) -> Dimension.Input {
        .init(entity: e, layerNames: layers, context: nil, datasetId: nil)
    }

    @Test func equalsOnField() {
        let c = FilterCondition(dimension: Dimension(kind: .field, fieldKey: "grade"), op: .equals, value: .string("重点"))
        #expect(c.evaluate(input(entity(type: "school", fields: ["grade": .string("重点")]))))
        #expect(!c.evaluate(input(entity(type: "school", fields: ["grade": .string("普通")]))))
    }

    @Test func inOnEntityType() {
        let c = FilterCondition(dimension: Dimension(kind: .entityType), op: .inOp, value: .array([.string("school"), .string("poi")]))
        #expect(c.evaluate(input(entity(type: "poi"))))
        #expect(!c.evaluate(input(entity(type: "compound"))))
    }

    @Test func inOnLayerMultiValue() {
        // 实体属多 layer,任一命中即过
        let c = FilterCondition(dimension: Dimension(kind: .layer), op: .inOp, value: .array([.string("教育")]))
        #expect(c.evaluate(input(entity(type: "school"), layers: ["商业", "教育"])))
        #expect(!c.evaluate(input(entity(type: "school"), layers: ["商业"])))
    }
}
```

- [ ] **Step 2: 跑确认失败**(`-only-testing:PropertyAtlasTests/FilterConditionTests`)

- [ ] **Step 3: 实现**

```swift
import Foundation

struct FilterCondition: Codable, Hashable {
    var dimension: Dimension
    var op: StyleConditionOp
    var value: AnyJSON

    /// 维度多值语义:op 针对"实体在该维度的值集"判定。
    @MainActor
    func evaluate(_ input: Dimension.Input) -> Bool {
        let values = dimension.resolve(input)
        switch op {
        case .equals:
            return values.contains { AnyJSON.string($0) == value }
        case .notEquals:
            return !values.contains { AnyJSON.string($0) == value }
        case .inOp:
            guard case let .array(opts) = value else { return false }
            let set = Set(opts.compactMap { if case let .string(s) = $0 { return s } else { return nil } })
            return values.contains { set.contains($0) }
        case .contains:
            guard case let .string(needle) = value else { return false }
            return values.contains { $0.contains(needle) }
        case .exists:
            return !values.isEmpty
        case .gte, .lte:
            guard case let .double(r) = numericValue(value) ?? .none else {
                // 退回 int
                return numericCompare(values: values, value: value, op: op)
            }
            return values.contains { (Double($0) ?? .nan).isFinite && compare(Double($0)!, r, op) }
        }
    }

    private func compare(_ l: Double, _ r: Double, _ op: StyleConditionOp) -> Bool {
        op == .gte ? l >= r : l <= r
    }
    private func numericValue(_ v: AnyJSON) -> AnyJSON? {
        if case .double = v { return v }; if case let .int(n) = v { return .double(Double(n)) }; return nil
    }
    private func numericCompare(values: [String], value: AnyJSON, op: StyleConditionOp) -> Bool {
        let r: Double? = { if case let .int(n) = value { return Double(n) }; if case let .double(d) = value { return d }; return nil }()
        guard let r else { return false }
        return values.contains { (Double($0)).map { compare($0, r, op) } ?? false }
    }
}
```
> 注:gte/lte 对多值取"任一满足"。AnyJSON 相等比较已有(`==`,见 ConditionEvaluator 用 `actual == condition.value`)。若编译报 AnyJSON 不 Equatable,确认其已 `: Equatable`(ConditionEvaluator 已用 `==`,应已满足)。

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(filter): FilterCondition over Dimension with multi-value op semantics"`

---

### Task 2: PrimaryFilter + NormalFilter 值类型

**Files:** Create `PropertyAtlas/PropertyAtlas/States/PrimaryFilter.swift`; Test `.../PrimaryFilterTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
@MainActor
struct PrimaryFilterTests {
    private func e(_ type: String, _ f: [String: AnyJSON] = [:]) -> StyleEntity {
        StyleEntity(entityType: type, id: UUID(), baseFields: f, customFields: [:])
    }
    private func inp(_ s: StyleEntity, _ layers: [String] = []) -> Dimension.Input {
        .init(entity: s, layerNames: layers, context: nil, datasetId: nil)
    }

    @Test func matchesAndsAllConditions() {
        let pf = PrimaryFilter(
            conditions: [
                FilterCondition(dimension: Dimension(kind: .entityType), op: .inOp, value: .array([.string("school")])),
                FilterCondition(dimension: Dimension(kind: .field, fieldKey: "grade"), op: .equals, value: .string("重点")),
            ],
            groupBy: Dimension(kind: .field, fieldKey: "grade")
        )
        #expect(pf.matches(inp(e("school", ["grade": .string("重点")]))))
        #expect(!pf.matches(inp(e("school", ["grade": .string("普通")]))))   // 第二条不过
        #expect(!pf.matches(inp(e("compound", ["grade": .string("重点")])))) // 第一条不过
    }

    @Test func groupValueFromGroupBy() {
        let pf = PrimaryFilter(conditions: [], groupBy: Dimension(kind: .field, fieldKey: "grade"))
        #expect(pf.groupValues(inp(e("school", ["grade": .string("区重点")]))) == ["区重点"])
    }

    @Test func noGroupByYieldsEmpty() {
        let pf = PrimaryFilter(conditions: [], groupBy: nil)
        #expect(pf.groupValues(inp(e("school", ["grade": .string("重点")]))).isEmpty)
    }
}
```

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**

```swift
import Foundation

struct PrimaryFilter: Codable, Hashable {
    var conditions: [FilterCondition]
    var groupBy: Dimension?

    @MainActor
    func matches(_ input: Dimension.Input) -> Bool {
        for c in conditions where !c.evaluate(input) { return false }
        return true
    }

    @MainActor
    func groupValues(_ input: Dimension.Input) -> [String] {
        groupBy?.resolve(input) ?? []
    }
}

struct NormalFilter: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var dimension: Dimension

    init(id: UUID = UUID(), name: String, dimension: Dimension) {
        self.id = id; self.name = name; self.dimension = dimension
    }
}
```

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(filter): PrimaryFilter (conditions+groupBy) + NormalFilter value types"`

---

### Task 3: DimensionFilterState(维度版运行时隐藏态)

**Files:** Create `PropertyAtlas/PropertyAtlas/States/DimensionFilterState.swift`; Test `.../DimensionFilterStateTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
@MainActor
struct DimensionFilterStateTests {
    @Test func toggleHidesAndUnhides() {
        let s = DimensionFilterState()
        let dimKey = Dimension(kind: .field, fieldKey: "grade").key
        #expect(!s.isHidden(dimensionKey: dimKey, value: "重点"))
        s.toggle(dimensionKey: dimKey, value: "重点")
        #expect(s.isHidden(dimensionKey: dimKey, value: "重点"))
        s.toggle(dimensionKey: dimKey, value: "重点")
        #expect(!s.isHidden(dimensionKey: dimKey, value: "重点"))
    }

    @Test func resetClears() {
        let s = DimensionFilterState()
        let k = Dimension(kind: .entityType).key
        s.toggle(dimensionKey: k, value: "school")
        s.reset()
        #expect(!s.isHidden(dimensionKey: k, value: "school"))
    }
}
```

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class DimensionFilterState {
    /// key = Dimension.key → 被隐藏的值集
    private(set) var hidden: [String: Set<String>] = [:]

    func isHidden(dimensionKey: String, value: String) -> Bool {
        hidden[dimensionKey]?.contains(value) == true
    }

    func toggle(dimensionKey: String, value: String) {
        var set = hidden[dimensionKey] ?? []
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
        hidden[dimensionKey] = set.isEmpty ? nil : set
    }

    func reset() { hidden = [:] }
}
```

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(filter): DimensionFilterState (per-dimension hidden values)"`

---

### Task 4: VisibilityResolver(可见集求值)

**Files:** Create `PropertyAtlas/PropertyAtlas/MapRender/VisibilityResolver.swift`; Test `.../VisibilityResolverTests.swift`

可见 = layerVisible(传入,来自 P4 `LayerEvaluator`)∩ primaryFilter.matches ∩ ¬被隐藏(primary groupBy + 各 normal filter 的维度值)。

- [ ] **Step 1: 写失败测试**

```swift
@MainActor
struct VisibilityResolverTests {
    private func item(_ id: UUID, _ type: String, _ f: [String: AnyJSON] = [:]) -> VisibilityResolver.Candidate {
        .init(id: id, entity: StyleEntity(entityType: type, id: id, baseFields: f, customFields: [:]), layerNames: [])
    }

    @Test func filtersByPrimaryConditionAndHidden() {
        let a = UUID(), b = UUID()
        let cands = [
            item(a, "school", ["grade": .string("重点")]),
            item(b, "school", ["grade": .string("普通")]),
        ]
        let pf = PrimaryFilter(conditions: [], groupBy: Dimension(kind: .field, fieldKey: "grade"))
        let fs = DimensionFilterState()
        fs.toggle(dimensionKey: Dimension(kind: .field, fieldKey: "grade").key, value: "普通")  // 隐藏普通
        let visible = VisibilityResolver.visibleIds(
            candidates: cands, layerVisible: Set([a, b]),
            primary: pf, normals: [], filterState: fs, context: nil, datasetId: nil
        )
        #expect(visible == Set([a]))   // b(普通)被隐
    }

    @Test func excludedByLayerVisible() {
        let a = UUID()
        let cands = [item(a, "school")]
        let visible = VisibilityResolver.visibleIds(
            candidates: cands, layerVisible: Set(),   // 不在 layer 可见集
            primary: PrimaryFilter(conditions: [], groupBy: nil), normals: [],
            filterState: DimensionFilterState(), context: nil, datasetId: nil
        )
        #expect(visible.isEmpty)
    }
}
```

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**

```swift
import Foundation
import SwiftData

@MainActor
enum VisibilityResolver {
    struct Candidate {
        let id: UUID
        let entity: StyleEntity
        let layerNames: [String]
    }

    static func visibleIds(
        candidates: [Candidate],
        layerVisible: Set<UUID>,
        primary: PrimaryFilter,
        normals: [NormalFilter],
        filterState: DimensionFilterState,
        context: ModelContext?,
        datasetId: UUID?
    ) -> Set<UUID> {
        var out = Set<UUID>()
        for c in candidates {
            guard layerVisible.contains(c.id) else { continue }
            let input = Dimension.Input(entity: c.entity, layerNames: c.layerNames, context: context, datasetId: datasetId)
            guard primary.matches(input) else { continue }
            if isHiddenByAnyChip(input: input, primary: primary, normals: normals, filterState: filterState) { continue }
            out.insert(c.id)
        }
        return out
    }

    /// primary groupBy 的值 + 各 normal filter 维度的值,任一被 filterState 隐藏 → 隐藏该实体。
    private static func isHiddenByAnyChip(
        input: Dimension.Input, primary: PrimaryFilter, normals: [NormalFilter], filterState: DimensionFilterState
    ) -> Bool {
        if let gb = primary.groupBy {
            for v in gb.resolve(input) where filterState.isHidden(dimensionKey: gb.key, value: v) { return true }
        }
        for nf in normals {
            for v in nf.dimension.resolve(input) where filterState.isHidden(dimensionKey: nf.dimension.key, value: v) { return true }
        }
        return false
    }
}
```

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(filter): VisibilityResolver (layer ∩ primary ∩ not-hidden)"`

---

### Task 5: DimensionLegendCounter(维度版图例计数)

**Files:** Create `PropertyAtlas/PropertyAtlas/MapRender/DimensionLegendCounter.swift`; Test `.../DimensionLegendCounterTests.swift`

按一个 Dimension 分组,出每值的 viewport / total 计数。primary(groupBy)与各 normal filter 各调一次。

- [ ] **Step 1: 写失败测试**

```swift
import CoreLocation
import MapKit

@MainActor
struct DimensionLegendCounterTests {
    private func item(_ type: String, _ f: [String: AnyJSON], _ lat: Double) -> DimensionLegendCounter.Item {
        .init(id: UUID(), entity: StyleEntity(entityType: type, id: UUID(), baseFields: f, customFields: [:]),
              coordinate: CLLocationCoordinate2D(latitude: lat, longitude: 117.2), layerNames: [])
    }

    @Test func countsByDimensionValue() {
        let items = [
            item("school", ["grade": .string("重点")], 39.1),
            item("school", ["grade": .string("重点")], 39.1),
            item("school", ["grade": .string("普通")], 39.1),
        ]
        let rows = DimensionLegendCounter.rows(
            dimension: Dimension(kind: .field, fieldKey: "grade"),
            items: items, region: nil, context: nil, datasetId: nil,
            swatch: { _ in "#FF0000" }
        )
        let byVal = Dictionary(uniqueKeysWithValues: rows.map { ($0.value, $0.total) })
        #expect(byVal["重点"] == 2)
        #expect(byVal["普通"] == 1)
    }
}
```

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**

```swift
import CoreLocation
import Foundation
import MapKit
import SwiftData

@MainActor
enum DimensionLegendCounter {
    struct Item {
        let id: UUID
        let entity: StyleEntity
        let coordinate: CLLocationCoordinate2D
        let layerNames: [String]
    }

    struct Row: Identifiable {
        let dimensionKey: String
        let value: String
        let swatchHex: String
        let viewport: Int
        let total: Int
        var id: String { "\(dimensionKey).\(value)" }
    }

    static func rows(
        dimension: Dimension,
        items: [Item],
        region: MKCoordinateRegion?,
        context: ModelContext?,
        datasetId: UUID?,
        swatch: (_ value: String) -> String
    ) -> [Row] {
        let bbox = region.map { BBox(region: $0) }
        var totalByValue: [String: Int] = [:]
        var viewportByValue: [String: Int] = [:]
        for it in items {
            let input = Dimension.Input(entity: it.entity, layerNames: it.layerNames, context: context, datasetId: datasetId)
            for value in dimension.resolve(input) where !value.isEmpty {
                totalByValue[value, default: 0] += 1
                if let bbox, bbox.contains(it.coordinate) { viewportByValue[value, default: 0] += 1 }
            }
        }
        return totalByValue.keys.sorted().map { v in
            Row(dimensionKey: dimension.key, value: v, swatchHex: swatch(v),
                viewport: viewportByValue[v] ?? 0, total: totalByValue[v] ?? 0)
        }
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
> 与旧 `LegendCounter` 并存;旧的按 `FilterFieldConfig.fieldKey`,新的按任意 `Dimension`。P8 切 RootView 后删旧。

- [ ] **Step 4: 跑确认通过**
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(legend): DimensionLegendCounter (count by arbitrary Dimension)"`

---

### Task 6: 全量测试 + CLAUDE.md

**Files:** Modify `CLAUDE.md`

- [ ] **Step 1: 全量单测**

Run: `cd /Users/fujie/projects/天津买房/.claude/worktrees/p7-dimension-filter-engine/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -40`
Expected: 全 unit PASS(含 6 个新套件;旧 FilterPredicate/LegendCounter 测试仍在仍过)。**P7 无 DB/migrator 改动 → 无清库 smoke**。

- [ ] **Step 2: 更新 CLAUDE.md**

P6 节点后加:
```markdown
> **P7 (2026-05-31) 完成后**: 通用维度过滤引擎(纯逻辑,与旧路径并存)。
> `Dimension`(layer/entityType/field/edgeField 四源 resolve)+ `FilterCondition`
> (维度多值 op)+ `PrimaryFilter`(conditions AND + 可选 groupBy)+ `NormalFilter`
> + `DimensionFilterState`(按 Dimension.key 隐藏值)+ `VisibilityResolver`
> (layer ∩ primary ∩ ¬隐藏)+ `DimensionLegendCounter`(按任意维度计数)。
> 旧 `FilterFieldConfig`/`FilterPredicate`/`LegendCounter` 未动,P8 切 RootView 时删。
> 后续 P8(View 模型 + Theme 下沉 + PaletteAssigner + 接 RootView + 删旧)。
```
并在计划列表加 P7 行。

- [ ] **Step 3: 提交** `git -c commit.gpgsign=false commit -am "docs(claude): note P7 dimension filter engine completion"`

---

## Self-Review

- **Spec 覆盖**:P7 = spec §9 第 2 项 + §3(Dimension)+ §4(PrimaryFilter/NormalFilter/Condition)+ §7(可见集)。LegendCounter/FilterState "改造" 以**并存新增**实现(P8 删旧),保证 P7 可编译、旧 UI 不断。
- **类型一致**:`Dimension.Input` 在 T0 定义,T1/T2/T4/T5 复用。`Dimension.key` T0 定义,T3(FilterState 分键)/T5(Row.dimensionKey)用。`FilterCondition`/`PrimaryFilter`/`NormalFilter` 链一致。`EdgeStore.relatedFieldValues`/`EdgeDirection`(P6)+ `StyleConditionOp`/`StyleEntity`(现有)签名对齐。
- **占位扫描**:无 TBD;每任务完整代码 + 测试。
- **风险**:① `AnyJSON: Equatable` 须成立(`ConditionEvaluator` 已用 `==`,应满足;否则 T1 编译报错时确认 conformance)。② gte/lte 对字符串值的数值化 best-effort(`Double($0)`),非数字字段返回 false,可接受。③ P7 新增代码在 P8 接入前"未被 RootView 使用",但有完整单测,非死代码。④ `Dimension.resolve` 是 `@MainActor`(因 edgeField 走 EntityReader/@MainActor);所有调用点测试均 `@MainActor struct`。
- **edgeField 真实投影未在 P7 单测覆盖**(需 ModelContext + 真 Edge):T0 测试用 context:nil 跳过 edgeField 分支;edgeField 端到端已由 P6 `EdgeStoreTests` 覆盖。P8 接入时补集成验证。
