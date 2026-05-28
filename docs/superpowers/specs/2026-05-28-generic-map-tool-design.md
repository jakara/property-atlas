# PropertyAtlas → 通用房产中介地图工具 — 设计文档

**日期**: 2026-05-28
**状态**: 设计待实施
**取代**: `docs/superpowers/specs/2026-05-19-tianjin-house-design.md` (天津学区房定位)
**关联**: 后续生成实施计划 `docs/superpowers/plans/2026-05-28-generic-map-tool.md`

---

## 1. 背景与产品定位

### 1.1 产品转向

原产品是 **iPad-first 天津学区房研究工具**，含 174 楼盘 / 823 学校 / 101 学片的预设数据。现转向 **服务全国房产中介的内容生产工具**，主要使用场景：

- **直播取景源**：中介开直播时，把 Studio 投屏作画面源，实时拖 pin、切图层、点选实体讲解；
- **静态截屏**：导出 PNG/JPG 用于公众号头图、朋友圈、直播间贴片。

### 1.2 监管规避原则

**不在 UI 文案与字段名中出现"学区"、"对口"、"派位" 等学区政策直接相关的术语**。产品能力上支持表达"地理实体之间的关系"，但具体含义、命名、讲解 **完全由中介自定义**。例如"对口小学"作为关系 label 由中介自己输入，系统不预置。

被规避的政策性概念（不进 baseField，不进默认 schema）：
- 1-1 派位 / 多校划片 / 全区摇号 / 学籍 / 户籍年限 / 招生范围 / 录取率 / 升学率 / 学区房

被保留的中性属性：
- 学校的 `category`（小学/中学/幼儿园…）、`grade`（重点/普通…）等枚举字段保留为 baseField，**但枚举值由中介自定义**，系统不预置政策含义。

### 1.3 关键设计决定

| 维度 | 决定 |
|---|---|
| 输出形态 | 直播取景源 + 静态截屏（不做视频导出/帧动画） |
| 数据策略 | 内置天津 demo dataset 作首启动样本，中介可 wipe 重建 |
| 实体抽象 | 4 固定类型：Compound（小区）/ School（学校）/ POI（兴趣点）/ Area（面片） |
| 关系模型 | 通用 Edge 多对多 + Pin 可选 primary Area（默认上色分组） |
| 协同 | iCloud 私有库（个人多设备同步）+ `.tjmap.zip` 文件导入/导出（团队共享） |
| 数据来源 | 手动点 + 表单 + Apple/高德 POI 搜索（不做 CSV 批量） |
| 样式系统 | StyleRule（字段值 → 样式）+ Palette（自动配色）+ Entity override（个体强覆盖）+ Theme（一键切场景） |
| 显示控制 | Layer（entity 集合 + zoom 触发）+ FilterFieldConfig（per-type 最多 3 个过滤+图例字段，含 viewport 计数） |
| 讲解交互 | 点击实体 = 详情卡 + 按 Edge label 分 tab + 切 tab 高亮关联实体 |

---

## 2. 总体架构

### 2.1 概念模型

```
Dataset (容器, 中介可多: '天津 demo' / '北京海淀' / '杭州滨江')
├── Entities (4 类固定)
│   ├── Compound  · Pin · 小区/楼盘
│   ├── School    · Pin · 学校/机构
│   ├── POI       · Pin · 通用兴趣点 (地铁/商场/医院/办事处)
│   └── Area      · Polygon · 面状区域 (片区/商圈/管辖区)
├── Edges    · 任意两实体间, typed (中介命名), 多对多
├── CustomFieldDefs · dataset 级 schema, per entityType 注册中介加的自定义字段
├── EnumOptions  · per scope (school.category / edge.label / ...) 维护中介自定义枚举值
├── FilterFieldConfigs · per entityType 最多 3 个过滤+图例字段 (含 viewport 计数)
├── Layers · 命名 entity 集合 (static ∪ dynamic) + zoom 触发, 默认 layer "全部" 不可删
├── StyleRules · per entityType, 条件 → 样式 (含 palette 模式)
├── Palettes   · 调色板 (内置 + 中介加)
├── Themes     · 一组 styleRule + cameraId + 文案 + 可见性 + defaultEnabledLayerIds, 直播一键切
├── Tags       · 通用标签
├── Photos     · 关联 entity
├── Documents  · PDF/富文本附件, 挂任意 entity
├── CameraPresets · 跨 dataset 镜头预设
└── activeThemeId, activeCameraPresetId
```

### 2.2 模块边界

- **DataKit**：所有 `@Model` + CRUD + 校验 + import/export 序列化，不依赖 UI；
- **MapRender**：输入 entities + active theme → 输出 `MKAnnotation` / `MKOverlay` + style，不直接读 SwiftData；
- **Studio**：SwiftUI 编辑面板 + Theme manager + 直播取景态切换，调 DataKit + MapRender；
- **Explore**：iPad 浏览模式（现场看房用，可禁编辑）。

### 2.3 数据流

1. 首启动 → 检测无 dataset → onboarding sheet（导入天津 demo / 空 dataset / 文件导入）；
2. 中介切到目标 dataset，进 Studio 编辑或取景模式；
3. Studio 显示 active Theme：拉取 StyleRules 应用到 entities，相机跳预设，copy 显文案区；
4. 点击 entity → 详情卡浮出 + 按 Edge label 分 tab + 切 tab 时地图高亮对应关联组（脉冲动画）；
5. 编辑 entity → 右抽屉表单 → 实时反映地图；
6. 导出 dataset → `.tjmap.zip`（entities + edges + styles + themes + raster 资源）。

### 2.4 错误处理

- 导入文件 schema 不匹配 → 弹窗显缺失字段，允许跳过；
- CloudKit sync 冲突 → server-wins（last-write），本地副本写 `Documents/conflicts/`；
- StyleRule 引用已删字段 → rule 标 invalid，UI 灰显，不崩；
- 渲染时 entity 无 geometry → 跳过 + log warning；
- Raster 文件丢 → 占位灰色 + warning chip。

---

## 3. 实体字段 schema

### 3.1 通用 baseFields（所有 Pin 共有）

```swift
id: UUID
datasetId: UUID
name: String                  // 主显示名
aliases: [String]             // 搜索辅助
geometry: Point | Polygon     // entityType 决定
address: String?
primaryAreaId: UUID?          // 默认归属 Area, 决定 pin 颜色分组 (替代旧 zoneId)
notes: String?                // 公开备注 (直播可展示)
privateNotes: String?         // 私密备注 (不进 export, 不显直播)
customFieldsJSON: String?     // {key: value} 由 CustomFieldDef 描述 schema
overrideStyleJSON: String?    // entity 级样式覆盖, nil 跟随 theme
photoIds: [UUID]
contact: ContactInfo?         // phone/wechat/contactName
sourceUrl: String?
createdAt, updatedAt, deleted, version
```

### 3.2 各类型 baseFields

| 实体 | 形态 | baseFields (非通用部分) |
|---|---|---|
| **Compound** | Point | `buildYear`, `developer`, `propertyMgmt`, `propertyFeeCents`, `landYears`, `finishType`(enum), `deliveryTime`, `isNewHouse`, `availableUnits`, `areaSegments`, `priceSegments` |
| **School** | Point | `category`(enum), `grade`(enum), `form`(enum: 普通/九年一贯/十二年制), `foundYear`, `capacity`, `communitiesText`, `phone`, `websiteUrl`, `motto` |
| **POI** | Point | `category`(enum: 中介自定义) |
| **Area** | Polygon\|Raster | `category`(enum), `geometryKind`("polygon"/"raster"), `geometryJSON`, `rasterImageRef`, `strokeHex`, `fillOpacity`, `textDescription` |

**所有 `enum` 字段值由中介通过 `EnumOption` 维护**，系统首启动塞天津 demo 默认值（中介可随时改）。

`district` 字段 **砍掉**：通过 `primaryAreaId` 指向"行政区" Area，或走 Tag/customField。

### 3.3 CustomField 系统

dataset 级 schema 注册：

```swift
@Model CustomFieldDef {
  id, datasetId
  entityType: String          // "compound"/"school"/"poi"/"area"
  key: String                 // 内部 key, unique per (datasetId, entityType, key)
  label: String               // 显示名
  type: String                // string/multiline/int/double/bool/date/enum/tag/url/money
  enumOptionsJSON: String?
  unit: String?               // "元","套","年","%","㎡"...
  defaultValueJSON: String?
  pinnedToCard: Bool = false  // 详情卡 quick row 显
  showInLegendChip: Bool = false
  sortOrder: Int = 0
  source: String              // "migrated"/"user"/"seed"
  createdAt, updatedAt, deleted, version
}
```

Entity 上 `customFieldsJSON` 仅存值字典，schema 由 `CustomFieldDef` 描述。编辑表单按 def 渲染，每条 def 一行 input。

新增 customField 流程：editor 自定义 tab → `[+ 加字段]` → 填 key/label/type/(enumOptions/unit) → 创建 def → 编辑器立即多出该字段。**之后同 dataset 同 type 别的 entity 编辑时自动可见此字段待填**，达到"一处定义，dataset 内通用"。

删除 def → 软删，历史值保留在 entity customFieldsJSON 但 UI 不显；恢复 def 数据回来。

### 3.4 字段类型映射

```
string     → TextField
multiline  → TextEditor
int/double → NumberField (可带 unit)
bool       → Toggle
date       → DatePicker
enum       → Picker, options from EnumOption
tag        → ChipPicker, refs Tag entity
url        → URLField (可点)
money      → MoneyField (¥ 前缀, 分单位整数)
```

---

## 4. 关系模型（Edge）

### 4.1 Edge schema

```swift
@Model Edge {
  id: UUID
  datasetId: UUID
  fromId: UUID, fromType: String   // "compound"/"school"/"poi"/"area"
  toId:   UUID, toType:   String
  label: String                    // 中介自定义, 从 EnumOption scope="edge.label" 选
  directed: Bool = false           // 仅影响文案 ("属于"/"包含" vs "周边"); 高亮始终双向
  note: String?
  sortOrder: Int = 0
  createdAt, updatedAt, deleted, version
}
```

**索引**: `@Index(fromId)`, `@Index(toId)`, `@Index(datasetId, label)`。

查询: `entityId → 双向收 (fromId == X OR toId == X) → groupBy(label)`。

### 4.2 校验

- 同 `(from, to, label)` 不允许重复（warn + skip）
- `from == to` 拒绝（无自连）
- 删 entity → 级联软删相关 Edge（deleted=true）

### 4.3 详情卡 tab 结构

点击某 entity → 右抽屉详情卡：

```
[School: 鞍山道小学]
header: 大图 + 主标题 + grade/category chip
default tab: 字段表 (baseFields + pinnedToCard 优先的 customFields)
tab: <label_1>  (该 entity 的 Edge group, e.g. "周边小区"列 N Compound)
tab: <label_2>  (e.g. "片内"列 N Area/Compound)
tab: <label_3>  (e.g. "集团校"列 N School)
tab: 媒体 (Photo + Document)
```

- tab 列表 = 该 entity 的 Edge 按 label 分组（空 label 组不显）
- 切 tab → 地图淡出其他 entity，仅 highlighted 关联组高亮（`Theme.spotlightOnSelect=true` 时）
- 关联 entity 点击 → 详情卡换为该 entity

### 4.4 Edge 编辑入口

1. **Entity 关联 tab**: `[+ 加关联]` → entity 搜索 picker（按 type 过滤）→ 选 label（EnumOption picker，可加新）→ 写 note → 保存；
2. **Settings → Edges 表格视图**: 全 dataset edge 列表（from/type/label/to/note），可批量删/改 label。

### 4.5 视觉

- 默认不画连线（直播视觉干扰小）；
- Theme 可选 `drawEdgeLines: [labelA, labelB]` → 对指定 label 画 dashed 线；
- 选中 entity 时关联组脉冲高亮。

---

## 5. 样式系统（StyleRule / Palette / Theme / Entity override）

### 5.1 求值链

```
final = default(entityType)
      → matching StyleRules (priority DESC, nil-skip merge)
      → entity.overrideStyleJSON (最高优先)
```

任一字段缺 → 回退上一层。

### 5.2 StyleRule

```swift
@Model StyleRule {
  id, datasetId, name
  entityType: String                  // compound/school/poi/area
  conditionsJSON: String              // [{field, op, value}], all AND
  priority: Int = 0                   // 高优先先匹配, 多 rule 命中按 priority 合并
  appliesShape: String?               // circle/square/hexagon/diamond/triangle/star
  appliesFillMode: String = "fixed"   // fixed / palette
  appliesFillHex: String?             // fillMode=fixed 时用
  appliesPaletteId: UUID?             // fillMode=palette 时用
  appliesPaletteKeyField: String?     // 调色板 index 来源 (nil → entity.id)
  appliesStrokeHex: String?
  appliesGlyph: String?               // 1-2 char
  appliesGlyphHex: String?
  appliesSize: Int?                   // 16-40 pt
  appliesLabelVisible: Bool?
  appliesFillOpacity: Double?         // Area only
  appliesStrokeWidth: Double?
  enabled: Bool = true
  createdAt, updatedAt, deleted, version
}
```

**Conditions** 操作符：`equals`, `notEquals`, `in`, `contains`, `gte`, `lte`, `exists`。所有条件 AND。

### 5.3 Palette

```swift
@Model Palette {
  id, name
  colorsHex: [String]
  builtIn: Bool
  sortOrder
  createdAt, updatedAt, deleted, version
}
```

**内置 Palette 种子**：
- `default-rainbow`（10 色彩虹）
- `category-cool`（6 色冷色）
- `category-warm`（6 色暖色）
- `mono-blue`（4 色浅深蓝）

**Palette 模式求值**：
```swift
let keyValue = rule.appliesPaletteKeyField
  .map { entity.field($0) ?? entity.id.uuidString }
  ?? entity.id.uuidString
let idx = stableHash(keyValue) % palette.colorsHex.count
fill = palette.colorsHex[idx]
```

`stableHash`：FNV-1a 32-bit，跨设备/跨平台结果一致（不能用 Swift `Hasher`，后者在进程间随机种子）。

- `paletteKeyField = nil` 或 `"id"` → 每 entity 唯一色（"每个 Area 自动不同色"）
- `paletteKeyField = "name"` → 同名同色（跨 dataset 一致）
- `paletteKeyField = "category"` → 同分类同色

### 5.4 Theme

```swift
@Model Theme {
  id, datasetId, name, isActive
  cameraPresetId: UUID?
  styleRuleIds: [UUID]                // theme 启用的 rule 子集 (有序)
  defaultStylesJSON: String           // per entityType 兜底
  visibilityJSON: String              // {compound:true, school:true, poi:false, area:true}
  defaultEnabledLayerIds: [UUID] = [] // 切 theme 时初始化 Layer enable 状态 (运行时改不回写)
  spotlightOnSelect: Bool = true      // 选中时其他 dim 30%
  drawEdgeLines: [String] = []        // 画连线的 edge label list
  showLegend: Bool = true
  bgMapStyle: String = "standard"     // standard/satellite/hybrid
  copyTitle: String?, copySubtitle: String?, copyWatermark: String?
  sortOrder, createdAt, updatedAt, deleted, version
}
```

**ActiveTheme**：存于 `Dataset.activeThemeId`，Studio toolbar segmented control 一键切。切换触发 `@Query` 重渲染。

**默认 theme 种子** (跟随天津 demo)：
- "字段总览"：所有 entity 显示，default style per type，no rule（编辑模式用）
- "学区视图"：School 按 category/grade 上色 + Area palette 色块
- "商圈视图"：仅 POI + Area
- "新房地图"：仅 Compound，finishType 颜色映射

### 5.5 Entity override

所有 Pin/Area 加 `overrideStyleJSON: String?`，存：

```json
{"shape":"diamond","fillHex":"#7C3AED","glyph":"★","size":28,"labelVisible":true}
```

任一字段缺 → 该属性回退 theme 链。

Entity editor 基本 tab 底加 **样式 disclosure**（默认折叠）：
```
▾ 样式 (默认跟随主题)
  形状: ⦿ 跟随主题  ○ ●  ○ ■  ○ ⬡  ○ ◆
  填色: ⦿ 跟随主题  ○ [#7C3AED ColorWell]
  Glyph: [____ TextField 0/2]
  Size: ⦿ 跟随  ○ ▒▒○○○○○○ (24pt)
  Label: ⦿ 跟随  ○ 显  ○ 隐
  [清空 override → 跟随]
```

**切 theme 时 entity override 始终保留**（中介个性化不被冲掉）。切 theme 给"重置 override"选项。

### 5.6 Legend 自动生成

由 active Theme 的 enabled rules + visible entity types + 启用 Layer 列条目（颜色样块 + glyph + 名称 + 数量）。详见 § 5.7 Filter 字段配置。

### 5.7 Filter 字段配置（per-entityType 最多 3 个，含 viewport 计数）

每实体类型最多 3 个"过滤+图例字段"，字段可选 baseField 或 customField。Legend 自动按 distinct value 列 chip，点击 toggle 隐显。

```swift
@Model FilterFieldConfig {
  id, datasetId
  entityType: String              // "compound"/"school"/"poi"/"area"
  fieldKey: String                // baseField 名 或 CustomFieldDef.key
  fieldSource: String             // "base" / "custom"
  label: String                   // legend 显示名
  slot: Int                       // 1/2/3 (per entityType 最多 3 个)
  showInLegend: Bool = true
  showSwatch: Bool = true         // chip 前是否显色样块 (取自 StyleRule/Palette 求值)
  expandedByDefault: Bool = true  // legend 该组默认展开
  createdAt, updatedAt, deleted, version
}
```

约束：同 `(datasetId, entityType, slot)` 唯一，slot ∈ {1,2,3}。

**Settings → 字段定义** 子页加 "过滤字段" tab：
```
─ Compound ─────────────
  slot 1: [finishType ▾]  label[精装类型]   ☑ legend ☑ swatch
  slot 2: [isNewHouse ▾]  label[新房/二手]   ☑ legend ☑ swatch
  slot 3: [+ 加]
─ School ─────────────
  slot 1: [category ▾]    label[阶段]       ☑ ☑
  slot 2: [grade ▾]       label[等级]       ☑ ☑
  slot 3: [form ▾]        label[学制]       ☑ ☑
─ POI ───────────────
  slot 1: [category ▾]    label[POI 类型]   ☑ ☑
─ Area ──────────────
  slot 1: [category ▾]    label[区域类型]   ☑ ☑
```

**Legend 渲染**（每 chip 显两个数字：当前屏 / 全 dataset）：
```
─ Legend (视图内 234 / 全集 1009) ─
  ▾ School    [83 / 823]
     阶段
        ● 小学    [50 / 411]    [hide]
        ■ 初中    [33 / 412]    [hide]
     等级
        ● 重点    [12 / 12]     [hide]
        ● 区重点  [8 / 38]      [hide]
        ○ 普通    [63 / 773]    [hide]
     学制
        ● 普通       [hide]
        ⬡ 九年一贯   [hide]
        ⬡ 十二年制   [hide]
  ▾ Compound  [142 / 174]
     精装类型
        ● 精装    [120 / 145]   [hide]
        ● 毛坯    [22 / 29]     [hide]
     ...
  ▾ POI       [9 / 412]
     ...
```

每 chip 点击 → 隐含 entity 该字段=值 的实例 + chip 灰显。AND 跨 slot，OR 跨 value。折叠/展开按 entityType。

**色样块**：由 StyleRule + Palette 实时求值（legend 与地图视觉一致）。

**Viewport 计数计算**：
```swift
struct LegendChipCount {
  let viewport: Int      // 同 type + 字段 = value + 在 region bbox + 过 active filters (除自身) + 在启用 Layer
  let total: Int         // 同上但忽略 viewport bbox
}
```

**刷新策略**：
- `MapContainerView.onRegionChange` 触发 → debounce 200ms → 重算所有 chip count
- 数据流：region → entityFetch(bbox) → groupBy (type, fieldKey, value) → 写 `@Observable LegendState`
- 大 dataset (N > 5000)：SwiftData `#Predicate` + bbox 过滤；内存中 spatial index (R-tree) 暂不引入，视实测加
- 计算 chip 自身 count 时，**排除自身这个字段的 filter**（避免点了"重点" chip 后该 chip count 变 0 看不出还能恢复）
- 跨字段的 active filter 仍生效
- count 结果按 `(region, filter, layer)` 签名缓存，签名变才失效

**接受标准**：
- 拖动地图后 200-300ms 内 count 刷新
- 点 chip 后 count 即时变（不等地图）
- 切 theme 重置 filter 后 count 全量重算
- Layer 启停立即影响 count

**默认 FilterFieldConfig 种子**（天津 demo）：
- compound: `finishType`, `isNewHouse`
- school: `category`, `grade`, `form`
- poi: `category`
- area: `category`

迁移：旧 `PinFilter`（tiers/levels/jiunianVisible 写死）砍，等价能力由 school slot1=category, slot2=grade, slot3=form 实现。

### 5.8 Layer（图层）

图层 = 命名的 entity 集合 + zoom 触发。用于在不同缩放维度精准控制展示，避免一次性堆 POI。

```swift
@Model Layer {
  id, datasetId, name
  iconSF: String?                 // SF Symbol (toolbar icon)
  colorHex: String?               // 图层指示色 (legend/toolbar)
  staticRefsJSON: String?         // [{entityId, entityType}] 显式加入
  dynamicQueryJSON: String?       // {entityType, conditions:[...]} 同 StyleRule.conditions
  minZoom: Double?                // 地图 zoom < min 时隐
  maxZoom: Double?                // 地图 zoom > max 时隐
  isDefault: Bool = false         // 默认全集 layer (不可删)
  enabled: Bool = true            // 中介当前是否启用 (运行时态, 由 Theme.defaultEnabledLayerIds 初始化)
  sortOrder: Int
  createdAt, updatedAt, deleted, version
}
```

**Member 求值**：`members = staticRefs ∪ (entities matching dynamicQuery)`。任一为空允许。

**Zoom**：MapKit `altitude` 标准化为 [0..21] zoom level。Layer 在视图当前 zoom < minZoom 或 > maxZoom 时整体隐。

**渲染逻辑**：
```swift
let visibleByType = theme.visibility            // {compound:true,...}
let enabledLayers = layers.filter { $0.enabled && $0.matchesAtZoom(currentZoom) }
let layerMembers: Set<UUID> = enabledLayers.flatMap { $0.members }.asSet
let visibleEntities = allEntities
  .filter { visibleByType[$0.type] }
  .filter { enabledLayers.isEmpty(forType: $0.type) || layerMembers.contains($0.id) }
  .filter { passesFilters($0) }        // §5.7 filter chips
```

**默认 layer**：首启动种入 `name="全部"`, `isDefault=true`, dynamicQuery 匹配全部 entity，无 zoom 限。永不能删（UI 删除按钮灰显）。

**Studio 左抽屉新增 Layers section**：
```
─ Layers ───────────
  ☑ 全部 (默认)        ⓘ 0-21
  ☑ 学校全集            ⓘ 0-12
  ☑ 重点学校            ⓘ 0-21
  ☐ 商圈细节            ⓘ 12-21
  ☐ 地铁站              ⓘ 8-21
  ☐ 实地踩盘            ⓘ 14-21
  [+ 新建 layer]
```

多选 toggle。当前 zoom 不在 layer 范围时该 layer 灰显 + 提示。

**Layer 编辑器**（Settings → Layers）：
```
┌── 编辑 layer ───────────────────────────┐
│ name: [重点学校]                          │
│ 图标 SF: [star.fill]    色: [#FF3B30]    │
│ zoom 范围: [0]___[21]  slider            │
│ 动态规则:                                  │
│   entityType: [School ▾]                  │
│   when: grade in [重点, 区重点]            │
│   [+ 条件]                                │
│ 静态加入:                                  │
│   [+ 从地图选]  / 当前: 0 entities        │
│ 预览: 命中 50 entities                    │
│ [取消]              [保存]                │
└─────────────────────────────────────────┘
```

**Theme × Layer 集成**：
- `Theme.defaultEnabledLayerIds: [UUID]` — 切 theme 时初始化 layer enable 状态；中介运行时 toggle 不回写 theme
- "学区视图" theme 默认 enabled：[全部, 重点学校]
- "商圈视图" theme 默认 enabled：[地铁站, 商圈细节, 重要商场]
- "新房地图" theme 默认 enabled：[新房楼盘]

**用例覆盖**：
- 中介开直播讲学区：启 "学校全集 (zoom 0-12)" + "重点学校 (zoom 0-21)"。拉远只见重点，拉近见全集。
- 切讲商圈：一键启 "地铁站" + "商圈细节"，学校自动从画面消失。
- 临时高亮某 5 个小区：新建 layer "本期重点 5 盘"，静态加入，zoom 全程。

---

## 6. 编辑页 UI

### 6.1 主界面布局（Studio = 主模态）

```
ZStack:
  MapContainerView (full screen, ignoresSafeArea)              z=0
  TopToolbar       (capsule, top center)                        z=30
    └─ [Dataset ▾] [Theme ▾] [Mode: 编辑/取景 toggle]
       [📸 截屏] [📡 直播取景态] [⚙ Settings]
  LeftDrawer (visible 编辑 mode only, 浮动)                       z=10
    └─ Layers + Legend (含 viewport count, 过滤 chip) + Visibility + StyleRule quick edit
  RightDrawer (selected entity 时浮出)                            z=10
    └─ EntityCard (read) / EntityEditor (edit)
  BottomChips (camera presets, scrollable)                       z=15
  WatermarkOverlay (右下, always)                                 z=20
```

抽屉宽：Mac 0.382，iPad 0.42。

### 6.2 取景态

按 📡 → chrome 全隐，仅保留：
- 左上 Theme picker（小，hover 展开）
- Esc 按钮
- 详情卡（点 entity 时浮出）
- 底部条幅（Theme.copyTitle/Subtitle 大字号渲染）

### 6.3 EntityEditor 通用结构

```
┌── 实体编辑器 ─────────────────────────────────┐
│ [🏘️ Compound chip] [name TextField (大号)]     │
│                              [⋯ menu: del/dup] │
├─ Tabs: 基本 · 关联 · 媒体 · 自定义 · 私密 ─────┤
│                                                │
│ 基本 tab:                                       │
│   坐标 [39.122, 117.193] [📍 地图点选]          │
│   地址 [TextField]                              │
│   归属面片 [Area picker ▾]                      │
│   (per-type baseFields 罗列)                    │
│   ▾ 样式 (默认跟随主题) ← override               │
│                                                │
│ 关联 tab:                                       │
│   [+ 加关联] [按 label 分组列表]                │
│                                                │
│ 媒体 tab:                                       │
│   [+ 加图] [+ 加文档]                           │
│                                                │
│ 自定义 tab:                                     │
│   按 CustomFieldDef list 渲染 + [+ 加字段]      │
│                                                │
│ 私密 tab:                                       │
│   privateNotes TextEditor (⚠ 不进 export/直播)  │
│                                                │
│ [取消]                  [保存] (自动保存默)     │
└────────────────────────────────────────────────┘
```

### 6.4 创建流程

- **Pin 类**（Compound/School/POI）：地图长按（iPad）/ 右键（Mac）→ 菜单 `[+ Compound / + School / + POI]` → entity 落点，右抽屉打开 editor，name 字段聚焦；
- **POI 搜索创建**：top toolbar 搜索框（Apple MKLocalSearch + 可选高德）→ 搜索结果列表 → 选 → 自动填 name/lat/lon，类型默 POI；
- **Area 绘制**：top toolbar `[✏️ 绘 Area]` → polygon mode → 地图点 vertex → 双击完成 → editor 开；
- **Area raster**：editor 切到 raster mode → 上传图 → 拖 4 角到地标 → 保存。

### 6.5 Settings 页

```
Settings
├── Datasets        新建/重命名/激活/导入/导出/清空
├── Themes          列表 + 编辑器
├── Style Rules     列表 + 编辑器
├── Palettes        列表 + 编辑器
├── Layers          列表 + 编辑器 (zoom/规则/静态成员)
├── Enum 字典       per scope (school.category / edge.label / ...)
├── 字段定义        per entityType
│   ├── 基本/Custom: 编辑 CustomFieldDef
│   └── 过滤字段:    编辑 FilterFieldConfig (最多 3 slot)
├── Cameras         列表 + "当前镜头另存为 preset"
└── 备份/同步       iCloud 状态 + 手动 export .tjmap.zip
```

### 6.6 平台适配

| 平台 | 主输入 | 关键交互 |
|---|---|---|
| Mac Catalyst | 键鼠 | 右键菜单 + 快捷键（⌘N / ⌘S / ⌘E / ⌘L / ⌘1-9） |
| iPad | 触屏 | 长按菜单 + 滑动 drawer + Pencil 绘 polygon |

### 6.7 状态管理

`@Observable AppState` 持：
```swift
activeDatasetId: UUID
activeThemeId: UUID?
selectedEntityId: UUID?, selectedEntityType: String?
editingMode: .read | .edit | .live
currentEditTab: .basic | .relations | .media | .custom | .private
```

切 dataset → reset selection；切 theme → recompute style 不动 selection；Editor 关闭无保存 → 弹 confirm sheet。

---

## 7. 同步、导入导出

### 7.1 CloudKit 私有库

```swift
ModelConfiguration(cloudKitDatabase: .private(...))
```

**全部 @Model 进私库**（中介跨 iPad/Mac 同步）：
`Dataset, Compound, School, POI, Area, Edge, CustomFieldDef, EnumOption, FilterFieldConfig, Layer, StyleRule, Palette, Theme, Photo, Document, Tag, CameraPreset`。

Photo / Document 走 `@Attribute(.externalStorage)` 自动 CKAsset。

**不进 CloudKit**：
- `AppSettings`（UserDefaults，设备本地）；
- bundled demo raster（main bundle，不入 store）；
- export `.tjmap.zip` 临时文件（`Documents/exports/`）。

**冲突**：SwiftData/CloudKit 默认 last-write-wins。出现 → 本地副本写 `Documents/conflicts/${date}/${entityId}.json` 留底 + warning log。不阻塞 UI。

**Mac Catalyst CloudKit**：**开启**（同步私库）。旧 CLAUDE.md 写"Mac Catalyst 下不开 CloudKit"作废。

### 7.2 `.tjmap.zip` 文件格式

```
manifest.json              # {version:"1.0", schema:"tjmap-1", exportedAt, datasetIds:[...]}
datasets/${id}.json        # Dataset 元 + activeThemeId
entities/compounds.json
entities/schools.json
entities/pois.json
entities/areas.json
edges.json
styles/rules.json
styles/themes.json
styles/palettes.json
display/layers.json
display/filterFields.json
vocab/customFieldDefs.json
vocab/enums.json
vocab/tags.json
cameras.json
photos/${photoId}.heic
documents/${docId}.${ext}
rasters/${areaId}.png
```

### 7.3 导入流程

1. 选 `.tjmap.zip` → 预览（含 N entities, N edges, N themes）；
2. 选择目标：新建 dataset / 合并到 active；
3. 合并模式：id 冲突 → 询问（keep local / replace with import / skip）；
4. 流式解压，transaction commit；失败 rollback；
5. raster/photo/document 文件解压到 `Documents/${datasetId}/`；
6. 版本兼容：manifest schema 版本检查，不支持时提示升级。

### 7.4 首启动 Onboarding

```
检测 count(Dataset) == 0?
  → Sheet (modal, 不可跳过):
     标题: 选个起点
     1. [导入天津 demo dataset]  (bundled .tjmap.zip)
     2. [新建空 dataset]         输入名 → 创建
     3. [从文件导入]             → file picker
  完成后跳 Studio 编辑态.
```

### 7.5 Wipe / 重置

Settings → Datasets → row swipe → confirm sheet：
- "删除 dataset 「天津 demo」?  含 174 Compound / 823 School / 32 Theme / 1.2 GB 媒体" → confirm
- Cascade：del Dataset，全部 entity（datasetId == X），全部 Edge（任一端 entity 删），Photo/Document，Theme/StyleRule/Palette，Layer，FilterFieldConfig，EnumOption，CustomFieldDef，CameraPreset，Tag，raster files。

"重置为天津 demo" 按钮：del active + 重导 bundled。

### 7.6 错误恢复

| 场景 | 处理 |
|---|---|
| Import schema 版本 > 当前 | Sheet "请升级 App"，拒绝导入 |
| Import 文件损坏 | Sheet 显错误位置，rollback |
| Sync 冲突 | server-wins + 本地备份 |
| 删 entity 时残留 Edge | 级联软删 |
| StyleRule 引用已删字段 | rule 标 invalid，UI 灰显 |
| 渲染时 entity 无 geometry | 跳过 + warning |
| Raster 文件丢 | 占位灰色 + warning chip |

---

## 8. 旧 → 新数据迁移

### 8.1 总原则

**砍掉的旧 baseField 若有现存数据，注册成 CustomFieldDef + 数据写到对应 entity 的 customFieldsJSON。不丢数据。**

### 8.2 字段级映射

| 旧字段 | 新位置 | 处理 |
|---|---|---|
| `Compound.zoneId` | `Compound.primaryAreaId` | 重命名 |
| `Compound.primarySchoolId` | Edge(Compound→School, label="对口小学", directed) | 砍 baseField |
| `Compound.sensitive*` | `Compound.privateNotes` | 合并 |
| `Compound.sourceCode`, `sourceRow`, `contributedBy`, `verifiedAt`, `amapPoiId`, `totalBuildings`, `greeningRatio`, `parkingRatio`, `districtGroup`, `streetBlock` | CustomFieldDef(compound, source="migrated") | 转 customField |
| `Compound.availableUnits`, `areaSegments`, `priceSegments`, `landYears`, `finishType`, `deliveryTime`, `isNewHouse`, `buildYear`, `developer`, `propertyMgmt`, `propertyFeeCents` | 保 baseField | |
| `Compound.aliases` | 保 baseField | |
| `School.type` | `School.category` | EnumOption "school.category" 塞 {小学, 初中} |
| `School.tier` | `School.grade` | EnumOption "school.grade" 塞 {重点, 区重点, 普通} |
| `School.isJiunian`, `is12Year` | `School.form` (enum) | EnumOption "school.form" 塞 {普通, 九年一贯, 十二年制} |
| `School.zoneId` | `School.primaryAreaId` | 重命名 |
| `School.isMarketFive`, `isMarketKey` | CustomFieldDef(school, bool) | |
| `School.communitiesText`, `phone`, `address`, `motto`, `websiteUrl`, `foundedYear`, `capacity`, `notes` | 保 baseField | |
| `School.campuses`, `tuition`, `sourceCode`, `geocodeSource`, `geocodeConfidence`, `sourceUrl`, `lat`, `lon` | CustomFieldDef(school) 或保 (lat/lon 保 baseField) | |
| `School.sensitive*` | `School.privateNotes` | 合并 |
| `SchoolZone` | `Area` | 重命名 |
| `SchoolZone.middleSchoolPoolJSON` | Edges (Area→School, label="片内中学") | |
| `SchoolZone.residencyYears` | CustomFieldDef(area, int, unit="年") | 政策性, 砍 baseField |
| `SchoolZone.tier` | CustomFieldDef(area) | |
| `SchoolZone.structureJSON` | 砍 | 天津特定 |
| `SchoolZone.note`, `textDescription`, `strokeColorHex`, `fillOpacity`, `geometryStage`, `geometrySimplified` | 保 baseField | |
| `SchoolZone.sensitive*` | `Area.privateNotes` | 合并 |
| `CompoundSchoolMatch.primaryMatches` | Edges (Compound→School, label="对口小学", directed) | |
| `CompoundSchoolMatch.middleMatches` | Edges (Compound→School, label="片内中学", directed) | |
| `SchoolGroup.leadsJSON` | Edges (School→School, label="集团领办", directed) | |
| `SchoolGroup.membersJSON` | Edges (School→School, label="集团成员", directed=false) | |
| `AdmissionRate` | 砍（政策性） | 不迁 |
| `Policy` | 砍（政策性） | 不迁 |
| `SchoolScore` | 砍（政策性） | 不迁 |
| `AdmissionDoc` | `Document` 通用化 | 关联到对应 Area/School |
| `BuiltinTag` | `Tag` | 通用化 |
| 19 区（`district` 字符串） | 19 个 Area（category="行政区"，bbox 取自 `district_bboxes.json`） | 自动迁入 |
| `CameraPresets.seed`（硬编码 6 区） | `CameraPreset` @Model | 旧 seed 迁入 |
| `PinFilter`（硬编码 tiers/levels/jiunianVisible struct） | `FilterFieldConfig` 种子 (school: category/grade/form) + Layer | 等价能力由 FilterFieldConfig + Layer 替代 |

### 8.3 LegacyMigrator 流程

```
1. 扫描旧 store，收集所有非空字段
2. 创建 default Dataset "天津 demo"
3. 19 区 Area 入库 (category="行政区")
4. 复制旧 baseField 现存 baseField 直接 copy
5. per entityType：被砍 baseField 注册 CustomFieldDef (source="migrated", label 中文) + 数据写到 customFieldsJSON
6. 旧关联表 (CompoundSchoolMatch / SchoolGroup / Zone.middleSchoolPoolJSON / Compound.primarySchoolId) → Edges
7. sensitive 子结构 → privateNotes
8. 种 EnumOption (school.category / school.grade / school.form / edge.label / area.category 等默认值)
9. 种 FilterFieldConfig (compound: finishType, isNewHouse; school: category, grade, form; poi/area: category)
10. 种默认 Palette + 默认 Theme (字段总览 / 学区视图 / 商圈视图 / 新房地图)
11. 种默认 Layer ("全部" isDefault=true)
12. 旧 store rename .legacy.store，不删
13. 写新 store
```

### 8.4 迁移测试

- 旧 store → 新 store，count 校验（174 Compound / 823 School / 101 Area / 19 行政区 Area / N edges）
- Sample diff：取 10 个 Compound，对照旧字段 = 新字段（含 customFieldsJSON）
- Edge 双向查询：删一个 Compound，对应 Edge cascade
- Round-trip：export → wipe → import，数据一致

---

## 9. 测试策略

### 9.1 单元（Swift Testing）

- Entity CRUD（每 type）
- CustomFieldDef + customFieldsJSON 序列化/反序列化
- Edge 双向查询 + groupBy label
- StyleRule matcher（每个 op）
- StyleRule merge（priority + nil-skip）
- Palette stableHash（同 key 多次结果一致 / 跨进程一致 / FNV-1a 32-bit 边界）
- Theme 切换不丢 entity override
- Layer member 求值（static ∪ dynamic 去重）
- Layer zoom 阈值（边界值行为：等于 min/max 时显隐）
- FilterFieldConfig slot 唯一约束（同 (datasetId, entityType, slot) 拒重复）
- Filter chip self-exclusion（同 slot filter 不影响自身 count）
- LegendCounter 缓存签名（region/filter/layer 变化触发失效）
- Migration: 旧 → 新 count + sample diff
- Migration: 旧 PinFilter 写死字段 → FilterFieldConfig 等价种子
- Round-trip: export → import 一致

### 9.2 UI 快照

- 各 EntityEditor tab 默认状态
- Studio 编辑态布局（Mac/iPad）：含 Layers panel + Legend
- Studio 取景态布局
- Theme 切换前后 map 渲染 hash 稳定
- 详情卡 tab 切换高亮联动
- Layer 切换前后 entity 可见集合差异

### 9.3 集成

- 长按 → 创建 entity → 编辑保存 → `@Query` reflects
- POI 搜索创建走 MKLocalSearch
- Area polygon 绘制
- Area raster 4 角校准
- CloudKit 双设备并发（模拟）→ last-write-wins + 本地备份
- Wipe + reseed bundled demo
- Viewport count：拖动地图 → 200-300ms 内 chip count 刷新
- Layer zoom 触发：缩放跨阈值时 entity 集合自动隐显
- Filter chip + Layer 组合：AND 语义验证

### 9.4 可访问性

- VoiceOver labels on every form field
- 颜色对比度（pin glyph 在 fill 上）
- 字体动态调整（直播态大字号 copy）

---

## 10. 模型清单（17 @Model）

新增 (12)：
- `Dataset`、`POI`、`Edge`、`CustomFieldDef`、`EnumOption`、`FilterFieldConfig`、`Layer`、`StyleRule`、`Palette`、`Theme`、`Photo`、`CameraPreset`（后者替代硬编码 `CameraPresets.seed` enum，非旧 @Model）

重命名/重构 (3)：
- `Area`（← `SchoolZone`，字段大改）
- `Document`（← `AdmissionDoc`，泛化）
- `Tag`（← `BuiltinTag`，泛化）

原地重构 (2)：
- `Compound`、`School`（字段大改，rename `zoneId` → `primaryAreaId`，砍 sensitive/政策性字段）

纯删除 (5，无替代)：
- `CompoundSchoolMatch`、`SchoolGroup`、`AdmissionRate`、`Policy`、`SchoolScore`

**合计**：旧 10 个 @Model + `CameraPresets` enum + 硬编码 `PinFilter` struct → 新 **17 个 @Model**（删 5 + 重命名 3 + 原地重构 2 + 新增 12）。

非 @Model 保留：`AppSettings`（UserDefaults-backed `ObservableObject`）。

---

## 11. 命名 / 文件结构提议

```
PropertyAtlas/PropertyAtlas/
├── Models/
│   ├── Core/        Dataset.swift, Edge.swift, Tag.swift, CameraPreset.swift
│   ├── Entities/    Compound.swift, School.swift, POI.swift, Area.swift
│   ├── Style/       StyleRule.swift, Palette.swift, Theme.swift
│   ├── Display/     Layer.swift, FilterFieldConfig.swift
│   ├── Schema/      CustomFieldDef.swift, EnumOption.swift
│   ├── Media/       Photo.swift, Document.swift
│   └── Settings/    AppSettings.swift (保留)
├── DataKit/
│   ├── LegacyMigrator.swift
│   ├── SeedImporter.swift (改造为读 .tjmap.zip)
│   ├── DatasetService.swift
│   ├── EdgeQuery.swift
│   ├── StyleResolver.swift
│   ├── PaletteResolver.swift
│   ├── LayerResolver.swift          // member 求值 + zoom 触发
│   ├── FilterResolver.swift         // chip toggle 状态 + entity 过滤
│   ├── LegendCounter.swift          // viewport count, debounce, 缓存
│   └── ImportExportService.swift (.tjmap.zip)
├── MapRender/
│   ├── MapContainerView.swift (保留)
│   ├── MapKitView.swift
│   ├── AnnotationFactory.swift
│   ├── OverlayFactory.swift
│   └── PinView.swift (现 SchoolPinView 改名/泛化)
├── Studio/
│   ├── StudioRootView.swift
│   ├── TopToolbar.swift
│   ├── LeftDrawer/  LayersPanel, LegendPanel (viewport-aware), FilterChips, VisibilityToggles
│   ├── RightDrawer/ EntityCard, EntityEditor (per type variants)
│   ├── Settings/    DatasetsView, ThemesView, StyleRulesView, PalettesView, LayersView, EnumDictView, FieldDefsView (基本/Custom + 过滤字段 tab), CamerasView
│   └── LiveMode/    LiveOverlay, SpotlightController
├── Explore/         (iPad 浏览模式)
├── Onboarding/      OnboardingSheet, DatasetPicker
└── Resources/       BundledDemo (.tjmap.zip), StudioRasters
```

---

## 12. CLAUDE.md 更新点

提交此 spec 后，需更新 `CLAUDE.md`：

- 项目定位：移除"iPad-first 学区房研究"，改"iPad/Mac Catalyst 通用房产中介内容生产工具，含天津 demo dataset"
- 数据模型层级：`pub_*` / `usr_*` / `loc_*` 分层作废，统一私库 CloudKit
- 删 "Never use HSplitView" 保留
- 删 "中学不要建模成 single-school assignment" 由 Edge 系统替代
- 添加：14 模型清单、Edge 关系机制、StyleRule + Palette + Theme + Entity override 求值链、CustomFieldDef 注册表、`.tjmap.zip` 格式
- 添加监管规避原则：不在字段名/UI 文案中出现学区政策性术语
- `docs/claude/data-pipeline.md` 大改：5 源 → demo dataset 一次性产出，运行时不再依赖
- `docs/claude/studio-mode.md` 大改：Studio 为主模态（非辅助），编辑/取景两态

---

## 13. 未决 / 后续

- 高德 POI 搜索 SDK 是否引入（Apple MKLocalSearch 已能覆盖大陆主流地点，先用之）
- 直播态投屏方式：Mac 推荐通过 QuickTime/OBS 录屏；iPad 推荐 AirPlay 镜像到 Mac
- bundled `.tjmap.zip` demo 由迁移完成后导出生成，纳入 build 流水线
- Apple Pencil 绘 polygon 体验细化
- 多 dataset 大数据量（>10K entity）渲染性能 — 视实测加 cluster annotation

---

**End of design**
