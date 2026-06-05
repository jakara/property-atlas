# 视图持有样式 · 主题/样式两级重设计 Design Spec

> 2026-06-06。Studio Mode (Mac Catalyst)。SwiftUI · SwiftData。

## 背景与目标

现有样式系统两级难懂:`Theme`(全局,持 `styleRuleIds` + `defaultStylesJSON`)+ `StyleRule`(全局条件样式,按 priority 匹配)。求值链:

```
builtin → Theme.defaultStylesJSON(按类型) → 匹配 StyleRule(按 priority) → 分组染色 → 实体 override
```

问题:Theme 与 StyleRule 概念重叠、难懂;样式用 JSON 存(`defaultStylesJSON`/`overrideStyleJSON`),而页面只展示有限几个字段,JSON 是历史包袱。

**目标职责模型**:
- **图层 (Layer)** = 实体的容器(`layerId` 归属)
- **视图 (MapView)** = 样式的容器(默认样式 + 调色板 + 染色 + 文案 + 过滤 + 图例开关)
- **实体** = 可覆写样式(override)

**核心改动**:
1. 删除全局条件样式 `StyleRule` 整套。
2. 删除 `Theme` 概念 —— 样式归视图:4 实体默认样式直接挂 MapView(经子模型),调色板内联进 MapView。
3. 所有样式去 JSON,强类型建模。
4. 实体 override 保留并去 JSON,复用同一套实体样式字段定义。
5. 分组染色、override 机制保留。
6. **不丢数据**:两阶段就地迁移。

## 非目标

- 不动实体/边/标记/视图过滤等用户数据(原地保留)。
- 不重做图例分组/过滤引擎(仅去掉对已删模型的引用)。
- CloudKit 仍延后(Catalyst `.none`)。
- 逐实体-逐图层 theme 解析 —— 已废弃(本次正式移除该方向)。

## 求值链(新)

全程强类型,无 JSON 解析:

```
builtin(按 entityType) → ViewEntityStyle(view, entityType) 合并 → 分组染色 groupFillHex → 实体样式列合并(override)
```

每层是「可空字段合并」:非 nil 字段覆盖累加器(等价现有 `PartialPinStyle.merge` 语义,但字段来自 typed 列而非 JSON)。

## 数据模型

### 共享样式字段集

可空(nil = 继承上一层),即现有 `PartialPinStyle`/`PartialAreaStyle` 的列化版本:

- pin:`shape: String?`、`fillHex: String?`、`strokeHex: String?`、`glyph: String?`、`glyphHex: String?`、`size: Int?`、`labelVisible: Bool?`
- area:`fillHex: String?`、`fillOpacity: Double?`、`strokeHex: String?`、`strokeWidth: Double?`、`labelVisible: Bool?`

两者并集作为统一列集合,按 entityType 取用相应子集(pin 类型不读 area 字段,反之亦然)。

### 新增 `ViewEntityStyle` @Model(视图默认样式)

```
id: UUID
datasetId: UUID
viewId: UUID            // 所属 MapView
entityType: String      // compound / school / poi / area
// + 上述全部可空样式列
shape, fillHex, strokeHex, glyph, glyphHex: String?
size: Int?
labelVisible: Bool?
fillOpacity, strokeWidth: Double?
version, createdAt, updatedAt: 标准
deleted: Bool
```

- 每个 MapView 拥有 4 行(compound/school/poi/area)。
- `resolvePin`/`resolveArea` 按 `entityType` 读对应行。

### `MapView` 新增字段

- `paletteHex: [String] = []` —— 分组染色色板;空 → 内置 `PaletteAssigner.highContrast` 兜底。
- `showLegend: Bool = true` —— 原在 `Theme` 上。

### 实体 override(去 JSON)

- 4 实体(`Compound`/`School`/`POI`/`Area`)各加同一套**可空样式列**(语义同 `ViewEntityStyle`,nil = 继承视图默认)。area 加 area 子集,pin 类型加 pin 子集。
- 删除 `overrideStyleJSON` 列(Stage B)。
- `StyleEntity` / `EntityWriter` / `OverrideStyleCodec` / `StyleOverrideSection` 改读写这些 typed 列。

### 删除(Stage B)

- @Model:`StyleRule`、`Theme`、`Palette`
- 字段:`Layer.themeId`、`Dataset.activeThemeId`、`MapView.paletteId`、实体 `overrideStyleJSON`
- 文件/类型:`StyleRuleMatcher`、`StyleCondition`/`ConditionEvaluator`、`StyleConditionRow`/`StyleConditionCodec`、`PaletteResolver`、`ThemeContext`(若死)、`StyleDefaults.parseThemeDefaults`(JSON 路径)
- `MapViewContext.activeTheme`

## StyleResolver 改动

- `resolvePin`:删 `rules: [StyleRule]` 参 + 匹配循环。`theme:`/`themeDefaults:` 改为 `viewStyle: ViewEntityStyle?`(按类型预取的那一行)。链:builtin → viewStyle 合并 → groupFillHex → 实体 override 列合并。
- `resolveArea`:同上。
- 删除 `parseDefaults`/`parseThemeDefaults`(JSON 解析)。性能修复(P5/06-05)的「解析一次复用」目标自然达成:typed 列无需解析。

## RootView / 渲染管线改动

- `rebuildContent`:删 `rulesForTheme`/`activeRuleIds`/`activeTheme`。改为按 dataset+viewId 预取 4 行 `ViewEntityStyle`(一次 fetch,`[entityType: ViewEntityStyle]` 字典),`buildPins`/`buildAreaOverlays` 按类型取行喂 `resolvePin`。
- `GroupColorResolver`:palette 来源 `palettesById[paletteId]` → `activeMapView.paletteHex`(空 → `highContrast`)。删 `palettesById` 相关 plumbing。
- 内容签名 `contentSignature`:删 rule 的 id/`updatedAt`;加 4 行 `ViewEntityStyle` 的 `updatedAt`/字段版本 + `MapView.paletteHex` + `showLegend` 的 hash。
- `MapViewContext`:删 `activeTheme`;新增按 viewId 取 `ViewEntityStyle` 行的便捷读取(或留给 RootView 直接 fetch)。

## UI / 设置页

- **设置页 8 tab → 5 tab**:视图 / 图层 / 枚举 / 相机 / 字段。删 主题 / 样式 / 调色板 三 tab(`ThemeSettingsTab`、`StyleRuleSettingsTab`、`PaletteSettingsTab` 删)。
- **`ViewSettingsTab` 新增三区**:
  - 「默认样式」:4 实体各一组样式表单。复用现有控件(`ColorHexField`、形状选择、glyph、size、label 开关)。写对应 `ViewEntityStyle` 行,直接 mutate + `updatedAt`。
  - 「调色板」:色组 CRUD(迁移 `PaletteSettingsTab` 逻辑),写 `MapView.paletteHex`。
  - 「图例」:`MapView.showLegend` 开关。
- **`StyleOverrideSection`**(实体编辑器):绑定实体 typed 样式列(替代 JSON codec),空 = 继承视图默认;清除 = 置 nil。

## 迁移方案(两阶段,零数据丢失)

实体/边/标记/视图过滤/customFieldsJSON 全程原地保留;`overrideStyleJSON` 与旧 theme/palette 在 Stage A 搬运后于 Stage B 删列。

### Stage A(本 spec/plan 范围 —— 功能完整 + 零丢失)

1. **加法 schema**(SwiftData 自动轻量迁移):
   - 新增 `ViewEntityStyle` @Model + 注册 ModelSchema。
   - `MapView` 加 `paletteHex`、`showLegend`。
   - 4 实体加可空样式列(override 用)。
   - `Dataset` 加 `stylesMigratedV2: Bool = false`(实体 override 迁移幂等标记)。
   - **保留** `StyleRule`/`Theme`/`Palette` @Model 及旧字段不删(行可读)。
2. **启动幂等迁移器 `StyleConsolidationMigrator.run(in:)`**(每启动跑,似 `LegacyMigrator`):
   - **每视图单一幂等闸** = 该 MapView 是否已有 `ViewEntityStyle` 行。**有则整体跳过该视图**(视图已迁移,不再触碰其样式/palette/showLegend),避免覆盖用户后续编辑。
   - 视图未迁移时,一次性搬运:
     - 按旧逻辑解出 activeTheme(启用图层 `themeId` 最高 zIndex → 回退 `dataset.activeThemeId`)。
     - `theme.defaultStylesJSON` 解析 → 建 4 行 `ViewEntityStyle`(无 theme/无对应键 → 该行留全 nil,渲染走 builtin)。
     - `palette(mapView.paletteId).colorsHex` → `mapView.paletteHex`。
     - `theme.showLegend` → `mapView.showLegend`。
   - **实体 override 单一幂等闸** = 一个一次性 dataset 级标记(`Dataset` 上新增 `stylesMigratedV2: Bool = false`):为 false 时遍历实体把 `overrideStyleJSON` 解析填入新样式列,完成后置 true;为 true 跳过。避免「实体本就无 override → 列全 nil」被误判为未迁移而反复跑。
3. **运行时全切到新模型**;旧 @Model 行原地留存(无害,不再被运行时读)。
4. **验证**:迁移后视图视觉与迁移前一致(默认样式 + 调色板搬运成功);实体 override 视觉一致;实体/边数不变;无 crash。StyleRule 条件样式停止生效(预期,用户接受)。

### Stage B(后续小发布,另开 plan)

- 删 `StyleRule`/`Theme`/`Palette` @Model + ModelSchema 条目 + 死文件/类型(见上「删除」清单)。
- 删 `Layer.themeId`、`Dataset.activeThemeId`、`MapView.paletteId`、实体 `overrideStyleJSON` 列、`Dataset.stylesMigratedV2`。
- 删 `StyleConsolidationMigrator`(搬运已完成)。
- 表 drop(数据已搬)。

## 测试

- `ViewEntityStyle` 求值:builtin → viewStyle → override 合并,nil 继承正确(Swift Testing,纯逻辑)。
- `StyleConsolidationMigrator`:给定旧 theme JSON + palette + 实体 overrideJSON,迁移后 `ViewEntityStyle` 行/`paletteHex`/实体列正确;幂等(二次跑不覆盖用户值);无 theme/无 palette 的边界。
- `GroupColorResolver`:`paletteHex` 空走 `highContrast`;非空按色组分配。
- 内容签名:`ViewEntityStyle`/`paletteHex` 变更触发重建,pan/zoom 不触发。

## 风险

- SwiftData 加法迁移失败 → Stage A 全加法(新模型 + 可空列),风险低;旧模型保留避免破坏性迁移。
- 迁移器误覆盖用户编辑 → 全部「仅当目标空」守卫 + 测试覆盖幂等。
- StyleRule 条件样式丢失视觉(如学校 grade→glyph、tier→配色)→ 已与用户确认接受;用户可经视图默认样式 + 分组染色 + 实体 override 重建所需视觉。
