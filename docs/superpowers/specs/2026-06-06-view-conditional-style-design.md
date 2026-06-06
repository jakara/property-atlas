# 视图条件样式(通用条件样式能力)Design Spec

> 2026-06-06。Studio Mode (Mac Catalyst)。SwiftUI · SwiftData。
> 接续:`2026-06-06-view-owned-style-redesign.md`(视图持有样式 Stage A,已实现于分支 `feat/view-owned-style`)。

## 背景与目标

视图持有样式 Stage A 删除了旧 `StyleRule`(全局条件样式),导致**学校 grade→glyph(重/区/普)+ tier 配色**等"同类型实体按字段值自动分流样式"的能力丢失。

用户判断:删除是因为原指令"全局维度的样式删掉"被字面执行,但那句话混了两件事——(a) 难懂的根源 = Theme+StyleRule **两级所有权 + 全局作用域**;(b) **条件样式能力本身**。重组所有权(theme→view)不应连带删除实体的条件样式能力。

**目标**:把条件样式作为**视图持有的通用能力**加回来,设计干净:
- 每个样式属性(全 9 项)都可「固定值」或「条件值」。
- 条件 = **多字段表达式**(AND 多个谓词)。
- **视图持有**(每视图×entityType 自己一组规则,跟随视图切换)。
- **实体 override 仅固定值**(维持现状)。
- 全 typed,无 JSON。
- 零数据丢失:既有库经迁移自动还原学校标识。

## 非目标

- 不重建旧 `StyleRule`/`Theme` 的全局两级所有权。
- 不动分组染色、视图默认样式、实体 override 的固定语义。
- 不做「每属性按不同字段」(已定:条件 = 多字段表达式规则,规则可设任意属性子集)。
- CloudKit 延后。

## 三层样式模型

求值链(全 typed):

```
builtin(按 entityType) → ViewEntityStyle 固定默认 → 命中的 ViewStyleRule(priority 升序 merge) → 分组染色 groupFillHex → 实体 override(固定)
```

每层「可空属性合并」:非 nil 覆盖累加器(沿用 `PartialPinStyle.merge`/`PartialAreaStyle.merge`)。

### 共享属性字段集

(即 `ViewEntityStyle` 现有列;`ViewStyleRule` 复用同集)
- pin:`shape, fillHex, strokeHex, glyph, glyphHex: String?`、`size: Int?`、`labelVisible: Bool?`
- area:`fillHex, strokeHex: String?`、`fillOpacity, strokeWidth: Double?`、`labelVisible: Bool?`

### 固定层 `ViewEntityStyle`(已存在,不改结构)

每 (viewId × entityType) 一行,各属性的固定默认值(nil = builtin)。**本 spec 不加 `conditionField`**(条件由 ViewStyleRule 携带)。

### 条件层 `ViewStyleRule`(新 @Model)

```
id, datasetId, viewId, entityType: String
priority: Int                 // 升序合并:高 priority 后套(覆盖低)
enabled: Bool = true          // 不删也能停用
// 命中后套的属性(与 ViewEntityStyle 同一套可空列)
shape, fillHex, strokeHex, glyph, glyphHex: String?
size: Int?; labelVisible: Bool?
fillOpacity, strokeWidth: Double?
version, createdAt, updatedAt: 标准
deleted: Bool
```

每 (viewId × entityType) 可 0..N 条。命中 = 其全部 `ViewStyleCondition` AND 成立(零条件 = 永远命中)。

### 条件 `ViewStyleCondition`(新 @Model,规则的子)

```
id, ruleId: UUID             // 所属 ViewStyleRule
field: String                // 实体字段 key(base 或 custom)
op: String                   // StyleConditionOp rawValue: equals/notEquals/in/contains/gte/lte/exists
valueString: String?         // equals/notEquals/contains/gte/lte 用
valueList: [String]          // in 用
sortOrder: Int
createdAt, updatedAt: 标准
deleted: Bool
```

同 ruleId 下多条 **AND**。求值复用现有 `ConditionEvaluator.matches(entity:condition:StyleCondition)`:从 typed 列拼 `StyleCondition(field, op, value)`:
- equals/notEquals/contains → `value = .string(valueString ?? "")`
- in → `value = .array(valueList.map { .string($0) })`
- gte/lte → `value = .double(Double(valueString))`(解析失败 → 不命中)
- exists → `value = .null`

> 复用 `StyleCondition`/`StyleConditionOp`/`ConditionEvaluator`(`MapRender/ConditionEvaluator.swift`,Stage A 保留至 Stage B)。

## StyleResolver 改动

为避免 resolver 内查 DB,定义轻量值类型 **`ResolvedStyleRule`**(纯内存,RootView 预取时组装):
```
struct ResolvedStyleRule {
    // 来自 ViewStyleRule 的属性列(shape/fillHex/.../strokeWidth)+ priority + enabled
    let pinPartial: PartialPinStyle
    let areaPartial: PartialAreaStyle
    let priority: Int
    let enabled: Bool
    let conditions: [StyleCondition]   // 该规则全部条件(AND)
}
```

- `resolvePin(entity:viewStyle:rules:groupFillHex:)`,`rules: [ResolvedStyleRule]`(已按该 entityType 预筛、priority 升序)。在 viewStyle merge 之后、groupFillHex 之前插入条件层:
  ```
  for rule in rules where rule.enabled
      && rule.conditions.allSatisfy({ ConditionEvaluator.matches(entity: entity, condition: $0) }):
      partial.merge(rule.pinPartial)
  ```
  (零条件 → allSatisfy 为 true → 永远命中。)
- `resolveArea(entity:viewStyle:rules:)`:同理用 `rule.areaPartial`。
- resolver 纯内存,不 fetch、不解析 JSON。

## RootView / 渲染管线

- `buildViewStyleRules(dsId:viewId:) -> [String: [ResolvedStyleRule]]`:fetch 该视图全部 `ViewStyleRule`(!deleted),按 entityType 分组、priority 升序;每 rule fetch 其 `ViewStyleCondition`(!deleted,sortOrder)拼 `[StyleCondition]`,组装 `ResolvedStyleRule`。
- `buildPins`/`buildAreaOverlays` 加 `rules: [String:[ResolvedStyleRule]]`,传 `rules[c.type] ?? []` 给 resolver。
- `contentSignature` 加:每 `ViewStyleRule` 的 id/priority/enabled/updatedAt + 每 `ViewStyleCondition` 的 updatedAt(限 active view)。
- 性能:规则少(学校 4 条)× 可见实体,纯内存字段比较(`ConditionEvaluator`),在 rebuild 内;pan/zoom 走内容签名缓存不重算。

## UI(`ViewSettingsTab`)

每 entityType 两块:
- **固定默认**:现有 `EntityDefaultStyleEditor`(不变)。
- **条件规则**(新):
  - `ViewStyleRulesSection`(按 entityType 列该视图规则 + 「加规则」)。
  - `ViewStyleRuleEditor`(单规则):
    - **条件**:谓词列表,每条 `StyleConditionRow`(新建,绑 typed `ViewStyleCondition`)= 字段 Picker(`FieldKeyCatalog.fields(entityType:datasetId:context:)`)+ op Picker(`StyleConditionOp.allCases`)+ 值输入(`valueString` TextField;op=`in` → `valueList` 逗号/标签输入)。加/删谓词。
    - **样式**:9 属性编辑(复用 `EntityDefaultStyleEditor` 控件:shape chips / `ColorHexField` / glyph TextField / size / label toggle / opacity / width)。
    - `enabled` 开关、priority Stepper、删除按钮(软删)。
  - 「加规则」:建空 `ViewStyleRule`(priority = 现有 max+1)。
- 改动直接 mutate + `updatedAt`;条件行/规则增删即时持久(SwiftData 自动保存);软删 `deleted=true`。
- 文件 ≤300 行:`ViewStyleRuleEditor.swift`、`StyleConditionRow.swift`、`ViewStyleRulesSection.swift` 分立;`ViewSettingsTab` 仅挂载 section。

## 迁移 / seed(还原学校标识)

`StyleConsolidationMigrator` 加**第 3 趟 `migrateStyleRules(in:)`**(与现有 migrateViews / migrateEntityOverrides 并列):

- **每视图闸** = 该视图是否已有 `ViewStyleRule` 行(`viewId` 命中任一非删)。有则跳过(不覆盖用户编辑)。独立于 ViewEntityStyle 闸——既有库(已有 ViewEntityStyle、无规则)下次启动会跑这趟。
- 视图未迁移:解析其旧 active theme(同 `migrateViews` 的 `resolveTheme`:启用图层 themeId 最高 zIndex → 回退 `dataset.activeThemeId`)→ `theme.styleRuleIds` → fetch 这些旧 `StyleRule`(!deleted)→ 每条:
  - 建 `ViewStyleRule(viewId, datasetId, entityType=rule.entityType, priority=rule.priority, enabled=rule.enabled)`,`applies*` → 属性列:
    `appliesShape→shape`、`appliesFillHex→fillHex`、`appliesStrokeHex→strokeHex`、`appliesGlyph→glyph`、`appliesGlyphHex→glyphHex`、`appliesSize→size`、`appliesLabelVisible→labelVisible`、`appliesFillOpacity→fillOpacity`、`appliesStrokeWidth→strokeWidth`。(`appliesFillMode=="palette"` 的旧 palette 填充模式 → 跳过 fill,本能力不支持 palette 模式填充;seed 学校规则用 fixed hex,无损。)
  - 解析 `rule.conditionsJSON`(`[StyleCondition]`,经 `JSONHelpers.decode` 或复刻 `StyleRuleMatcher.parseConditions`)→ 每条建 `ViewStyleCondition(ruleId, field, op=condition.op.rawValue, sortOrder)`,value AnyJSON → typed:`.string→valueString`、`.array→valueList`(元素 stringify)、`.int/.double→valueString`(数字串)、`.bool→valueString`、`.null/exists→均空`。
- 旧 `StyleRule` 行保留(Stage B 删)。
- 新装:LegacyMigrator 继续 seed 旧 StyleRule + 挂 theme(本阶段旧模型在),consolidation 据此建规则 —— 闭环,**不改 LegacyMigrator**。

**Stage B 备注**:删旧 `StyleRule`/`Theme`/`Palette` @Model 时,一并删 `migrateStyleRules`,并改 LegacyMigrator 直接 seed `ViewStyleRule`+`ViewStyleCondition`(替代 `seedSchoolStyleRules`)。

## 测试

- `ResolvedStyleRule` 求值(Swift Testing 纯逻辑):builtin→默认→规则(priority 合并、AND 条件命中/不命中)→override 顺序正确;enabled=false 跳过;多规则 priority 覆盖。
- `ConditionEvaluator` 经 typed 列拼 `StyleCondition`:equals/in/exists/gte 各 op 命中正确。
- `StyleConsolidationMigrator.migrateStyleRules`:给定旧 theme+styleRuleIds+StyleRule(含 conditionsJSON)→ 生成 ViewStyleRule + ViewStyleCondition 正确;幂等(二次不重复);无 styleRuleIds 的视图 → 零规则不崩。
- 内容签名:规则/条件变更触发重建,pan/zoom 不触发。

## 风险

- 加法 schema(`ViewStyleRule`/`ViewStyleCondition` 两新 @Model)→ SwiftData 轻量迁移,风险低。
- resolver 内 DB 查询 → 已规避(RootView 预取 `ResolvedStyleRule`,resolver 纯内存)。
- 规则匹配回到渲染路径 → 仅 rebuild 内、纯内存比较,内容签名缓存挡住 pan/zoom,性能无忧。
- 旧规则 palette 填充模式不迁移 → seed 学校规则用 fixed hex,无损;若用户曾自建 palette-mode 规则,fill 不迁移(可接受,极少)。
