# P9d 设计:剩余 Settings 编辑器(Theme/StyleRule/CameraPreset/CustomFieldDef)

> Spec 日期:2026-06-02。承接 P9c。执行用 superpowers:writing-plans → subagent-driven-development。

## 目标

在 Studio 的 `SettingsSheet` 内补齐四个实体编辑器 —— **主题 Theme / 样式 StyleRule / 相机 CameraPreset / 自定义字段 CustomFieldDef**,让用户在 app 内直接增删改这些配置,无需改 seed/JSON 或动数据库。纯 additive UI,沿用 P9a 已确立的编辑器模式,**无 schema 变更**。

**非目标**:逐实体-逐图层 theme 解析(本轮明确**不做**,继续挂起 —— 单 active theme + StyleRule(entityType + 字段条件)已覆盖绝大多数染色需求);`defaultStylesJSON` 的结构化可视编辑(只做原始 JSON 文本编辑 + 校验,YAGNI);CloudKit(Catalyst 保持 `.none`)。

## 背景:已确立的 P9a 编辑器模式

P9a 建了 `SettingsSheet`(4 段:视图/图层/调色板/枚举)。每个 tab 的统一套路:
- `@Query` 取实体,运行时 `.filter { $0.datasetId == activeDatasetId && !$0.deleted }` + 排序。
- 编辑 = 控件直接绑模型属性,setter 里 `entity.field = new; entity.updatedAt = Date()`(SwiftData 自动保存)。
- 删除 = 软删 `entity.deleted = true; entity.updatedAt = Date()`。
- 新建 = 构造实体设默认 + `modelContext.insert(e)`。
- 复用组件在 `Studio/Settings/Components/`:`ColorHexField`(hex 规范化)、`FilterConditionRow`、`DimensionPicker` 等。

四个新 tab 完全照此,**不引入新的状态/保存机制**。

## 架构

### 容器导航

`SettingsSheet` 的分段从 4 段扩到 **8 段**:视图 / 图层 / 调色板 / 枚举 / **主题 / 样式 / 相机 / 字段**。460pt 宽下 8 个 2 字中文标签可用。其 tab enum 增 4 个 case,`switch` 增 4 个分支指向新 tab 视图。

### 四个编辑器(均为 `Studio/Settings/<Name>Tab.swift`,各 ≤300 行)

**`CameraSettingsTab`**(最简):`@Query` CameraPreset,按 `sortOrder` 排。每项:`name`(TextField)、`centerLat`/`centerLon`/`distance`/`pitch`/`heading`(数字 TextField,见下 clamp)。新建:`CameraPreset(datasetId:name:"新机位",centerLat:39.12,centerLon:117.2,distance:15000)` + `sortOrder` 追加末位。软删。

**`CustomFieldSettingsTab`**(按 entityType 分组):`@Query` CustomFieldDef,先按 `entityType` 分组(school/compound/poi/area),组内按 `sortOrder`。每项:`label`(TextField)、`key`(新建后**只读** —— 标识符,改了会与已存 `customFieldsJSON` 失配)、`type`(Picker: string/int/double/bool/date/multiline)、`unit`(TextField,可空)、`pinnedToCard`(Toggle)。新建:选 entityType 后建 `CustomFieldDef(datasetId:entityType:key:label:type:source:"user")`,key 默认占位待用户填(新建态可改,持久化后锁定)。软删。

**`ThemeSettingsTab`**(中等):`@Query` Theme + StyleRule(供勾选)。每项:`name`、`sortOrder`、`isActive`(Toggle)、`showLegend`(Toggle)、`styleRuleIds` 多选(列出本 dataset 未删 StyleRule,勾选写回数组)、`defaultStylesJSON`(多行 TextEditor,失焦校验:`JSONSerialization.jsonObject` 不通过则红字提示"无效 JSON"且不写回)。新建:`Theme(datasetId:name:"新主题")` + sortOrder 末位。软删。

**`StyleRuleSettingsTab`**(最重):`@Query` StyleRule + Palette(palette 模式用)。每项分段:
- 基本:`name`、`entityType`(Picker: school/compound/poi/area)、`enabled`(Toggle)、`priority`(Stepper/数字)。
- 形状/标签:`appliesShape`(Picker,取 `PinShape` 全部 rawValue + "(无)"=nil)、`appliesLabelVisible`(三态:nil/true/false,用可选 Toggle 或 Picker)。
- 填充:`appliesFillMode`(Picker fixed/palette)。fixed → `ColorHexField`(`appliesFillHex`);palette → Palette Picker(`appliesPaletteId`)+ `appliesPaletteKeyField`(TextField)。
- glyph:`appliesGlyph`(TextField,SF 符号名或单字)+ `appliesGlyphHex`(`ColorHexField`)。
- 描边/尺寸:`appliesStrokeHex`(`ColorHexField`)、`appliesStrokeWidth`/`appliesSize`/`appliesFillOpacity`(数字,可空)。
- 条件:`conditionsJSON` 编辑 —— 一组 `StyleCondition{field, op, value}` 行,新组件 `StyleConditionRow`(仿 `FilterConditionRow`):`field`(TextField,字段 key)、`op`(Picker `StyleConditionOp`:equals/notEquals/in/contains/gte/lte/exists)、`value`(复用 `AnyJSONValueField`)。增删条件行,经 codec 序列化回 `conditionsJSON`。

新建 StyleRule:`StyleRule(datasetId:name:"新规则",entityType:"compound")`,`priority` 末位。软删。

### 抽出的纯逻辑(带单测)

- **`StyleConditionCodec`**(`Studio/Settings/` 或 `DataKit/`):`decode(_ json:String) -> [StyleCondition]` / `encode(_:[StyleCondition]) -> String`(空/坏 JSON → `[]` / `"[]"`)。给 StyleConditionRow 用。
- **`CameraFieldClamp`**(纯函数,或 CameraSettingsTab 内 static):`clampPitch(_:Double)->Double`(0…85)、`clampHeading(_:Double)->Double`(0…<360,取模)。setter 用。
- **`JSONValidator.isValidObject(_ s:String) -> Bool`**(若仓内无同类):`defaultStylesJSON` 校验用(`JSONSerialization.jsonObject` 成功即真;空串视为有效=清空)。先查现有 `JSONHelpers` 是否已有可复用项,有则不新增。

## 数据流

```
SettingsSheet (8 段 Picker)
  └─ <Entity>Tab: @Query[Entity].filter(datasetId, !deleted)
       ├─ 控件 → entity.field = v; entity.updatedAt = Date()   (SwiftData 自动存)
       ├─ 软删: entity.deleted = true
       └─ 新建: modelContext.insert(Entity(...))
StyleRule.conditionsJSON  ⇄  StyleConditionCodec  ⇄  [StyleConditionRow]
```

渲染端自动反映:`MapViewContext.activeTheme` / `StyleResolver` 已实时读这些实体,改完即生效(无需额外接线)。

## 错误处理

- `defaultStylesJSON` / `conditionsJSON`:无效 JSON 不写回 + 行内红字提示;空串合法(= 清空 → `"[]"` 或 `"{}"`)。
- CameraPreset 数字越界:pitch/heading clamp;lat/lon/distance 接受任意 Double(地图自处理)。
- `CustomFieldDef.key` 持久化后只读,防失配。
- 删除一律软删(`deleted=true`),不硬删 —— 与全仓一致。

## 测试

- **纯逻辑单测**(Swift Testing):
  - `StyleConditionCodec`:round-trip(含 op=in/exists、value 各类型 AnyJSON)、坏 JSON → `[]`、空 → `[]`。
  - `CameraFieldClamp`:pitch -10→0 / 90→85;heading 370→10 / -10→350。
  - `JSONValidator`(若新增):合法对象真、坏串假、空串真。
- **SwiftUI 部分**:`xcodebuild build` 绿 + 启动不崩(同 P9a;无 SwiftUI 单测)。
- **smoke**:无 schema 改动 → **不需要清库重迁**。常规启动一次(沿用现有 dev store),打开 Settings 八个 tab 均无崩、能增删改一项即可。全量 `xcodebuild test` 通过(含新纯逻辑测试)。

## 执行前需 grep 确认(交给 plan)

- `PinShape` 的 rawValue 全集(`appliesShape` Picker 选项)位置。
- `AnyJSONValueField` 的确切接口(P9a 组件,StyleConditionRow 复用)。
- `FilterConditionRow` 的结构(StyleConditionRow 仿写参照)。
- `JSONHelpers` 是否已有 JSON 校验/`StyleConditionCodec` 等价物(优先复用,避免重复)。
- `SettingsSheet` 的 tab enum 与 segmented 控件确切写法(扩 8 段)。

## 影响面小结

- **新增**:4 个 `*Tab.swift` + `StyleConditionRow` 组件 + `StyleConditionCodec`(+ 可能 `CameraFieldClamp`/`JSONValidator`)+ 对应单测。
- **改**:`SettingsSheet.swift`(tab enum + 段 + switch 各加 4)。
- **不动**:实体 @Model、渲染引擎、StyleResolver、seed 管线、CloudKit、逐图层 theme(明确不做)。
- **收益**:Theme/StyleRule/CameraPreset/CustomFieldDef 全部 app 内可编辑;StyleRule 编辑器大幅增强单 theme 内的染色能力。
