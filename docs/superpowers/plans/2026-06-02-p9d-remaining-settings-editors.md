# P9d 剩余 Settings 编辑器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `SettingsSheet` 补齐 主题/样式/相机/字段 四个实体编辑器,让 Theme/StyleRule/CameraPreset/CustomFieldDef 在 app 内可增删改。

**Architecture:** 纯 additive UI,照搬 P9a 编辑器模式(`@Query` 过滤 `datasetId && !deleted` → 控件直接 mutate 设 `updatedAt` → 软删 `deleted=true` → 新建 `modelContext.insert`)。每个 tab 一个文件(≤300 行),先各自独立建好(未接入即编译通过),最后一个 task 扩 `SettingsSheet` 8 段并接入。无 schema 变更。

**Tech Stack:** SwiftUI / SwiftData / Mac Catalyst(所有 Settings 文件 `#if targetEnvironment(macCatalyst)` 包裹)/ Swift Testing。

**Spec:** `docs/superpowers/specs/2026-06-02-p9d-remaining-settings-editors-design.md`

---

## 构建 / 测试命令

工作目录:worktree 内 `PropertyAtlas/`。

- 构建:`xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -6` → `** BUILD SUCCEEDED **`
- 单套件:`xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/<Suite> 2>&1 | tail -15`
- 全量:`xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -15` → `** TEST SUCCEEDED **`(唯一已知 flaky:`PropertyAtlasUITests.testLaunchPerformance`,忽略)

> SourceKit "No such module 'Testing'" / "Cannot find type X" = 陈旧索引噪声,仅 `xcodebuild` 权威。Swift Testing(`import Testing`),非 XCTest。所有新 Settings 文件、组件须 `#if targetEnvironment(macCatalyst) ... #endif` 包裹(与现有一致),否则非-Catalyst 构建会丢符号。纯逻辑文件(StyleConditionCodec/CameraFieldClamp)**不**加 `#if`(要在测试里用,测试跑 Catalyst 但逻辑应通用 —— 不加 gating 最简)。

## 既定事实(已 grep 确认,直接用)

- `PinShape: String, CaseIterable`,cases:`circle, square, hexagon, diamond, triangle, star`(`MapRender/PinStyle.swift`)。
- `StyleConditionOp: String, Codable, Hashable`,cases:`equals, notEquals, inOp("in"), contains, gte, lte, exists`(`MapRender/ConditionEvaluator.swift`)。
- `StyleCondition: Codable { let field: String; let op: StyleConditionOp; let value: AnyJSON }`(memberwise init,三参必填)。
- `AnyJSON`:`.string/.int/.double/.bool/.array/.object/.null`。
- `JSONHelpers.encode(_:some Encodable) throws -> String` / `JSONHelpers.decode<T: Decodable>(_:String) throws -> T`。
- 组件:`ColorHexField(title:hex:Binding<String>)` + `static ColorHexField.normalize(_:String)->String`;`AnyJSONValueField(value:Binding<AnyJSON>)`(标量编辑为字符串,经 `ValueFormat.display`)。
- Model init:`Theme(datasetId:name:)`;`CameraPreset(datasetId:name:centerLat:centerLon:distance:pitch=0:heading=0)`;`CustomFieldDef(datasetId:entityType:key:label:type="string":source="user")`;`StyleRule(datasetId:name:entityType:)`。
- `SettingsSheet` 现 4 段(view/layer/palette/enumOption),`MapViewContext.datasetIdValue` 提供活跃 datasetId。
- StyleRule 全字段:`name/entityType/conditionsJSON/priority/appliesShape?/appliesFillMode(默认"fixed")/appliesFillHex?/appliesPaletteId?/appliesPaletteKeyField?/appliesStrokeHex?/appliesGlyph?/appliesGlyphHex?/appliesSize?(Int)/appliesLabelVisible?(Bool)/appliesFillOpacity?(Double)/appliesStrokeWidth?(Double)/enabled(Bool)`。
- CustomFieldDef 字段:`entityType/key/label/type/unit?/pinnedToCard(Bool)/sortOrder/source`。
- CameraPreset 字段:`name/centerLat/centerLon/distance/pitch/heading/sortOrder`。
- Theme 字段:`name/sortOrder/isActive(Bool)/showLegend(Bool)/styleRuleIds([UUID])/defaultStylesJSON(String)`。

---

## Task 0: 纯逻辑 — StyleConditionCodec + CameraFieldClamp + 单测

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/StyleConditionCodec.swift`
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/CameraFieldClamp.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/Studio/P9dLogicTests.swift`

Additive,无 UI。

- [ ] **Step 1: 写失败测试**

新建 `PropertyAtlasTests/Studio/P9dLogicTests.swift`:

```swift
import Foundation
import Testing
@testable import PropertyAtlas

@Suite("P9d pure logic")
struct P9dLogicTests {
    @Test func conditionCodecRoundTrip() {
        let conds = [
            StyleCondition(field: "grade", op: .equals, value: .string("重点")),
            StyleCondition(field: "isNewHouse", op: .exists, value: .null),
            StyleCondition(field: "tags", op: .inOp, value: .array([.string("a"), .string("b")])),
        ]
        let json = StyleConditionCodec.encode(conds)
        let back = StyleConditionCodec.decode(json)
        #expect(back.count == 3)
        #expect(back[0].field == "grade")
        #expect(back[0].op == .equals)
        #expect(back[2].op == .inOp)
    }

    @Test func conditionCodecBadEmpty() {
        #expect(StyleConditionCodec.decode("").isEmpty)
        #expect(StyleConditionCodec.decode("not json").isEmpty)
        #expect(StyleConditionCodec.encode([]) == "[]")
    }

    @Test func clampPitch() {
        #expect(CameraFieldClamp.pitch(-10) == 0)
        #expect(CameraFieldClamp.pitch(90) == 85)
        #expect(CameraFieldClamp.pitch(45) == 45)
    }

    @Test func clampHeading() {
        #expect(CameraFieldClamp.heading(370) == 10)
        #expect(CameraFieldClamp.heading(-10) == 350)
        #expect(CameraFieldClamp.heading(360) == 0)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/P9dLogicTests 2>&1 | tail -15`
Expected: 编译失败(`StyleConditionCodec`/`CameraFieldClamp` 未定义)。

- [ ] **Step 3: 实现 StyleConditionCodec**

新建 `Studio/Settings/StyleConditionCodec.swift`:

```swift
import Foundation

/// StyleRule.conditionsJSON ⇄ [StyleCondition]。坏/空 JSON → []。
enum StyleConditionCodec {
    static func decode(_ json: String) -> [StyleCondition] {
        let result: [StyleCondition]? = try? JSONHelpers.decode(json)
        return result ?? []
    }

    static func encode(_ conditions: [StyleCondition]) -> String {
        (try? JSONHelpers.encode(conditions)) ?? "[]"
    }
}
```

- [ ] **Step 4: 实现 CameraFieldClamp**

新建 `Studio/Settings/CameraFieldClamp.swift`:

```swift
import Foundation

/// CameraPreset 数字字段边界。
enum CameraFieldClamp {
    /// pitch 限 0…85 度。
    static func pitch(_ v: Double) -> Double { min(max(v, 0), 85) }

    /// heading 归一到 0…<360 度。
    static func heading(_ v: Double) -> Double {
        let m = v.truncatingRemainder(dividingBy: 360)
        return m < 0 ? m + 360 : m
    }
}
```

- [ ] **Step 5: 跑测试确认通过**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/P9dLogicTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`(4 tests)。

- [ ] **Step 6: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/StyleConditionCodec.swift \
        PropertyAtlas/PropertyAtlas/Studio/Settings/CameraFieldClamp.swift \
        PropertyAtlas/PropertyAtlasTests/Studio/P9dLogicTests.swift
git -c commit.gpgsign=false commit -m "feat(settings): StyleConditionCodec + CameraFieldClamp pure logic (P9d T0)"
```

---

## Task 1: CameraSettingsTab

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/CameraSettingsTab.swift`

独立视图,本 task 不接入 SettingsSheet(T5 接)。编译通过即可(未引用 = 合法)。

- [ ] **Step 1: 实现 CameraSettingsTab**

新建 `Studio/Settings/CameraSettingsTab.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct CameraSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var presets: [CameraPreset]

    private var dsPresets: [CameraPreset] {
        presets.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("相机机位").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addPreset() } label: { Label("新机位", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(dsPresets, id: \.id) { p in card(p) }
        }
    }

    private func card(_ p: CameraPreset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { p.name }, set: { p.name = $0; p.updatedAt = Date() })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { p.deleted = true; p.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                numField("纬度", get: { p.centerLat }, set: { p.centerLat = $0; p.updatedAt = Date() })
                numField("经度", get: { p.centerLon }, set: { p.centerLon = $0; p.updatedAt = Date() })
            }
            HStack {
                numField("距离", get: { p.distance }, set: { p.distance = $0; p.updatedAt = Date() })
                numField("俯仰", get: { p.pitch }, set: { p.pitch = CameraFieldClamp.pitch($0); p.updatedAt = Date() })
                numField("朝向", get: { p.heading }, set: { p.heading = CameraFieldClamp.heading($0); p.updatedAt = Date() })
            }
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func numField(_ title: String, get: @escaping () -> Double, set: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("0", text: Binding(get: { String(get()) }, set: { if let d = Double($0) { set(d) } }))
                .font(.system(size: 12).monospaced()).frame(width: 70)
        }
    }

    private func addPreset() {
        let p = CameraPreset(datasetId: datasetId, name: "新机位", centerLat: 39.12, centerLon: 117.2, distance: 15000)
        p.sortOrder = (dsPresets.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(p)
    }
}
#endif
```

- [ ] **Step 2: build**

Run: `xcodebuild build ... 2>&1 | tail -6`
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/CameraSettingsTab.swift
git -c commit.gpgsign=false commit -m "feat(settings): CameraSettingsTab (preset CRUD) (P9d T1)"
```

---

## Task 2: CustomFieldSettingsTab

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/CustomFieldSettingsTab.swift`

按 entityType 分组。`key` 持久化后只读 —— 用本地 `@State newlyAddedIds: Set<UUID>` 记录本次会话新建的 id,只有这些 id 的 key 可编辑(简单务实;重开 sheet 后一律只读)。

- [ ] **Step 1: 实现 CustomFieldSettingsTab**

新建 `Studio/Settings/CustomFieldSettingsTab.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct CustomFieldSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var defs: [CustomFieldDef]
    @State private var entityType: String = "compound"
    @State private var newlyAddedIds: Set<UUID> = []

    private let entityTypes = ["compound", "school", "poi", "area"]
    private let fieldTypes = ["string", "int", "double", "bool", "date", "multiline"]

    private var rows: [CustomFieldDef] {
        defs.filter { $0.datasetId == datasetId && $0.entityType == entityType && !$0.deleted }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("实体", selection: $entityType) {
                ForEach(entityTypes, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).font(.system(size: 12))
            HStack {
                Text("自定义字段").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addDef() } label: { Label("新字段", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(rows, id: \.id) { d in card(d) }
        }
    }

    private func card(_ d: CustomFieldDef) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("标签", text: Binding(get: { d.label }, set: { d.label = $0; d.updatedAt = Date() })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { d.deleted = true; d.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                Text("key").font(.system(size: 11)).foregroundStyle(.secondary)
                if newlyAddedIds.contains(d.id) {
                    TextField("字段标识", text: Binding(get: { d.key }, set: { d.key = $0; d.updatedAt = Date() })).font(.system(size: 12).monospaced())
                } else {
                    Text(d.key).font(.system(size: 12).monospaced()).foregroundStyle(.secondary)
                }
            }
            HStack {
                Picker("类型", selection: Binding(get: { d.type }, set: { d.type = $0; d.updatedAt = Date() })) {
                    ForEach(fieldTypes, id: \.self) { Text($0).tag($0) }
                }.font(.system(size: 12))
                TextField("单位", text: Binding(get: { d.unit ?? "" }, set: { d.unit = $0.isEmpty ? nil : $0; d.updatedAt = Date() })).font(.system(size: 12)).frame(width: 70)
            }
            Toggle("卡片置顶显示", isOn: Binding(get: { d.pinnedToCard }, set: { d.pinnedToCard = $0; d.updatedAt = Date() })).font(.system(size: 12))
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func addDef() {
        let key = "field_\((rows.map(\.sortOrder).max() ?? 0) + 1)"
        let d = CustomFieldDef(datasetId: datasetId, entityType: entityType, key: key, label: "新字段")
        d.sortOrder = (rows.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(d)
        newlyAddedIds.insert(d.id)
    }
}
#endif
```

- [ ] **Step 2: build**

Run: `xcodebuild build ... 2>&1 | tail -6` → `** BUILD SUCCEEDED **`。

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/CustomFieldSettingsTab.swift
git -c commit.gpgsign=false commit -m "feat(settings): CustomFieldSettingsTab (per-entityType CRUD, key locked after create) (P9d T2)"
```

---

## Task 3: ThemeSettingsTab

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/ThemeSettingsTab.swift`

styleRuleIds 多选 + defaultStylesJSON 原文编辑带校验。

- [ ] **Step 1: 实现 ThemeSettingsTab**

新建 `Studio/Settings/ThemeSettingsTab.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct ThemeSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var themes: [Theme]
    @Query private var styleRules: [StyleRule]

    private var dsThemes: [Theme] {
        themes.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder }
    }
    private var dsRules: [StyleRule] {
        styleRules.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.priority < $1.priority }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("主题").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addTheme() } label: { Label("新主题", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(dsThemes, id: \.id) { t in card(t) }
        }
    }

    private func card(_ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { t.name }, set: { t.name = $0; t.updatedAt = Date() })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { t.deleted = true; t.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                Stepper(value: Binding(get: { t.sortOrder }, set: { t.sortOrder = $0; t.updatedAt = Date() }), in: 0...999) { Text("排序 \(t.sortOrder)").font(.system(size: 12)) }
                Toggle("激活", isOn: Binding(get: { t.isActive }, set: { t.isActive = $0; t.updatedAt = Date() })).font(.system(size: 12))
                Toggle("图例", isOn: Binding(get: { t.showLegend }, set: { t.showLegend = $0; t.updatedAt = Date() })).font(.system(size: 12))
            }
            DisclosureGroup("样式规则 (\(t.styleRuleIds.count))") {
                ForEach(dsRules, id: \.id) { rule in
                    Toggle(rule.name, isOn: ruleBinding(t, rule.id)).font(.system(size: 11))
                }
            }.font(.system(size: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text("defaultStylesJSON").font(.system(size: 10)).foregroundStyle(.secondary)
                TextEditor(text: jsonBinding(t)).font(.system(size: 11).monospaced()).frame(height: 70).border(.quaternary)
                if !isValidJSON(t.defaultStylesJSON) {
                    Text("⚠️ 无效 JSON,未保存").font(.system(size: 10)).foregroundStyle(.red)
                }
            }
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func ruleBinding(_ t: Theme, _ ruleId: UUID) -> Binding<Bool> {
        Binding(
            get: { t.styleRuleIds.contains(ruleId) },
            set: { on in
                if on { if !t.styleRuleIds.contains(ruleId) { t.styleRuleIds.append(ruleId) } }
                else { t.styleRuleIds.removeAll { $0 == ruleId } }
                t.updatedAt = Date()
            }
        )
    }

    /// 本地草稿:无效 JSON 时只更新草稿不写回模型;有效时写回。
    @State private var draft: [UUID: String] = [:]
    private func jsonBinding(_ t: Theme) -> Binding<String> {
        Binding(
            get: { draft[t.id] ?? t.defaultStylesJSON },
            set: { s in
                draft[t.id] = s
                if s.isEmpty || isValidJSON(s) { t.defaultStylesJSON = s; t.updatedAt = Date() }
            }
        )
    }

    private func isValidJSON(_ s: String) -> Bool {
        if s.isEmpty { return true }
        guard let data = s.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    private func addTheme() {
        let t = Theme(datasetId: datasetId, name: "新主题")
        t.sortOrder = (dsThemes.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(t)
    }
}
#endif
```

> 校验依据用错误状态显示(草稿里的串无效时红字),与 spec 一致。`draft` 是 `@State` 字典,放在 struct 内属性位置(SwiftUI 允许)。

- [ ] **Step 2: build**

Run: `xcodebuild build ... 2>&1 | tail -6` → `** BUILD SUCCEEDED **`。

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/ThemeSettingsTab.swift
git -c commit.gpgsign=false commit -m "feat(settings): ThemeSettingsTab (styleRuleIds multi-select + defaultStylesJSON validate) (P9d T3)"
```

---

## Task 4: StyleConditionRow + StyleRuleSettingsTab

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/Components/StyleConditionRow.swift`
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/StyleRuleSettingsTab.swift`

最重 tab。条件行复用 `AnyJSONValueField`;StyleCondition 是 `let` 成员,改值需整体重建。

- [ ] **Step 1: 实现 StyleConditionRow 组件**

新建 `Studio/Settings/Components/StyleConditionRow.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct StyleConditionRow: View {
    @Binding var condition: StyleCondition
    let onDelete: () -> Void

    private let ops: [StyleConditionOp] = [.equals, .notEquals, .inOp, .contains, .gte, .lte, .exists]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField("字段 key", text: fieldBinding).font(.system(size: 12).monospaced())
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            Picker("运算", selection: opBinding) {
                ForEach(ops, id: \.self) { Text($0.rawValue).tag($0) }
            }.font(.system(size: 12))
            if condition.op != .exists {
                AnyJSONValueField(value: valueBinding)
            }
        }
        .padding(8).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var fieldBinding: Binding<String> {
        Binding(get: { condition.field }, set: { condition = StyleCondition(field: $0, op: condition.op, value: condition.value) })
    }
    private var opBinding: Binding<StyleConditionOp> {
        Binding(get: { condition.op }, set: { condition = StyleCondition(field: condition.field, op: $0, value: condition.value) })
    }
    private var valueBinding: Binding<AnyJSON> {
        Binding(get: { condition.value }, set: { condition = StyleCondition(field: condition.field, op: condition.op, value: $0) })
    }
}
#endif
```

- [ ] **Step 2: 实现 StyleRuleSettingsTab**

新建 `Studio/Settings/StyleRuleSettingsTab.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct StyleRuleSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [StyleRule]
    @Query private var palettes: [Palette]

    private let entityTypes = ["compound", "school", "poi", "area"]
    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    private var dsRules: [StyleRule] {
        rules.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.priority < $1.priority }
    }
    private var dsPalettes: [Palette] { palettes.filter { !$0.deleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("样式规则").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addRule() } label: { Label("新规则", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(dsRules, id: \.id) { r in card(r) }
        }
    }

    private func card(_ r: StyleRule) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { r.name }, set: { r.name = $0; r.updatedAt = Date() })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { r.deleted = true; r.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                Picker("实体", selection: Binding(get: { r.entityType }, set: { r.entityType = $0; r.updatedAt = Date() })) {
                    ForEach(entityTypes, id: \.self) { Text($0).tag($0) }
                }.font(.system(size: 12))
                Toggle("启用", isOn: Binding(get: { r.enabled }, set: { r.enabled = $0; r.updatedAt = Date() })).font(.system(size: 12))
                Stepper("优先\(r.priority)", value: Binding(get: { r.priority }, set: { r.priority = $0; r.updatedAt = Date() }), in: 0...999).font(.system(size: 11))
            }
            appliesSection(r)
            conditionsSection(r)
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func appliesSection(_ r: StyleRule) -> some View {
        DisclosureGroup("样式") {
            VStack(alignment: .leading, spacing: 6) {
                Picker("形状", selection: Binding(get: { r.appliesShape ?? "" }, set: { r.appliesShape = $0.isEmpty ? nil : $0; r.updatedAt = Date() })) {
                    Text("(无)").tag("")
                    ForEach(shapes, id: \.self) { Text($0).tag($0) }
                }.font(.system(size: 12))
                Picker("填充模式", selection: Binding(get: { r.appliesFillMode }, set: { r.appliesFillMode = $0; r.updatedAt = Date() })) {
                    Text("固定色").tag("fixed"); Text("调色板").tag("palette")
                }.pickerStyle(.segmented).font(.system(size: 11))
                if r.appliesFillMode == "palette" {
                    Picker("调色板", selection: Binding(get: { r.appliesPaletteId }, set: { r.appliesPaletteId = $0; r.updatedAt = Date() })) {
                        Text("无").tag(UUID?.none)
                        ForEach(dsPalettes, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                    }.font(.system(size: 12))
                    TextField("调色 key 字段", text: Binding(get: { r.appliesPaletteKeyField ?? "" }, set: { r.appliesPaletteKeyField = $0.isEmpty ? nil : $0; r.updatedAt = Date() })).font(.system(size: 12))
                } else {
                    ColorHexField(title: "填充色", hex: hexBinding(get: { r.appliesFillHex }, set: { r.appliesFillHex = $0; r.updatedAt = Date() }))
                }
                ColorHexField(title: "描边色", hex: hexBinding(get: { r.appliesStrokeHex }, set: { r.appliesStrokeHex = $0; r.updatedAt = Date() }))
                HStack {
                    TextField("glyph", text: Binding(get: { r.appliesGlyph ?? "" }, set: { r.appliesGlyph = $0.isEmpty ? nil : $0; r.updatedAt = Date() })).font(.system(size: 12))
                    ColorHexField(title: "glyph 色", hex: hexBinding(get: { r.appliesGlyphHex }, set: { r.appliesGlyphHex = $0; r.updatedAt = Date() }))
                }
                HStack {
                    optIntField("尺寸", get: { r.appliesSize }, set: { r.appliesSize = $0; r.updatedAt = Date() })
                    optDoubleField("描边宽", get: { r.appliesStrokeWidth }, set: { r.appliesStrokeWidth = $0; r.updatedAt = Date() })
                    optDoubleField("不透明", get: { r.appliesFillOpacity }, set: { r.appliesFillOpacity = $0; r.updatedAt = Date() })
                }
                Picker("标签", selection: Binding(get: { labelTag(r.appliesLabelVisible) }, set: { r.appliesLabelVisible = labelValue($0); r.updatedAt = Date() })) {
                    Text("默认").tag(0); Text("显示").tag(1); Text("隐藏").tag(2)
                }.pickerStyle(.segmented).font(.system(size: 11))
            }
        }.font(.system(size: 12))
    }

    private func conditionsSection(_ r: StyleRule) -> some View {
        let conds = StyleConditionCodec.decode(r.conditionsJSON)
        return DisclosureGroup("条件 (\(conds.count))") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(conds.indices, id: \.self) { i in
                    StyleConditionRow(
                        condition: Binding(
                            get: { StyleConditionCodec.decode(r.conditionsJSON)[safe: i] ?? StyleCondition(field: "", op: .equals, value: .string("")) },
                            set: { newCond in
                                var arr = StyleConditionCodec.decode(r.conditionsJSON)
                                if arr.indices.contains(i) { arr[i] = newCond; r.conditionsJSON = StyleConditionCodec.encode(arr); r.updatedAt = Date() }
                            }
                        ),
                        onDelete: {
                            var arr = StyleConditionCodec.decode(r.conditionsJSON)
                            if arr.indices.contains(i) { arr.remove(at: i); r.conditionsJSON = StyleConditionCodec.encode(arr); r.updatedAt = Date() }
                        }
                    )
                }
                Button { addCondition(r) } label: { Label("加条件", systemImage: "plus") }.font(.system(size: 11))
            }
        }.font(.system(size: 12))
    }

    // MARK: helpers

    private func hexBinding(get: @escaping () -> String?, set: @escaping (String?) -> Void) -> Binding<String> {
        Binding(get: { get() ?? "" }, set: { set($0.isEmpty ? nil : ColorHexField.normalize($0)) })
    }
    private func optIntField(_ title: String, get: @escaping () -> Int?, set: @escaping (Int?) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("—", text: Binding(get: { get().map(String.init) ?? "" }, set: { set($0.isEmpty ? nil : Int($0)) })).font(.system(size: 12).monospaced()).frame(width: 44)
        }
    }
    private func optDoubleField(_ title: String, get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("—", text: Binding(get: { get().map { String($0) } ?? "" }, set: { set($0.isEmpty ? nil : Double($0)) })).font(.system(size: 12).monospaced()).frame(width: 50)
        }
    }
    private func labelTag(_ v: Bool?) -> Int { v == nil ? 0 : (v == true ? 1 : 2) }
    private func labelValue(_ tag: Int) -> Bool? { tag == 0 ? nil : (tag == 1) }

    private func addCondition(_ r: StyleRule) {
        var arr = StyleConditionCodec.decode(r.conditionsJSON)
        arr.append(StyleCondition(field: "", op: .equals, value: .string("")))
        r.conditionsJSON = StyleConditionCodec.encode(arr); r.updatedAt = Date()
    }
    private func addRule() {
        let r = StyleRule(datasetId: datasetId, name: "新规则", entityType: "compound")
        r.priority = (dsRules.map(\.priority).max() ?? 0) + 1
        modelContext.insert(r)
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
#endif
```

- [ ] **Step 3: build**

Run: `xcodebuild build ... 2>&1 | tail -6` → `** BUILD SUCCEEDED **`。
若 `StyleRule` 某 applies* 字段名/类型与本文件不符,以模型为准微调(grep `Models/Style/StyleRule.swift` 核对)。

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/Components/StyleConditionRow.swift \
        PropertyAtlas/PropertyAtlas/Studio/Settings/StyleRuleSettingsTab.swift
git -c commit.gpgsign=false commit -m "feat(settings): StyleRuleSettingsTab + StyleConditionRow (applies* + conditions) (P9d T4)"
```

---

## Task 5: 接入 SettingsSheet(8 段)+ 全量验证 + CLAUDE.md

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Settings/SettingsSheet.swift`
- Modify: `CLAUDE.md`

- [ ] **Step 1: 扩 SettingsSheet 到 8 段**

`SettingsSheet.swift` 改:enum 加 4 case;switch 加 4 分支。完整替换文件:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

enum SettingsTab: String, CaseIterable, Identifiable {
    case view = "视图", layer = "图层", palette = "调色板", enumOption = "枚举"
    case theme = "主题", styleRule = "样式", camera = "相机", customField = "字段"
    var id: String { rawValue }
}

struct SettingsSheet: View {
    @Bindable var viewContext: MapViewContext
    let onClose: () -> Void
    @State private var tab: SettingsTab = .view

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置").font(.headline)
                Spacer()
                Button("完成", action: onClose).keyboardShortcut(.defaultAction)
            }
            .padding(12)
            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            Divider().padding(.top, 8)
            ScrollView {
                Group {
                    switch tab {
                    case .view: ViewSettingsTab(viewContext: viewContext)
                    case .layer: LayerSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .palette: PaletteSettingsTab()
                    case .enumOption: EnumOptionSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .theme: ThemeSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .styleRule: StyleRuleSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .camera: CameraSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .customField: CustomFieldSettingsTab(datasetId: viewContext.datasetIdValue)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 460, height: 820)
    }
}
#endif
```

- [ ] **Step 2: 全量 build + test**

Run: `xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`(仅 `testLaunchPerformance` 可接受失败)。

- [ ] **Step 3: 启动不崩 smoke(无 schema 改动,用现有 dev store)**

确认 app 未运行;取 worktree 产物路径:
```bash
DIR=$(xcodebuild -showBuildSettings -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR /{print $3}')
APP="$DIR/PropertyAtlas.app/Contents/MacOS/PropertyAtlas"
"$APP" >/tmp/p9d-boot.log 2>&1 &
PID=$!; sleep 12; kill $PID 2>/dev/null; sleep 1
grep -i "fatal\|crash\|exception" /tmp/p9d-boot.log && echo "CRASH" || echo "BOOT-OK no crash"
```
Expected: `BOOT-OK no crash`(无 schema 改动,不需清库;只验启动不崩)。

- [ ] **Step 4: 更新 CLAUDE.md**

(a) 计划列表:在 P9c 行后加
```markdown
- 实施计划 P9d (已完成): `docs/superpowers/plans/2026-06-02-p9d-remaining-settings-editors.md`
```
并把 `- P9 余项: 待写 (...)` 行改为
```markdown
- P9 余项: 逐实体-逐图层 theme 解析 (明确延后;单 active theme + StyleRule 已覆盖,等具体取景需求再做)
```

(b) 在 P9c 节点块后加 P9d 节点:
```markdown
> **P9d (2026-06-02) 完成后**: Studio Settings 补齐四编辑器(纯 additive,无 schema 变更)。`SettingsSheet`
> 扩 8 段(+主题/样式/相机/字段)。`CameraSettingsTab`(机位 CRUD,pitch/heading 经 `CameraFieldClamp`)、
> `CustomFieldSettingsTab`(按 entityType 分组,key 持久后只读)、`ThemeSettingsTab`(styleRuleIds 多选 +
> defaultStylesJSON 原文校验)、`StyleRuleSettingsTab`(entityType + applies* 全字段 + 条件经 `StyleConditionRow`)。
> 新纯逻辑(有单测):`StyleConditionCodec`(conditionsJSON ⇄ [StyleCondition])、`CameraFieldClamp`
> (pitch 0–85 / heading 0–360)。组件 `StyleConditionRow`。改动直接 mutate + `updatedAt`,软删 `deleted=true`。
> **逐实体-逐图层 theme 明确延后**(单 active theme + StyleRule 已覆盖)。CloudKit 仍延后(Catalyst `.none`)。
```

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/SettingsSheet.swift CLAUDE.md
git -c commit.gpgsign=false commit -m "feat(settings): wire 4 editors into SettingsSheet (8 tabs) + CLAUDE.md (P9d T5)"
```

---

## Self-Review(写计划者自检)

1. **Spec coverage**:① 8 段容器 → T5;② CameraSettingsTab → T1;③ CustomFieldSettingsTab(key 锁)→ T2;④ ThemeSettingsTab(styleRuleIds + JSON 校验)→ T3;⑤ StyleRuleSettingsTab(applies* + 条件)+ StyleConditionRow → T4;⑥ StyleConditionCodec/CameraFieldClamp + 测试 → T0;⑦ 无 schema → 启动 smoke → T5。全覆盖。逐图层 theme 明确不做(spec 非目标)。
2. **Placeholder scan**:无 TBD;每步给完整代码或精确替换。
3. **Type consistency**:`StyleCondition(field:op:value:)` 在 codec/row 一致;`StyleConditionOp` cases 与既定一致(inOp rawValue "in");`ColorHexField`/`AnyJSONValueField` 接口与 grep 一致;各 model init 与 grep 一致;`datasetId: viewContext.datasetIdValue` 与现有 tab 调用一致。
4. **风险**:StyleRuleSettingsTab applies* 字段最多,T4 build 步注明"以模型为准微调";条件编辑用 decode→mutate→encode 往返(每次从 conditionsJSON 重读,避免索引漂移)。无渲染/schema 改动,风险低。
