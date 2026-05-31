# 通用过滤 / 图例 / 染色 重设计 Design Spec

**状态**: 设计定稿(待拆 plan)
**日期**: 2026-05-31
**前置决策**:
- 决策1 = A:`primaryAreaId`(+ 残留 FK)→ `Edge`,删字段,关系模型统一走 Edge。
- 决策2 = B:暂不引 `MapEntity` 协议(`StyleEntity` 已是运行时统一缝)。

## 1. 动机

把"按维度过滤 + 图例 + 分类染色"从天津学区写死,升级成**通用、关系感知**的能力:任意实体按 layer / 类型 / 字段值 / **某类 edge 上下游实体的字段** 过滤、分组、着色。当前 `FilterFieldConfig`(仅实体字段)+ 全局 `Theme` 驱动一切的模型不够用。

## 2. 概念层级

```
Dataset
  └─ View (视图预设,可多个)          ← 全局视图配置容器(取代旧 Theme 的全局职责)
       ├─ enabledLayerIds + zOrder    ← 启用哪些 Layer,渲染叠放序
       ├─ PrimaryFilter               ← 组合谓词 + 可选 groupBy(决定分组+染色)
       ├─ NormalFilter[]              ← 仅 legend + 视口计数 + 可隐藏
       └─ paletteId                   ← 分组染色用的调色板
  └─ Layer (dataset 下、entity 上)     ← 固定过滤器 + zIndex + themeId
       └─ themeId → Theme             ← per-layer 基样式(含 base color)
  └─ MapEntity {Compound|School|POI|Area}
  └─ Edge (通用关系, n:n, label 枚举)
```

要点:
- **Theme 下沉到 Layer**:每 layer 挂一个 theme,管该层实体的**基样式含基色**(shape/icon/size/labelVisible/可见性/base color)。分类染色**移出** theme。
- **View 是新的全局容器**:一个 dataset 可存多个 View(如"学区视图"/"商圈视图"),取代旧 Theme 的"全局预设"角色。
- **PrimaryFilter 唯一**:每 View 一个,决定分组(染色)。**NormalFilter 多个**:仅 legend+计数+隐藏。

## 3. 维度抽象 `Dimension`(新,值类型 / JSON)

统一四种来源,filter 条件、groupBy、normal filter 都用它:

```
enum DimensionKind { layer, entityType, field, edgeField }

struct Dimension {
    kind: DimensionKind
    // kind == .field:
    fieldKey: String?          // 如 "grade"
    fieldSource: String?       // "base" | "custom"
    // kind == .edgeField:
    edgeLabel: String?         // 如 "所属片区"(edge.label 枚举值)
    edgeDirection: String?     // "downstream"(from→to) | "upstream"(to→from)
    edgeTargetField: String?   // 对端实体的字段,如 "name";nil=对端实体名
    // kind == layer / entityType: 无参
}
```

`Dimension.resolve(entity, context) -> [String]`(投影成该实体在此维度上的值,可多值 —— 一个实体可属多 layer、可有多条同 label edge):
- `.layer` → 实体所属 layer 名/ id 集
- `.entityType` → ["compound"|"school"|...]
- `.field` → `StyleEntity.field(fieldKey)` 字符串化
- `.edgeField` → 经 `EdgeStore` 查该 label+方向的对端实体,取 `edgeTargetField`(或对端名)

> **edgeField 依赖决策1 A** —— 关系统一走 Edge 后,"所属片区" 才是一条 edge,可被投影。

## 4. PrimaryFilter / NormalFilter

```
struct Condition { dimension: Dimension; op: Op; value: AnyJSON }   // 复用并泛化 StyleCondition
enum Op { equals, notEquals, in, contains, gte, lte, exists }

struct PrimaryFilter {
    conditions: [Condition]    // AND 组合:layer in() AND type in() AND field=... AND edgeField=...
    groupBy: Dimension?        // 可选
}

struct NormalFilter {
    name: String
    dimension: Dimension       // 该维度的值列表 → legend 行
}
```

**PrimaryFilter.groupBy 语义**:
- **有 groupBy**:该 dimension 在当前可见集里出现的所有值 = ① legend chip(可 toggle 隐藏)+ ② **染色分组**(每值一色)。
- **无 groupBy**:不分类染色 → 走 theme 基色(见 §5)。

**NormalFilter 语义**:每个 → 一组 legend 行(dimension 各值 + 视口计数),chip 可 toggle 隐藏对应实体。**不参与染色**。

## 5. 染色优先级(定稿)

对每个 entity,fill 色按此**从高到低**求值:

```
1. entity.override color (overrideStyleJSON.fillHex 已存在) ── 最高,直接覆盖
2. PrimaryFilter.groupBy 存在 → PaletteAssigner(该实体在 groupBy 维度的值) 取色
3. Layer 的 Theme base color (theme 基样式)
4. builtin 兜底
```

- **groupBy 全走 palette**,忽略 `EnumOption.colorHex`(决策:统一)。
- 非颜色样式(shape/glyph/size/labelVisible/stroke)仍由 theme + StyleRule 决定,不受 groupBy 影响。
- 一个实体在 groupBy 维度有多值时:取第一个(排序后)作染色键 [待 plan 期确认]。

## 6. PaletteAssigner(分组配色:hash + 同屏去重)

替代 `PaletteResolver` 的纯 hash%N。算法:

1. 收集**当前视口**内 groupBy 维度的 distinct 值集 `V`。
2. 每值先算 `seed = stableHash(值) % palette.count` 作首选槽。
3. 按值排序遍历,槽位冲突时**线性探测下一个空槽**(在 `V` 内去重),直到 `|V| > palette.count` 才允许复用。
4. (best-effort)相邻空间不同色:留待后续,先保证同屏去重。
5. 同值跨帧稳定:相同视口 distinct 集 → 相同分配(纯函数于 `V` + palette)。

**curated 高对比 palette**:复用删掉的 `ZoneColorPalette` 的 8 色(ColorBrewer Set1 改:红/蓝/绿/紫/橙/棕/粉/青,跳黄,白字可读),作为内置 `Palette`(builtIn)。

## 7. 可见集求值(过滤链)

```
可见(entity) =
    region 内
  ∧ entity ∈ ⋃(enabledLayers 的成员集)          // Layer 固定过滤(LayerEvaluator 现成)
  ∧ PrimaryFilter.conditions 全部命中
  ∧ ¬被任何 NormalFilter / PrimaryFilter.groupBy chip 隐藏   // FilterState 运行时态
```
渲染叠放按 Layer.zIndex(新)。

## 8. 对现有模型的增改

| 对象 | 现状 | 动作 |
|---|---|---|
| **View** | 无 | **新增 @Model** {datasetId, name, enabledLayerIds:[UUID], layerZOrderJSON, primaryFilterJSON, normalFiltersJSON, paletteId, cameraPresetId, bgMapStyle, drawEdgeLines:[String], copyTitle/Subtitle/Watermark, sortOrder, isActive, 版本/时间戳/deleted} |
| **Layer** | 有 colorHex/iconSF/staticRefs/dynamicQuery/sortOrder | **+ `zIndex:Int`**(渲染叠放)**+ `themeId:UUID?`**(layer→theme)。保留过滤职责 |
| **Theme** | 全局 active,管一切 | **下沉**:每 layer 一个,管基样式 + base color;`visibilityJSON`/`defaultEnabledLayerIds`/`drawEdgeLines`/`copy*` **移到 View**;分类染色移到 groupBy |
| **Dimension** | 无 | **新增**值类型(§3) |
| **PrimaryFilter / NormalFilter / Condition** | 无 | **新增**(JSON 存 View) |
| **FilterFieldConfig** | 仅实体字段 legend | **废弃**,职责并入 NormalFilter + PrimaryFilter.groupBy |
| **StyleCondition** | {field,op,value} | **泛化**为 {dimension,op,value}(或新 Condition 并存)|
| **PaletteResolver** | hash%N | **替换**为 PaletteAssigner(§6)|
| **LegendCounter** | 按 fieldKey 分组+计数 | **保留**,改吃 Dimension(primary + 各 normal)|
| **FilterState** | hidden:[fieldKey:Set] | **保留**,改按 filter 键 |
| **StyleResolver** | builtin→theme→rules→override | **插入** group-color 段(§5),theme 退为基色 |
| **EdgeStore** | relations/add/del | **+ 投影 helper**(给 Dimension.edgeField 用)|
| **primaryAreaId** | 3 pin 上 FK | **删**,迁成 `Edge(label="所属片区")`(决策1 A)|
| **edge.label 枚举** | EnumOption scope=edge.label 已有 | 复用;Settings 编辑(后续)|

## 9. 拆分为 plans(建议顺序)

1. **P6 — 关系统一**:`primaryAreaId`→`Edge(label="所属片区")` + 删字段;`EdgeStore` 投影 helper;`Dimension.edgeField` 投影 + 测试。(决策1 A 落地,体量小,独立可交付)
2. **P7 — Dimension + Filter 引擎**:`Dimension` 值类型 + `Condition`/`PrimaryFilter`/`NormalFilter` 模型 + 可见集求值 + `LegendCounter`/`FilterState` 改造。纯逻辑 + 测试,不动 UI。
3. **P8 — View 模型 + Theme 下沉 + 染色**:新增 `View` @Model;`Layer` + zIndex/themeId;`Theme` 下沉;`PaletteAssigner`(同屏去重 + curated palette);`StyleResolver` 插 group-color 段;渲染叠放接 zIndex。
4. **P9 — Settings 编辑 UI**:View / Layer / Theme / PrimaryFilter / NormalFilter / Dimension / EnumOption(含 edge.label)/ Palette 的编辑页 + CloudKit `.private` + 删 Legacy* @Model(原 P5 重型范围并入)。

> 每步产出可独立编译+测试的软件。P6 不依赖 P7/8;P7 的 edgeField 维度依赖 P6;P8 依赖 P7;P9 收尾。

## 10. 待 plan 期确认 / 延后
- groupBy 维度多值时的染色键选择(取排序首值?)。
- NormalFilter 是否需 AND 跨 filter(沿用 P4 的 AND 跨 slot 语义)。
- 相邻空间不同色(§6.4)best-effort,可延后。
- Layer.zIndex 与 area(polygon)/pin/edge-line 的统一叠放序细则。
- 多 View 切换的 UI(toolbar picker,类似旧 theme picker)。
- 旧 `FilterFieldConfig` 数据迁移到 NormalFilter(migrator 一次性)。
