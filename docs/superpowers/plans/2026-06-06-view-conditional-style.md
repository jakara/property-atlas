# 视图条件样式 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把条件样式作为视图持有的通用能力加回:`ViewStyleRule`(每视图×entityType 的规则,设任意属性子集)+ `ViewStyleCondition`(多字段 AND 谓词,typed),接入求值链(builtin→视图默认→**条件规则**→分组染色→实体 override),并经启动迁移自动还原学校 重/区/普 标识。

**Architecture:** 纯加法 schema(两新 @Model)。求值复用现有 `ConditionEvaluator`;为避免 resolver 内查 DB,RootView 预取规则+条件组装成纯内存值类型 `ResolvedStyleRule` 喂 resolver。迁移在 `StyleConsolidationMigrator` 加第 3 趟(幂等,每视图闸=已有 ViewStyleRule 行),把旧 `StyleRule`+`conditionsJSON` 翻成新模型。

**Tech Stack:** SwiftUI · SwiftData · MapKit · Swift Testing · Mac Catalyst (`#if targetEnvironment(macCatalyst)`)。

**前置事实(已核实,基于分支 `feat/view-owned-style` 当前状态):**
- spec:`docs/superpowers/specs/2026-06-06-view-conditional-style-design.md`。
- `StyleResolver.resolvePin(entity:viewStyle:groupFillHex:)` / `resolveArea(entity:viewStyle:)`(`MapRender/StyleResolver.swift`,42 行,Stage A 重写后)。
- `StyleCondition { field:String, op:StyleConditionOp, value:AnyJSON }`、`enum StyleConditionOp { equals,notEquals,inOp="in",contains,gte,lte,exists }`、`ConditionEvaluator.matches(entity:StyleEntity, condition:StyleCondition)->Bool`(`MapRender/ConditionEvaluator.swift`)。
- `StyleFieldConvert.pinPartial(shape:fillHex:strokeHex:glyph:glyphHex:size:labelVisible:)->PartialPinStyle` / `.areaPartial(fillHex:fillOpacity:strokeHex:strokeWidth:labelVisible:)->PartialAreaStyle`(`MapRender/StyleFieldConvert.swift`)。
- `AnyJSON`(`DataKit/JSONHelpers.swift`):`.string/.int/.double/.bool/.array([AnyJSON])/.object/.null`。`JSONHelpers.decode<T:Decodable>(_:String)->T`。
- `RootView.swift`(`StudioRootView`):`buildViewStyles(dsId:viewId:)->[String:ViewEntityStyle]`(L672)、`rebuildContent`(L435,调 `buildPins`/`buildAreaOverlays` 传 `viewStyles`)、`buildPins(cands:visibleIds:groupColors:viewStyles:highlight:)`(L586)、`buildAreaOverlays(areas:visibleIds:viewStyles:)`(L611)、`contentSignature`(L370,已 fetch ViewEntityStyle by activeViewId)。
- `StyleConsolidationMigrator`(`DataKit/StyleConsolidationMigrator.swift`):`run(in:)` 调 `migrateViews`+`migrateEntityOverrides`+`save`;private `resolveTheme(for:in:)->Theme?`、`themeById(_:in:)->Theme?`。
- 旧 `StyleRule`(`Models/Style/StyleRule.swift`,仍在,Stage B 删):`entityType,conditionsJSON,priority,enabled,appliesShape,appliesFillMode,appliesFillHex,appliesPaletteId,appliesPaletteKeyField,appliesStrokeHex,appliesGlyph,appliesGlyphHex,appliesSize:Int?,appliesLabelVisible:Bool?,appliesFillOpacity:Double?,appliesStrokeWidth:Double?`。
- seed 学校规则(`LegacyMigrator.seedSchoolStyleRules`):base 规则(无条件,shape=square,labelVisible=true,priority 0)+ 3 grade 规则(grade==重点/区重点/普通 → glyph 重/重/普,fill #FF3B30/#FF9500/#8E8E93,glyphHex #FFFFFF,labelVisible true,priority 10/11/12),挂 t1/t2 themes。
- `ModelSchema.allTypes`(`DataKit/ModelSchema.swift`)当前含 `... Layer.self, MapView.self, ViewEntityStyle.self, ...`。
- `FieldKeyCatalog.fields(entityType:datasetId:context:)->[FieldItem{key,label}]`(`DataKit/FieldKeyCatalog.swift`)。
- 现有 UI 控件:`ColorHexField(title:hex:)`、`StudioChip(_:isOn:action:)`、`StudioDisclosure(_:summary:open:){}`、`SettingsCard(_:){}`、`SettingsRow(title:){}`、`RowDivider()`、`.glassField()`、`.tbtn(.ghost)`/`.tbtn(.dangerGhost)`、`Studio.sans/on2/cool`。`EntityDefaultStyleEditor`(`Studio/Settings/Components/EntityDefaultStyleEditor.swift`)= 单类型固定默认编辑参考。
- 工程 folder-sync(新文件免 pbxproj);测试 `PropertyAtlasTests/`,Swift Testing。

---

## 文件结构

**新建**
- `Models/Display/ViewStyleRule.swift` — 条件规则 @Model
- `Models/Display/ViewStyleCondition.swift` — 规则谓词 @Model
- `DataKit/ViewStyleConditionCodec.swift` — typed 列 ⇄ `StyleCondition` / `AnyJSON`(纯逻辑,可测)
- `MapRender/ResolvedStyleRule.swift` — resolver 用纯内存值类型
- `Studio/Settings/Components/StyleConditionRow.swift` — 单谓词编辑(字段/op/值)
- `Studio/Settings/Components/ViewStyleRuleEditor.swift` — 单规则编辑(条件+样式)
- `Studio/Settings/Components/ViewStyleRulesSection.swift` — 某 entityType 的规则列表 + 加规则
- 测试:`PropertyAtlasTests/MapRender/StyleResolverRuleTests.swift`、`PropertyAtlasTests/DataKit/ViewStyleConditionCodecTests.swift`、`PropertyAtlasTests/DataKit/StyleConsolidationMigratorRuleTests.swift`

**修改**
- `DataKit/ModelSchema.swift` — 注册两新 @Model
- `MapRender/StyleResolver.swift` — `resolvePin`/`resolveArea` 加 `rules:[ResolvedStyleRule]`
- `RootView.swift` — `buildViewStyleRules`、wire `buildPins`/`buildAreaOverlays`、`contentSignature`
- `DataKit/StyleConsolidationMigrator.swift` — 加 `migrateStyleRules`
- `Studio/Settings/ViewSettingsTab.swift` — 每 entityType 挂 `ViewStyleRulesSection`

---

### Task 1: ViewStyleRule + ViewStyleCondition @Models + schema

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Display/ViewStyleRule.swift`
- Create: `PropertyAtlas/PropertyAtlas/Models/Display/ViewStyleCondition.swift`
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift`

- [ ] **Step 1: ViewStyleRule**

`Models/Display/ViewStyleRule.swift`:
```swift
import Foundation
import SwiftData

/// 视图持有的条件样式规则(spec: 条件层)。每 (viewId × entityType) 可 0..N 条。
/// 命中(全部 ViewStyleCondition AND)则其非 nil 属性列覆盖视图固定默认。priority 升序合并。
@Model
final class ViewStyleRule {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var viewId: UUID = UUID()
    var entityType: String = ""
    var priority: Int = 0
    var enabled: Bool = true

    var shape: String?
    var fillHex: String?
    var strokeHex: String?
    var glyph: String?
    var glyphHex: String?
    var size: Int?
    var labelVisible: Bool?
    var fillOpacity: Double?
    var strokeWidth: Double?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), datasetId: UUID, viewId: UUID, entityType: String) {
        self.id = id
        self.datasetId = datasetId
        self.viewId = viewId
        self.entityType = entityType
    }
}
```

- [ ] **Step 2: ViewStyleCondition**

`Models/Display/ViewStyleCondition.swift`:
```swift
import Foundation
import SwiftData

/// ViewStyleRule 的谓词。同 ruleId 下多条 AND。op = StyleConditionOp rawValue。
/// equals/notEquals/contains/gte/lte 用 valueString;in 用 valueList;exists 无值。
@Model
final class ViewStyleCondition {
    var id: UUID = UUID()
    var ruleId: UUID = UUID()
    var field: String = ""
    var op: String = "equals"
    var valueString: String?
    var valueList: [String] = []
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), ruleId: UUID, field: String, op: String) {
        self.id = id
        self.ruleId = ruleId
        self.field = field
        self.op = op
    }
}
```

- [ ] **Step 3: 注册 schema**

`DataKit/ModelSchema.swift`,把含 `ViewEntityStyle.self` 的那行改为:
```swift
        Layer.self, MapView.self, ViewEntityStyle.self, ViewStyleRule.self, ViewStyleCondition.self,
```

- [ ] **Step 4: 编译**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交**
```bash
cd /Users/fujie/projects/天津买房
git add PropertyAtlas/PropertyAtlas/Models/Display/ViewStyleRule.swift PropertyAtlas/PropertyAtlas/Models/Display/ViewStyleCondition.swift PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift
git commit -m "feat(style): ViewStyleRule + ViewStyleCondition @Models (conditional layer)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: ViewStyleConditionCodec(typed ⇄ StyleCondition/AnyJSON,TDD)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/ViewStyleConditionCodec.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/ViewStyleConditionCodecTests.swift`

> 两个方向:① 求值用(typed 列 → `StyleCondition`)② 迁移用(`AnyJSON` → typed 列)。

- [ ] **Step 1: 写失败测试**

`PropertyAtlasTests/DataKit/ViewStyleConditionCodecTests.swift`:
```swift
import Foundation
import Testing
@testable import PropertyAtlas

struct ViewStyleConditionCodecTests {
    @Test func equalsBuildsStringCondition() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "grade", op: .equals, valueString: "重点", valueList: []
        )
        #expect(cond.field == "grade")
        #expect(cond.op == .equals)
        #expect(cond.value == .string("重点"))
    }

    @Test func inBuildsArrayCondition() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "tags", op: .inOp, valueString: nil, valueList: ["a", "b"]
        )
        #expect(cond.value == .array([.string("a"), .string("b")]))
    }

    @Test func gteParsesNumber() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "capacity", op: .gte, valueString: "100", valueList: []
        )
        #expect(cond.value == .double(100))
    }

    @Test func existsBuildsNull() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "address", op: .exists, valueString: nil, valueList: []
        )
        #expect(cond.value == .null)
    }

    @Test func columnsFromStringValue() {
        let cols = ViewStyleConditionCodec.columns(from: .string("重点"), op: .equals)
        #expect(cols.valueString == "重点")
        #expect(cols.valueList.isEmpty)
    }

    @Test func columnsFromArrayValue() {
        let cols = ViewStyleConditionCodec.columns(from: .array([.string("a"), .int(2)]), op: .inOp)
        #expect(cols.valueList == ["a", "2"])
        #expect(cols.valueString == nil)
    }

    @Test func columnsFromNumericValue() {
        let cols = ViewStyleConditionCodec.columns(from: .int(100), op: .gte)
        #expect(cols.valueString == "100")
    }
}
```

- [ ] **Step 2: 跑测试看失败**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "Cannot find 'ViewStyleConditionCodec'|BUILD FAILED" | head`
Expected: 编译失败

- [ ] **Step 3: 实现**

`DataKit/ViewStyleConditionCodec.swift`:
```swift
import Foundation

/// ViewStyleCondition 的 typed 列 ⇄ StyleCondition / AnyJSON。
/// 求值:styleCondition(...) 喂 ConditionEvaluator。迁移:columns(from:op:) 从旧 AnyJSON 取列。
enum ViewStyleConditionCodec {
    static func styleCondition(
        field: String, op: StyleConditionOp, valueString: String?, valueList: [String]
    ) -> StyleCondition {
        let value: AnyJSON
        switch op {
        case .inOp:
            value = .array(valueList.map { .string($0) })
        case .exists:
            value = .null
        case .gte, .lte:
            if let number = Double(valueString ?? "") {
                value = .double(number)
            } else {
                value = .string(valueString ?? "")
            }
        default:
            value = .string(valueString ?? "")
        }
        return StyleCondition(field: field, op: op, value: value)
    }

    static func columns(from value: AnyJSON, op: StyleConditionOp) -> (valueString: String?, valueList: [String]) {
        switch value {
        case let .string(text):
            return (text, [])
        case let .int(number):
            return (String(number), [])
        case let .double(number):
            return (String(number), [])
        case let .bool(flag):
            return (String(flag), [])
        case let .array(items):
            return (nil, items.map { stringify($0) })
        case .null, .object:
            return (nil, [])
        }
    }

    private static func stringify(_ value: AnyJSON) -> String {
        switch value {
        case let .string(text): text
        case let .int(number): String(number)
        case let .double(number): String(number)
        case let .bool(flag): String(flag)
        default: ""
        }
    }
}
```

- [ ] **Step 4: 跑测试看通过**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "ViewStyleConditionCodecTests|TEST (SUCCEEDED|FAILED)" | tail`
Expected: 7 测试通过

- [ ] **Step 5: 提交**
```bash
cd /Users/fujie/projects/天津买房
git add PropertyAtlas/PropertyAtlas/DataKit/ViewStyleConditionCodec.swift PropertyAtlas/PropertyAtlasTests/DataKit/ViewStyleConditionCodecTests.swift
git commit -m "feat(style): ViewStyleConditionCodec (typed cols <-> StyleCondition/AnyJSON)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: ResolvedStyleRule + StyleResolver 条件层 + RootView 接入(TDD)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/ResolvedStyleRule.swift`
- Modify: `PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift`
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/StyleResolverRuleTests.swift`

- [ ] **Step 1: ResolvedStyleRule 值类型**

`MapRender/ResolvedStyleRule.swift`:
```swift
import Foundation

/// resolver 用的纯内存规则(RootView 预取时由 ViewStyleRule + 其 ViewStyleCondition 组装)。
/// 避免 resolver 内查 DB / 解析 JSON。conditions 全部 AND;空 → 永远命中。
struct ResolvedStyleRule {
    let pinPartial: PartialPinStyle
    let areaPartial: PartialAreaStyle
    let priority: Int
    let enabled: Bool
    let conditions: [StyleCondition]
}
```

- [ ] **Step 2: 写失败测试(条件层求值)**

`PropertyAtlasTests/MapRender/StyleResolverRuleTests.swift`:
```swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleResolverRuleTests {
    private func school(grade: String) -> StyleEntity {
        StyleEntity(entityType: "school", id: UUID(),
                    baseFields: ["grade": .string(grade)], customFields: [:])
    }

    private func rule(grade: String, fill: String, priority: Int = 10, enabled: Bool = true) -> ResolvedStyleRule {
        ResolvedStyleRule(
            pinPartial: PartialPinStyle(fillHex: fill),
            areaPartial: PartialAreaStyle(),
            priority: priority, enabled: enabled,
            conditions: [StyleCondition(field: "grade", op: .equals, value: .string(grade))]
        )
    }

    @Test func matchingRuleApplies() {
        let style = StyleResolver.resolvePin(
            entity: school(grade: "重点"), viewStyle: nil,
            rules: [rule(grade: "重点", fill: "#FF0000")], groupFillHex: nil
        )
        #expect(style.fillHex == "#FF0000")
    }

    @Test func nonMatchingRuleSkipped() {
        let style = StyleResolver.resolvePin(
            entity: school(grade: "普通"), viewStyle: nil,
            rules: [rule(grade: "重点", fill: "#FF0000")], groupFillHex: nil
        )
        #expect(style.fillHex == "#A8A8A8") // builtin
    }

    @Test func disabledRuleSkipped() {
        let style = StyleResolver.resolvePin(
            entity: school(grade: "重点"), viewStyle: nil,
            rules: [rule(grade: "重点", fill: "#FF0000", enabled: false)], groupFillHex: nil
        )
        #expect(style.fillHex == "#A8A8A8")
    }

    @Test func higherPriorityWinsWhenBothMatch() {
        // rules 已按 priority 升序传入;高 priority 后 merge 覆盖
        let low = ResolvedStyleRule(pinPartial: PartialPinStyle(fillHex: "#111111"),
                                    areaPartial: PartialAreaStyle(), priority: 1, enabled: true,
                                    conditions: [])
        let high = ResolvedStyleRule(pinPartial: PartialPinStyle(fillHex: "#222222"),
                                     areaPartial: PartialAreaStyle(), priority: 9, enabled: true,
                                     conditions: [])
        let style = StyleResolver.resolvePin(
            entity: school(grade: "x"), viewStyle: nil, rules: [low, high], groupFillHex: nil
        )
        #expect(style.fillHex == "#222222")
    }

    @Test func ruleBeatsViewStyleButGroupFillBeatsRule() {
        let viewStyle = ViewEntityStyle(datasetId: UUID(), viewId: UUID(), entityType: "school")
        viewStyle.fillHex = "#000000"
        let style = StyleResolver.resolvePin(
            entity: school(grade: "重点"), viewStyle: viewStyle,
            rules: [rule(grade: "重点", fill: "#FF0000")], groupFillHex: "#00FF00"
        )
        #expect(style.fillHex == "#00FF00") // groupFill 在规则之后
    }

    @Test func emptyConditionsAlwaysMatch() {
        let always = ResolvedStyleRule(pinPartial: PartialPinStyle(glyph: "★"),
                                       areaPartial: PartialAreaStyle(), priority: 0, enabled: true,
                                       conditions: [])
        let style = StyleResolver.resolvePin(
            entity: school(grade: "any"), viewStyle: nil, rules: [always], groupFillHex: nil
        )
        #expect(style.glyph == "★")
    }
}
```

- [ ] **Step 3: 跑测试看失败**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "extra argument 'rules'|Cannot find|BUILD FAILED" | head`
Expected: 编译失败(`resolvePin` 无 `rules` 参)

- [ ] **Step 4: StyleResolver 加条件层**

`MapRender/StyleResolver.swift` 整体替换为:
```swift
import CoreGraphics
import Foundation

@MainActor
enum StyleResolver {
    static func resolvePin(
        entity: StyleEntity,
        viewStyle: ViewEntityStyle?,
        rules: [ResolvedStyleRule] = [],
        groupFillHex: String? = nil
    ) -> PinStyle {
        let base = StyleDefaults.builtinPin(for: entity.entityType)
        var partial = PartialPinStyle()
        if let viewStyle {
            partial.merge(StyleFieldConvert.pinPartial(
                shape: viewStyle.shape, fillHex: viewStyle.fillHex, strokeHex: viewStyle.strokeHex,
                glyph: viewStyle.glyph, glyphHex: viewStyle.glyphHex,
                size: viewStyle.size, labelVisible: viewStyle.labelVisible
            ))
        }
        for rule in rules where rule.enabled && matches(rule, entity) {
            partial.merge(rule.pinPartial)
        }
        if let groupFillHex { partial.fillHex = groupFillHex }
        partial.merge(entity.overridePin)
        return partial.finalize(default: base)
    }

    static func resolveArea(
        entity: StyleEntity,
        viewStyle: ViewEntityStyle?,
        rules: [ResolvedStyleRule] = []
    ) -> AreaStyle {
        let base = StyleDefaults.builtinArea()
        var partial = PartialAreaStyle()
        if let viewStyle {
            partial.merge(StyleFieldConvert.areaPartial(
                fillHex: viewStyle.fillHex, fillOpacity: viewStyle.fillOpacity,
                strokeHex: viewStyle.strokeHex, strokeWidth: viewStyle.strokeWidth,
                labelVisible: viewStyle.labelVisible
            ))
        }
        for rule in rules where rule.enabled && matches(rule, entity) {
            partial.merge(rule.areaPartial)
        }
        partial.merge(entity.overrideArea)
        return partial.finalize(default: base)
    }

    /// 规则全部条件 AND 命中(空条件 → true)。rules 由调用方按 priority 升序传入。
    private static func matches(_ rule: ResolvedStyleRule, _ entity: StyleEntity) -> Bool {
        rule.conditions.allSatisfy { ConditionEvaluator.matches(entity: entity, condition: $0) }
    }
}
```

- [ ] **Step 5: RootView — 预取规则 + 接入**

(a) 在 `buildViewStyles`(L672 附近)之后加预取方法:
```swift
    /// 按 viewId 预取该视图全部 ViewStyleRule(+ 各自 ViewStyleCondition)→ 按 entityType 分组、
    /// priority 升序的 ResolvedStyleRule。resolver 纯内存,不再查 DB。
    private func buildViewStyleRules(dsId: UUID, viewId: UUID?) -> [String: [ResolvedStyleRule]] {
        guard let viewId else { return [:] }
        let ruleFetch = FetchDescriptor<ViewStyleRule>(
            predicate: #Predicate { $0.datasetId == dsId && $0.viewId == viewId && !$0.deleted },
            sortBy: [SortDescriptor(\.priority)]
        )
        let rules = (try? modelContext.fetch(ruleFetch)) ?? []
        var out: [String: [ResolvedStyleRule]] = [:]
        for rule in rules {
            let ruleId = rule.id
            let condFetch = FetchDescriptor<ViewStyleCondition>(
                predicate: #Predicate { $0.ruleId == ruleId && !$0.deleted },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            let conditions = ((try? modelContext.fetch(condFetch)) ?? []).map { condition in
                ViewStyleConditionCodec.styleCondition(
                    field: condition.field,
                    op: StyleConditionOp(rawValue: condition.op) ?? .equals,
                    valueString: condition.valueString, valueList: condition.valueList
                )
            }
            let resolved = ResolvedStyleRule(
                pinPartial: StyleFieldConvert.pinPartial(
                    shape: rule.shape, fillHex: rule.fillHex, strokeHex: rule.strokeHex,
                    glyph: rule.glyph, glyphHex: rule.glyphHex, size: rule.size, labelVisible: rule.labelVisible
                ),
                areaPartial: StyleFieldConvert.areaPartial(
                    fillHex: rule.fillHex, fillOpacity: rule.fillOpacity,
                    strokeHex: rule.strokeHex, strokeWidth: rule.strokeWidth, labelVisible: rule.labelVisible
                ),
                priority: rule.priority, enabled: rule.enabled, conditions: conditions
            )
            out[rule.entityType, default: []].append(resolved)
        }
        return out
    }
```

(b) `rebuildContent`(L491 附近,`let viewStyles = buildViewStyles(...)` 之后)加:
```swift
        let viewRules = buildViewStyleRules(dsId: dsId, viewId: activeMapView?.id)
```
并把 `buildPins(...)`、`buildAreaOverlays(...)` 调用加传 `viewRules: viewRules`。

(c) `buildPins`(L586)签名加 `viewRules: [String: [ResolvedStyleRule]]`,循环内 resolver 调用改:
```swift
            let style = StyleResolver.resolvePin(
                entity: c.entity, viewStyle: viewStyles[c.type],
                rules: viewRules[c.type] ?? [], groupFillHex: groupColors[c.id]
            )
```

(d) `buildAreaOverlays`(L611)签名加 `viewRules: [String: [ResolvedStyleRule]]`,循环内:
```swift
            let style = StyleResolver.resolveArea(
                entity: a.styleEntity, viewStyle: viewStyles["area"], rules: viewRules["area"] ?? []
            )
```

(e) `contentSignature`(L388 的 ViewEntityStyle fetch 之后)加规则+条件版本:
```swift
        let ruleSignFetch = FetchDescriptor<ViewStyleRule>(
            predicate: #Predicate { $0.datasetId == dsId && $0.viewId == activeViewId && !$0.deleted }
        )
        for rule in (try? modelContext.fetch(ruleSignFetch)) ?? [] {
            hasher.combine(rule.id)
            hasher.combine(rule.priority)
            hasher.combine(rule.enabled)
            hasher.combine(rule.updatedAt)
            let ruleId = rule.id
            let condSignFetch = FetchDescriptor<ViewStyleCondition>(
                predicate: #Predicate { $0.ruleId == ruleId && !$0.deleted }
            )
            for condition in (try? modelContext.fetch(condSignFetch)) ?? [] {
                hasher.combine(condition.updatedAt)
            }
        }
```

- [ ] **Step 6: 编译 + 跑测试**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|StyleResolverRuleTests|TEST (SUCCEEDED|FAILED)" | tail -15`
Expected: 6 规则测试通过 + 全套 `** TEST SUCCEEDED **`(既有 StyleResolverChainTests 等仍过,因 `rules` 有默认空值)

- [ ] **Step 7: 提交**
```bash
cd /Users/fujie/projects/天津买房
git add PropertyAtlas/PropertyAtlas/MapRender/ResolvedStyleRule.swift PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift PropertyAtlas/PropertyAtlas/RootView.swift PropertyAtlas/PropertyAtlasTests/MapRender/StyleResolverRuleTests.swift
git commit -m "feat(style): StyleResolver conditional layer; RootView prefetch ResolvedStyleRule

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: StyleConsolidationMigrator.migrateStyleRules(TDD,幂等)

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/StyleConsolidationMigrator.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/StyleConsolidationMigratorRuleTests.swift`

- [ ] **Step 1: 写失败测试**

`PropertyAtlasTests/DataKit/StyleConsolidationMigratorRuleTests.swift`:
```swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleConsolidationMigratorRuleTests {
    private func makeContext() throws -> ModelContext {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        return ModelContext(container)
    }

    /// 旧 StyleRule(grade==重点 → glyph 重 fill 红)挂 theme → 迁出 ViewStyleRule + ViewStyleCondition。
    @Test func migratesStyleRuleAndConditions() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds")
        ctx.insert(dataset)
        let old = StyleRule(datasetId: dataset.id, name: "学校-重点", entityType: "school")
        old.priority = 10
        old.appliesGlyph = "重"
        old.appliesFillHex = "#FF3B30"
        old.appliesLabelVisible = true
        old.conditionsJSON = ##"[{"field":"grade","op":"equals","value":"重点"}]"##
        ctx.insert(old)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.styleRuleIds = [old.id]
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let view = MapView(datasetId: dataset.id, name: "v")
        view.isActive = true
        ctx.insert(view)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let rules = try ctx.fetch(FetchDescriptor<ViewStyleRule>())
        #expect(rules.count == 1)
        let rule = try #require(rules.first)
        #expect(rule.entityType == "school")
        #expect(rule.glyph == "重")
        #expect(rule.fillHex == "#FF3B30")
        #expect(rule.priority == 10)
        let conds = try ctx.fetch(FetchDescriptor<ViewStyleCondition>())
        #expect(conds.count == 1)
        #expect(conds.first?.field == "grade")
        #expect(conds.first?.op == "equals")
        #expect(conds.first?.valueString == "重点")
    }

    @Test func idempotentSkipsViewWithRules() throws {
        let ctx = try makeContext()
        let dataset = Dataset(name: "ds2")
        ctx.insert(dataset)
        let old = StyleRule(datasetId: dataset.id, name: "r", entityType: "school")
        old.appliesGlyph = "重"
        old.conditionsJSON = "[]"
        ctx.insert(old)
        let theme = Theme(datasetId: dataset.id, name: "t")
        theme.styleRuleIds = [old.id]
        ctx.insert(theme)
        dataset.activeThemeId = theme.id
        let view = MapView(datasetId: dataset.id, name: "v")
        view.isActive = true
        ctx.insert(view)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)
        StyleConsolidationMigrator.run(in: ctx)

        let rules = try ctx.fetch(FetchDescriptor<ViewStyleRule>())
        #expect(rules.count == 1) // 二次不重复
    }
}
```

> 注:`AnyJSON` 用 `singleValueContainer` 编码,`value` 是**裸值**(`"value":"重点"`,非带类型键对象),`op` 是 rawValue 串(`"equals"`)。上面字面量已按此。

- [ ] **Step 2: 跑测试看失败**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "StyleConsolidationMigratorRuleTests|TEST (SUCCEEDED|FAILED)" | tail`
Expected: 2 测试失败(migrateStyleRules 未实现,无规则产出)

- [ ] **Step 3: 实现 migrateStyleRules**

`DataKit/StyleConsolidationMigrator.swift`:`run` 改为:
```swift
    static func run(in context: ModelContext) {
        migrateViews(in: context)
        migrateEntityOverrides(in: context)
        migrateStyleRules(in: context)
        try? context.save()
    }
```
在文件内(`migrateEntityOverrides` 之后)加:
```swift
    /// 旧 StyleRule(挂 theme.styleRuleIds)→ ViewStyleRule + ViewStyleCondition。
    /// 每视图闸 = 已有 ViewStyleRule 行则跳过。
    private static func migrateStyleRules(in context: ModelContext) {
        let views = (try? context.fetch(FetchDescriptor<MapView>(
            predicate: #Predicate { !$0.deleted }
        ))) ?? []
        for view in views {
            let viewId = view.id
            let existing = (try? context.fetch(FetchDescriptor<ViewStyleRule>(
                predicate: #Predicate { $0.viewId == viewId && !$0.deleted }
            ))) ?? []
            if !existing.isEmpty { continue }
            guard let theme = resolveTheme(for: view, in: context) else { continue }
            for styleRuleId in theme.styleRuleIds {
                guard let old = styleRuleById(styleRuleId, in: context) else { continue }
                let rule = ViewStyleRule(datasetId: view.datasetId, viewId: viewId, entityType: old.entityType)
                rule.priority = old.priority
                rule.enabled = old.enabled
                rule.shape = old.appliesShape
                rule.fillHex = (old.appliesFillMode == "palette") ? nil : old.appliesFillHex
                rule.strokeHex = old.appliesStrokeHex
                rule.glyph = old.appliesGlyph
                rule.glyphHex = old.appliesGlyphHex
                rule.size = old.appliesSize
                rule.labelVisible = old.appliesLabelVisible
                rule.fillOpacity = old.appliesFillOpacity
                rule.strokeWidth = old.appliesStrokeWidth
                context.insert(rule)
                let conditions: [StyleCondition] = (try? JSONHelpers.decode(old.conditionsJSON)) ?? []
                for (index, condition) in conditions.enumerated() {
                    let columns = ViewStyleConditionCodec.columns(from: condition.value, op: condition.op)
                    let newCondition = ViewStyleCondition(
                        ruleId: rule.id, field: condition.field, op: condition.op.rawValue
                    )
                    newCondition.valueString = columns.valueString
                    newCondition.valueList = columns.valueList
                    newCondition.sortOrder = index
                    context.insert(newCondition)
                }
            }
        }
    }

    private static func styleRuleById(_ id: UUID, in context: ModelContext) -> StyleRule? {
        (try? context.fetch(FetchDescriptor<StyleRule>(
            predicate: #Predicate { $0.id == id && !$0.deleted }
        )))?.first
    }
```
并更新文件顶部注释:`run` 现含三趟(views/entityOverrides/styleRules)。

- [ ] **Step 4: 跑测试看通过**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "StyleConsolidationMigrator|TEST (SUCCEEDED|FAILED)" | tail`
Expected: 全部迁移测试(含原有 + 新 2)通过

- [ ] **Step 5: 提交**
```bash
cd /Users/fujie/projects/天津买房
git add PropertyAtlas/PropertyAtlas/DataKit/StyleConsolidationMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/StyleConsolidationMigratorRuleTests.swift
git commit -m "feat(style): migrate legacy StyleRule -> ViewStyleRule + ViewStyleCondition

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: UI — 条件规则编辑(视图 tab)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/Components/StyleConditionRow.swift`
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/Components/ViewStyleRuleEditor.swift`
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/Components/ViewStyleRulesSection.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Settings/ViewSettingsTab.swift`

> 读 `Studio/Settings/Components/EntityDefaultStyleEditor.swift` 复用控件写法(StudioDisclosure/StudioChip/ColorHexField/getOrCreateRow 模式)。所有 menu Picker 加 `.lineLimit(1).fixedSize(horizontal: true, vertical: false)`(项目惯例,防折行)。改动直接 mutate + `updatedAt`。

- [ ] **Step 1: StyleConditionRow(单谓词)**

`Studio/Settings/Components/StyleConditionRow.swift`:
```swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 单条 ViewStyleCondition 编辑:字段 + op + 值。
struct StyleConditionRow: View {
    @Bindable var condition: ViewStyleCondition
    let entityType: String
    let datasetId: UUID
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context

    private let ops: [StyleConditionOp] = [.equals, .notEquals, .inOp, .contains, .gte, .lte, .exists]

    private var fieldItems: [FieldKeyCatalog.FieldItem] {
        FieldKeyCatalog.fields(entityType: entityType, datasetId: datasetId, context: context)
    }

    private var currentOp: StyleConditionOp {
        StyleConditionOp(rawValue: condition.op) ?? .equals
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: Binding(
                get: { condition.field },
                set: { condition.field = $0; condition.updatedAt = Date() }
            )) {
                Text("—").tag("")
                ForEach(fieldItems, id: \.key) { Text($0.label).tag($0.key) }
            }
            .labelsHidden().tint(Studio.cool).lineLimit(1).fixedSize(horizontal: true, vertical: false)

            Picker("", selection: Binding(
                get: { condition.op },
                set: { condition.op = $0; condition.updatedAt = Date() }
            )) {
                ForEach(ops, id: \.rawValue) { Text(opLabel($0)).tag($0.rawValue) }
            }
            .labelsHidden().tint(Studio.cool).lineLimit(1).fixedSize(horizontal: true, vertical: false)

            if currentOp == .inOp {
                TextField("值1,值2", text: Binding(
                    get: { condition.valueList.joined(separator: ",") },
                    set: { condition.valueList = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        condition.updatedAt = Date()
                    }
                )).glassField()
            } else if currentOp != .exists {
                TextField("值", text: Binding(
                    get: { condition.valueString ?? "" },
                    set: { condition.valueString = $0.isEmpty ? nil : $0; condition.updatedAt = Date() }
                )).glassField()
            }

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle").font(.system(size: 12))
            }.buttonStyle(.plain)
        }
    }

    private func opLabel(_ op: StyleConditionOp) -> String {
        switch op {
        case .equals: "等于"
        case .notEquals: "不等于"
        case .inOp: "属于"
        case .contains: "包含"
        case .gte: "≥"
        case .lte: "≤"
        case .exists: "存在"
        }
    }
}
#endif
```

- [ ] **Step 2: ViewStyleRuleEditor(单规则:条件 + 样式)**

`Studio/Settings/Components/ViewStyleRuleEditor.swift`:
```swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 单条 ViewStyleRule 编辑:条件列表(AND)+ 样式属性 + enabled/priority/删除。
struct ViewStyleRuleEditor: View {
    @Bindable var rule: ViewStyleRule
    let datasetId: UUID
    let onDelete: () -> Void
    @Environment(\.modelContext) private var context
    @State private var conditions: [ViewStyleCondition] = []

    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    var body: some View {
        StudioDisclosure(summaryTitle, summary: rule.glyph ?? rule.fillHex ?? "规则", open: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text("条件(全部满足)").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                ForEach(conditions, id: \.id) { condition in
                    StyleConditionRow(
                        condition: condition, entityType: rule.entityType, datasetId: datasetId,
                        onDelete: { deleteCondition(condition) }
                    )
                }
                Button { addCondition() } label: { Label("加条件", systemImage: "plus") }
                    .buttonStyle(.tbtn(.ghost))
            }
            Divider().overlay(Studio.on2.opacity(0.2))
            if rule.entityType != "area" {
                shapePicker
            }
            ColorHexField(title: "填充色", hex: hexBinding(\.fillHex))
            ColorHexField(title: "描边色", hex: hexBinding(\.strokeHex))
            TextField("字符 / 图标", text: Binding(
                get: { rule.glyph ?? "" },
                set: { rule.glyph = $0.isEmpty ? nil : String($0.prefix(2)); rule.updatedAt = Date() }
            )).glassField().font(Studio.mono(13))
            Toggle("显示标签", isOn: Binding(
                get: { rule.labelVisible ?? false },
                set: { rule.labelVisible = $0; rule.updatedAt = Date() }
            ))
            HStack {
                Toggle("启用", isOn: Binding(
                    get: { rule.enabled },
                    set: { rule.enabled = $0; rule.updatedAt = Date() }
                ))
                Spacer()
                Stepper("优先级 \(rule.priority)", value: Binding(
                    get: { rule.priority },
                    set: { rule.priority = $0; rule.updatedAt = Date() }
                ), in: 0...999)
            }
            Button(role: .destructive, action: onDelete) {
                Label("删除规则", systemImage: "trash")
            }.buttonStyle(.tbtn(.dangerGhost))
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { conditions = fetchConditions() }
    }

    private var summaryTitle: String {
        conditions.isEmpty ? "无条件规则" : conditions.map { "\($0.field)" }.joined(separator: "+")
    }

    private var shapePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("形状").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(shapes, id: \.self) { shape in
                        StudioChip(shape, isOn: rule.shape == shape) {
                            rule.shape = (rule.shape == shape) ? nil : shape
                            rule.updatedAt = Date()
                        }
                    }
                }
            }
        }
    }

    private func hexBinding(_ keyPath: ReferenceWritableKeyPath<ViewStyleRule, String?>) -> Binding<String> {
        Binding(
            get: { rule[keyPath: keyPath] ?? "" },
            set: { rule[keyPath: keyPath] = $0.isEmpty ? nil : $0; rule.updatedAt = Date() }
        )
    }

    private func fetchConditions() -> [ViewStyleCondition] {
        let ruleId = rule.id
        return (try? context.fetch(FetchDescriptor<ViewStyleCondition>(
            predicate: #Predicate { $0.ruleId == ruleId && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []
    }

    private func addCondition() {
        let condition = ViewStyleCondition(ruleId: rule.id, field: "", op: "equals")
        condition.sortOrder = conditions.count
        context.insert(condition)
        rule.updatedAt = Date()
        conditions = fetchConditions()
    }

    private func deleteCondition(_ condition: ViewStyleCondition) {
        condition.deleted = true
        condition.updatedAt = Date()
        rule.updatedAt = Date()
        conditions = fetchConditions()
    }
}
#endif
```

- [ ] **Step 3: ViewStyleRulesSection(某 entityType 列表)**

`Studio/Settings/Components/ViewStyleRulesSection.swift`:
```swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 某视图某 entityType 的条件规则列表 + 加规则。
struct ViewStyleRulesSection: View {
    let datasetId: UUID
    let viewId: UUID
    let entityType: String
    @Environment(\.modelContext) private var context
    @State private var rules: [ViewStyleRule] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rules, id: \.id) { rule in
                ViewStyleRuleEditor(rule: rule, datasetId: datasetId, onDelete: { deleteRule(rule) })
            }
            Button { addRule() } label: { Label("加条件规则", systemImage: "plus.circle") }
                .buttonStyle(.tbtn(.ghost))
        }
        .onAppear { rules = fetchRules() }
    }

    private func fetchRules() -> [ViewStyleRule] {
        let view = viewId, type = entityType
        return (try? context.fetch(FetchDescriptor<ViewStyleRule>(
            predicate: #Predicate { $0.viewId == view && $0.entityType == type && !$0.deleted },
            sortBy: [SortDescriptor(\.priority)]
        ))) ?? []
    }

    private func addRule() {
        let rule = ViewStyleRule(datasetId: datasetId, viewId: viewId, entityType: entityType)
        rule.priority = (rules.map(\.priority).max() ?? 0) + 1
        context.insert(rule)
        rules = fetchRules()
    }

    private func deleteRule(_ rule: ViewStyleRule) {
        rule.deleted = true
        rule.updatedAt = Date()
        rules = fetchRules()
    }
}
#endif
```

- [ ] **Step 4: 挂进 ViewSettingsTab**

`Studio/Settings/ViewSettingsTab.swift`,在 `SettingsCard("默认样式")`(Stage A 加的那张卡)之后插入条件规则卡(用同一组 entityType):
```swift
                SettingsCard("条件样式") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach([("compound", "小区"), ("school", "学校"), ("poi", "POI"), ("area", "片区")], id: \.0) { type, label in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(label).font(Studio.sans(12, .semibold)).foregroundStyle(Studio.on)
                                ViewStyleRulesSection(datasetId: mv.datasetId, viewId: mv.id, entityType: type)
                            }
                        }
                    }.padding(.horizontal, 13).padding(.bottom, 12)
                }
```

- [ ] **Step 5: 编译 + lint**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|Build input file cannot be found|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`

Run: `cd /Users/fujie/projects/天津买房 && swiftlint lint --quiet PropertyAtlas/PropertyAtlas/Studio/Settings/Components/StyleConditionRow.swift PropertyAtlas/PropertyAtlas/Studio/Settings/Components/ViewStyleRuleEditor.swift PropertyAtlas/PropertyAtlas/Studio/Settings/Components/ViewStyleRulesSection.swift 2>&1 | grep -c error`
Expected: `0`(若报 `type`/`label` 短名:`type` 4 字符 OK;闭包参 `$0` 允许。新文件各 ≤300 行。)

- [ ] **Step 6: 提交**
```bash
cd /Users/fujie/projects/天津买房
git add -A PropertyAtlas
git commit -m "feat(settings): conditional style rule editor in view tab

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: 双库验证(还原学校标识)+ CLAUDE.md

**Files:** 无代码(验证 + 文档)

- [ ] **Step 1: 全量单元测试 + lint**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)" | tail`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2: 既有库迁移验证(还原学校标识)**

```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)" | head -1
export LC_ALL=C
ps ax -o pid,command | grep "tmp/pa-build" | grep "MacOS/PropertyAtlas" | grep -v grep | awk '{print $1}' | xargs -r kill -9 2>/dev/null
open /tmp/pa-build/Build/Products/Debug-maccatalyst/PropertyAtlas.app
sleep 12
ps ax -o pid,command | grep "tmp/pa-build" | grep "MacOS/PropertyAtlas" | grep -v grep | awk '{print $1}' | xargs -r kill -9 2>/dev/null
S=~/Library/Application\ Support/default.store
echo "=== ViewStyleRule 行数(应 >0,字段总览/学区视图 各 4 条学校规则)==="
sqlite3 "$S" "SELECT COUNT(*) FROM ZVIEWSTYLERULE WHERE ZDELETED=0;" 2>/dev/null
echo "=== ViewStyleCondition 行数(应 >0)==="
sqlite3 "$S" "SELECT COUNT(*) FROM ZVIEWSTYLECONDITION WHERE ZDELETED=0;" 2>/dev/null
echo "=== 实体数不变(175/823)==="
sqlite3 "$S" "SELECT COUNT(*) FROM ZCOMPOUND WHERE ZDELETED=0; SELECT COUNT(*) FROM ZSCHOOL WHERE ZDELETED=0;" 2>/dev/null
```
Expected:ViewStyleRule/ViewStyleCondition 行数 >0;实体数仍 175/823。
人工:打开 app → 默认视图(字段总览/学区视图)→ **学校重新显示 重/区/普 glyph + tier 配色**;切到无规则的视图(商圈)学校不显示标识;在视图 tab「条件样式」能加/改/删规则并即时反映。

- [ ] **Step 3: 幂等验证**
```bash
export LC_ALL=C
open /tmp/pa-build/Build/Products/Debug-maccatalyst/PropertyAtlas.app
sleep 10
ps ax -o pid,command | grep "tmp/pa-build" | grep "MacOS/PropertyAtlas" | grep -v grep | awk '{print $1}' | xargs -r kill -9 2>/dev/null
S=~/Library/Application\ Support/default.store
echo "=== 二次启动后 ViewStyleRule 行数(应与上次相同,不翻倍)==="
sqlite3 "$S" "SELECT COUNT(*) FROM ZVIEWSTYLERULE WHERE ZDELETED=0;" 2>/dev/null
```
Expected:行数与 Step 2 相同(幂等,不重复建)。

- [ ] **Step 4: CLAUDE.md 记录**

在 `CLAUDE.md` 实施计划列表加一行指向本 plan;并补一段「视图条件样式」完成纪要:三层(ViewEntityStyle 固定 / ViewStyleRule+ViewStyleCondition 条件 / 实体 override)、求值链恢复条件层、ResolvedStyleRule 预取避免 resolver 查 DB、迁移第 3 趟还原学校标识、UI 视图 tab 条件规则编辑。注明 Stage B 一并删 migrateStyleRules + LegacyMigrator 改直接 seed ViewStyleRule。

- [ ] **Step 5: 提交**
```bash
cd /Users/fujie/projects/天津买房
git add CLAUDE.md
git commit -m "docs(claude): record view conditional styling

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## 完成后

全部任务完成 → `superpowers:finishing-a-development-branch`(与视图持有样式 Stage A 同分支 `feat/view-owned-style`,一并收尾)。Stage B(删旧 StyleRule/Theme/Palette @Model + migrateStyleRules + LegacyMigrator 改直接 seed ViewStyleRule)另开 spec/plan,待真机验证后做。
