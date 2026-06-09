# 图层中心化视图重设计 (Layer-Centric View Redesign)

> Status: 设计已确认，待写实施计划。
> 取代「视图聚合多图层 + 单 active 视图」旧模型。

## 目标 (Goal)

把「视图」与「图层」合并为单一概念 `Layer`：一个图层固定一种实体类型，1:1 持有自己的过滤/样式/染色配置；可同时启用多个图层叠加展示（图层间 OR），图层内过滤器 AND。

## 背景 / 旧模型问题

当前（`feat/view-owned-style` 分支）：

- `MapView` 通过 `enabledLayerIds` 聚合**多个** `Layer`；`Layer` 可混装多种实体类型。
- 同一时刻只有**一个** `MapView` active（`isActive` 单选，互斥）。
- `MapView` 还承载相机/底图/导出文案/水印等全局展示设置。
- `ViewEntityStyle` 每视图 ×4 实体类型；`ViewStyleRule` 每视图 × entityType。
- 实体经 `entity.layerId` 显式归属图层；`LayerEvaluator` 按 enabled×zoom×成员算可见集。

问题：视图/图层两概念职责重叠且耦合；单 active 视图无法叠加展示不同维度；图层混类型导致过滤/样式语义复杂。

## 确认的设计决策

| 决策点 | 结论 |
|---|---|
| View↔Layer 关系 | 1:1，**合并为单一 @Model**（SwiftData 无 join、无孤儿、迁移一张表） |
| 存活类型名 | 保留 `Layer`，吸收 `MapView`，全局改名 `MapView`→`Layer`（~117 处，机械） |
| 图层成员 | `entityType`（创建时定死）+ 图层 AND 过滤器**派生**；删 `entity.layerId` |
| 一种类型多图层 | 允许（`路网`/`行政区` 都是 area，不同过滤） |
| 多图层关系 | 启用集并集 OR；图层内过滤 AND |
| 哪些图层激活 | `Layer.enabled` 集合（取代 `isActive` 单选） |
| 全局展示设置 | 相机/底图/导出文案/水印/画幅 上提到 `Dataset` 级 |
| 迁移策略 | **保实体（含道路 styleFillHex），删重建配置**（图层/样式表） |

## §1 — 核心模型

### 1.1 `Layer` @Model（唯一存活，吸收 MapView）

```
Layer
  id: UUID
  datasetId: UUID
  name: String
  iconSF: String?
  colorHex: String?
  entityType: String          // 创建时定死: compound | school | poi | area
  enabled: Bool               // 是否同屏展示（取代 MapView.isActive 单选）
  zIndex: Int                 // 跨图层渲染叠放
  sortOrder: Int
  minZoom: Double?
  maxZoom: Double?
  filtersJSON: String         // [FilterCondition] 扁平 AND 数组
  groupByJSON: String?        // 可选 MapDimension（分组染色维度）
  paletteHex: [String]        // 分组染色色板（空→PaletteAssigner.highContrast）
  showLegend: Bool
  hiddenChipsJSON: String     // 图例 chip 隐藏态（DimensionFilterState 快照）
  deleted: Bool
  version: Int
  createdAt / updatedAt
```

**删除/废弃字段：**
- `MapView` @Model 整体（字段并入 `Layer`）
- `MapView.enabledLayerIds`（图层不再聚合多层）
- `MapView.visibilityJSON`（单一类型，无需 per-type 开关）
- `MapView.isActive`（→ `Layer.enabled`）
- `entity.layerId`（4 个实体类，成员改派生）
- `Layer.themeId`（旧；样式已视图持有，见 §3）
- `PrimaryFilter.entityType` / `NormalFilter.entityType`（类型由图层定，冗余）

### 1.2 样式表改键 `viewId` → `layerId`

- `ViewEntityStyle`：每 `Layer` **一行**（单一类型，不再 ×4）。
- `ViewStyleRule` + `ViewStyleCondition`：每 `Layer`（其单一类型的规则）。

### 1.3 `Dataset`（+全局展示字段）

```
Dataset (新增/吸收)
  cameraPresetId: UUID?  （及现有相机相关字段）
  bgMapStyle / studioMapStyleRaw: String
  copyTitle / copySubtitle / copyWatermark: String?
  watermarkQRData: Data?
  canvasAspectRaw: String
  poiEnabled: Bool / poiCategoriesRaw: String
  spotlightOnSelect: Bool
```

## §2 — 成员与过滤

### 2.1 可见集语义

```
visibleIds = ⋃ over Layer where enabled && !deleted && zoom ∈ [minZoom, maxZoom]:
               { e | e.type == layer.entityType
                     && ALL(c in layer.filters) c.evaluate(e) }   // AND
```

- 实体无 `layerId`，成员**纯派生**：类型匹配 + AND 过滤全过。
- `路网` = `area` + `category=道路`；`行政区` = `area` + `category=行政区`。同 area 池不同过滤，可同屏。
- 跨图层 **OR**（并集）；同一实体被多图层命中 → **渲染一次**，样式取 **zIndex 最高** 的命中图层。

### 2.2 `VisibilityResolver` 重写

```swift
static func resolve(
    entities: [StyleEntity],        // 全部候选（按 dataset）
    layers: [Layer],                // enabled && !deleted
    zoom: Double,
    edgeProjection: EdgeProjection?,
    cache: DimResolveCache?
) -> [UUID: UUID]                   // entityId → 命中图层 id（zIndex 最高）
```

返回 entity→layer **映射**（非纯 Set），因渲染需知每实体归哪图层取样式/染色/图例计数。

### 2.3 复用

- `MapDimension`（kind: layer/entityType/field/edgeField）、`FilterCondition`（op: equals/notEquals/in/contains/exists/gte/lte）、`EdgeProjection` 投影逻辑不变。
- `filtersJSON = [FilterCondition]` 纯 AND 数组；`groupByJSON` = 可选 `MapDimension`。
- `LayerEvaluator`（旧 enabled×zoom×成员）逻辑并入 `VisibilityResolver.resolve`；旧 `entity.layerId` 成员判定删除。

## §3 — 样式 / 图例 / UI

### 3.1 样式求值链（简化）

图层=单一类型，`ViewEntityStyle` 每图层一行。链不变：

```
builtin → ViewEntityStyle(图层默认) → ViewStyleRule(命中, priority 升序合并)
        → 分组染色 groupFillHex → 实体 override（最高优先级）
```

- `StyleResolver.resolvePin/resolveArea` 签名不变，改按 `layerId` 取预取的 default style + rules。
- **道路染色保留**：`entity.styleFillHex` 是实体 override，位于链末端最高优先级，路网图层默认样式不覆盖它 → 颜色仍在。

### 3.2 分组染色

- 每图层独立 `groupBy` + `paletteHex`。
- `GroupColorResolver` 在**图层内**对该 dimension 取值分组配色；多图层各染各。

### 3.3 图例（多图层分段）

- 左抽屉每个**启用图层一段**（section）。
- 段内：`groupBy` 彩色 chip（`PaletteAssigner`）+ 各 NormalFilter 灰 chip + 视口/总数计数。
- 无 `groupBy` → 单 swatch 行（图层默认色）。
- `DimensionLegendCounter` 按图层（layerId 映射）计数。
- **要求：左抽屉支持多图层 toggle 同屏 + 同时显示多个图层的图例段。**

### 3.4 左抽屉（`LeftDrawerView` / `LayersView`）

- 图层清单，每行 `enabled` toggle（**多选**，取代 `StudioToolbar` 视图单选 Menu）+ 该图层图例段。
- 删 `StudioToolbar` 的视图单选 Menu。

### 3.5 设置页（`SettingsSheet`）

- **图层 tab** = 图层 CRUD。新建时**先选 entityType**（之后定死、只读）。选中图层后所有子设置（过滤/样式/染色/zoom/zIndex/调色板/图例开关）围绕其类型。
- 旧「视图 tab」并入图层 tab（1:1 合并）。
- 相机/底图/导出文案/水印/画幅 → 移到 **dataset 级展示设置**（新「展示 tab」或并入现有）。
- 枚举 / 字段 tab 不动。

### 3.6 渲染叠放

- `buildAreaOverlays` / pin 按 `layer.zIndex` 统一驱动叠放；去掉硬编码颜色优先级（`roadDrawPriority` 之类）——叠放改由命中图层 zIndex 决定。

## §4 — 迁移 / Seed / 测试

### 4.1 迁移（保实体，删重建配置）

启动幂等迁移器（扩 `StyleConsolidationMigrator` 或新增 `LayerModelMigrator`），新闸 `Dataset.layerModelV3: Bool`：

```
1. 删旧配置：旧 MapView 行、旧 ViewEntityStyle(×4)/ViewStyleRule、旧 Layer 行
2. seed 新 Layer 默认集（每 dataset）：
     楼盘    entityType=compound  enabled=true
     学校    entityType=school    enabled=true
     POI     entityType=poi       enabled=false
     行政区   entityType=area  filter[category=行政区]  enabled=true
     路网    entityType=area  filter[category=道路]    enabled=true
   每 Layer 配 ViewEntityStyle 一行 + 默认 paletteHex + zIndex
3. 全局展示字段从旧首个 view 搬到 Dataset（camera/bg/copy/watermark/aspect/...）
4. 置 layerModelV3 = true
```

- schema 破坏字段（`entity.layerId`、`Layer.themeId`、旧 `MapView`）→ 清库重迁验证。
- 实体保留：道路 `styleFillHex` 等 override 不动。

### 4.2 测试（Swift Testing）

- `VisibilityResolver.resolve`：单类型过滤、多图层 OR 并集去重、zIndex 取胜映射、zoom 边界。
- `Layer.filtersJSON` / `groupByJSON` codec round-trip（AND 条件 + 维度）。
- 迁移器幂等（二次启动不重复 seed）。
- `GroupColorResolver` 按图层独立染色。
- `DimensionLegendCounter` 多图层分段计数。

### 4.3 文件结构（改名为主）

- 全局 `MapView`→`Layer`、`viewId`→`layerId`、`mapView`→`layer`（~117 处 / 19 文件，机械）。
- `Models/Display/MapView.swift` 内容并入 `Models/Display/Layer.swift`（合并后控制在 300 行内）。
- `MapRender/MapViewContext.swift` → `LayerContext`（持多 enabled 图层集，无单 active）。
- 删 `Models/Display/Layer.swift` 旧定义、`MapView` @Model、`LayerEvaluator`（逻辑并入 resolver）。

### 4.4 清库重迁验证标准

- 实体数不变（compound/school 175/823 等）。
- `Layer` 行 = 5（楼盘/学校/POI/行政区/路网）。
- `ViewEntityStyle` 行 = 5（每图层一行）。
- 二次启动幂等，不重复 seed。
- 道路保持染色（实体 override 生效）。
- 多图层 toggle 同屏 + 多段图例正确。

## 非目标 (YAGNI)

- 不做多 Scene/构图预设（展示设置先单例上提 dataset）。
- 不做逐实体显式图层指派（成员纯派生）。
- 不动 CloudKit（仍延后，Catalyst `.none`）。
- 不做实体类型扩展（仍 4 类）。
