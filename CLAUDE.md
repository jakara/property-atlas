# CLAUDE.md

Guidance for Claude Code (claude.ai/code) in this repo.

## Project

iPad-first iOS 17+ app for property research in Tianjin. Stack: SwiftUI · MapKit · SwiftData · CloudKit private DB. Mac Catalyst 出 Studio Mode (截屏工具).

## Key Documents (按需读, 不 auto-import)

- Design spec: `docs/superpowers/specs/2026-05-19-tianjin-house-design.md`
- Implementation plan: `docs/superpowers/plans/2026-05-20-tianjin-house-app.md`
- Studio spec: `docs/superpowers/specs/2026-05-26-studio-mode-design.md`
- Studio plan: `docs/superpowers/plans/2026-05-26-studio-mode.md`
- 新方向 spec (2026-05-28 重定位): `docs/superpowers/specs/2026-05-28-generic-map-tool-design.md`
- 实施计划 P1 (已完成): `docs/superpowers/plans/2026-05-28-p1-data-model-migration.md`
- 实施计划 P2 (已完成): `docs/superpowers/plans/2026-05-29-p2-style-engine-map-render.md`
- 实施计划 P3 (已完成): `docs/superpowers/plans/2026-05-31-p3-interaction-editing-core.md`
- 实施计划 P4 (已完成): `docs/superpowers/plans/2026-06-01-p4-legend-filter-layer.md`
- 实施计划 P5 (已完成): `docs/superpowers/plans/2026-05-31-p5-data-integrity-school-display.md`
- 通用过滤/图例/染色 重设计 spec: `docs/superpowers/specs/2026-05-31-generic-filter-legend-color-redesign.md`
- 实施计划 P6 (已完成): `docs/superpowers/plans/2026-05-31-p6-relation-unification.md`
- 实施计划 P7 (已完成): `docs/superpowers/plans/2026-05-31-p7-dimension-filter-engine.md`
- 实施计划 P8a (已完成): `docs/superpowers/plans/2026-06-01-p8a-view-model-palette-engine.md`
- 实施计划 P8b (已完成): `docs/superpowers/plans/2026-06-01-p8b-view-driven-integration.md`
- 实施计划 P9a (已完成): `docs/superpowers/plans/2026-06-01-p9a-settings-editing-ui.md`
- 实施计划 P9b (已完成): `docs/superpowers/plans/2026-06-01-p9b-delete-filterfieldconfig-legendswatch.md`
- 实施计划 P9c (已完成): `docs/superpowers/plans/2026-06-02-p9c-seed-pipeline-direct-write.md`
- 实施计划 P9d (已完成): `docs/superpowers/plans/2026-06-02-p9d-remaining-settings-editors.md`
- CloudKit: 延后 (iOS 上手后;Catalyst 现 `.none`)
- P9 余项: 逐实体-逐图层 theme 解析 (明确延后;单 active theme + StyleRule 已覆盖,等具体取景需求再做)

## 拆分文档 (`docs/claude/`) — 按需读

| 文件 | 内容 |
|---|---|
| `docs/claude/data-pipeline.md` | 5 源文档 → 7 JSON 输出, schema, sensitive 两级, scripts 表, 完整重建流水线, raw/private 目录策略 |
| `docs/claude/studio-mode.md` | Studio 架构约束, pin 三通道, legend filter, hot reload, DB 单一数据源, Mac Catalyst 构建 |
| `docs/claude/design-tokens.md` | accent/tier/status 颜色 |
| `docs/claude/swiftdata-store.md` | Mac Catalyst store 路径, DBeaver, sqlite3, 清空命令 |
| `docs/claude/skills-notes.md` | `add-school` 流程, Apple MKLocalSearch 经验 |

## Critical Architecture

### Layout — floating chrome, NOT rigid split

Map 全屏 (`ignoresSafeArea()`). Toolbar/drawer 浮在 `ZStack` 上, 不用 `HStack`:

```swift
ZStack {
    MapContainerView().ignoresSafeArea()        // z-index 0
    ToolbarView().zIndex(30)                    // top 40pt, inset 16pt H, h 52pt
    DrawerContainerView().zIndex(5)             // trailing 16pt, width = parent × 0.382 − 16pt
    WizardView().zIndex(12)                     // same frame as drawer
}
```

Never use `HSplitView` or `HStack` to divide map and drawer.

### Data model naming — three layers

| Prefix | Contents | Storage |
|--------|----------|---------|
| `pub_*` | School zones, compounds, schools (read-only seed) | SwiftData, no CloudKit |
| `usr_*` | User marks, visit records, custom zones, photos | SwiftData + CloudKit private DB |
| `loc_*` | App settings | SwiftData local only |

Never sync `pub_*` or `loc_*` to CloudKit.

> **P1 (2026-05-28) 完成后**: pub_/usr_/loc_ 分层作废. 全部新 @Model 走
> CloudKit private (Mac Catalyst 暂 .none, P5 切). 旧 pub_* 类已加
> `@available(*, deprecated)` 标记, 由 `LegacyMigrator` 一次性消化
> 到新 entity, P5 删除文件. usr_* 类 (PropertyMark/Visit/...) 当前
> 保留不动, 后续 plan 决定去留.

> **P2 (2026-05-29) 完成后**: Studio 渲染走 `MapRender/StyleResolver`
> (default → matching rules → entity override 三段求值). 旧
> `SchoolPinView` / `ZoneGeometryImporter` / `ZoneColorPalette` /
> `LegacyShim` 删除. Theme 切换由 `ThemeContext` 驱动. §5.7 Filter
> 视图内计数 + §5.8 Layer 留待 P4. `PinFilter` / `StudioLegend` /
> `SchoolDetailCard` + 极小 `LegacyStudioAccessors` shim 暂留, P4 重做后删.

> **P3 (2026-05-31) 完成后**: `AppState` 驱动 selection/editingMode/editTab。
> 点 pin → `EntityCard`(读) → `EntityEditor`(5 tab: 基本/关联/媒体/自定义/私密)。
> Edge 经 `EdgeStore` 双向查询 + 校验(自连/重复) + 级联软删；关联 tab 增删。
> 实体读写经 `EntityReader`/`EntityWriter`(按 `EntityRef`)，可编辑 baseField 由
> `EntityFieldSchema` 单一声明；override 样式经 `OverrideStyleCodec`。spotlight
> (`SpotlightResolver`) + drawEdgeLines(`EdgeLineFactory`) 已接。长按/右键建 Pin。
> 延后: POI 外部搜索 / Area 绘制+raster / PhotosPicker → P3.5；
> Settings / §5.7 Filter / §5.8 Layer → P4。

> **P4 (2026-06-01) 完成后**: 左抽屉回归 — 通用 Legend(`LegendCounter` 按
> type×field×value 分组 + viewport/全集双计数, swatch 由 `LegendSwatch` 经
> StyleResolver 求, chip toggle 走 `FilterState`/`FilterPredicate`, AND 跨 slot)
> + Layers(`LayerEvaluator` enabled×zoom×成员 → 可见 id 集, `LayerState` 运行时态,
> `Theme.defaultEnabledLayerIds` 初始化)。可见集 = visibility × Layer × Filter；
> area 也进 layer 候选集(否则 match-all 层会漏掉)。zoom 由 `ZoomLevel` 从 region 推。
> 天津专用 `PinFilter`/`StudioLegend`/`SchoolDetailCard` + `LegacyStudioAccessors` 删除。
> 延后: Settings 编辑页(Layer/FilterFieldConfig 编辑、新建) + CloudKit `.private`
> + 删 Legacy* @Model → P5。

> **P5 (2026-05-31) 完成后**: 数据正确性 + 学校显示修复。datasetId 改确定性
> (`LegacyMigrator.stableDatasetId` 从 name 派生 MD5,重跑复用同 id);
> `cleanupOrphans` 每次启动删 datasetId 无对应 Dataset 行的残留实体(13 类),
> `SeedImporter` 在迁移守卫前调用 + 早返回路径 `save()`；`StudioRootView` 所有实体
> 消费点(buildPins/buildAreaOverlays/layerCands/legendItems)按活跃 datasetId 过滤
> (修跨 dataset bleed)。学校 StyleRules seed(名称 labelVisible + grade→重/普 glyph +
> tier 配色)挂进"字段总览"/"学区视图" theme — 修学校无名字/无等级标识。
> 延后 P6: Settings 全编辑页 + CloudKit `.private` + 删 Legacy* @Model。

> **P6 (2026-05-31) 完成后**: 关系模型统一。`primaryAreaId` FK 删除(3 实体),
> 迁成 `Edge(label="所属片区")`(`LegacyMigrator.migratePrimaryArea`);edge.label
> 枚举加 "所属片区"。新增 `EdgeStore.relatedFieldValues(of:edgeLabel:direction:
> targetField:)` + `EdgeDirection` —— 关系投影原语,给 Dimension.edgeField 用
> (按 edge 上/下游实体字段过滤/分组/染色)。见重设计 spec。
> 后续 P7(Dimension+Filter 引擎)/ P8(View+Theme下沉+染色)/ P9(Settings+CloudKit+删Legacy*)。

> **P7 (2026-06-01) 完成后**: 通用维度过滤引擎(纯逻辑,与旧路径并存,未接 RootView)。
> `MapDimension`(layer/entityType/field/edgeField 四源 resolve;**注意命名** MapDimension
> 非 Dimension —— 避 Foundation.Dimension 撞名)+ `FilterCondition`(维度多值 op,
> Codable/Equatable 非 Hashable 因含 AnyJSON)+ `PrimaryFilter`(conditions AND +
> 可选 groupBy)+ `NormalFilter` + `DimensionFilterState`(按 MapDimension.key 隐藏值)
> + `VisibilityResolver`(layer ∩ primary ∩ ¬隐藏)+ `DimensionLegendCounter`(按任意
> 维度计数 viewport/total)。旧 `FilterFieldConfig`/`FilterPredicate`/`LegendCounter`
> 未动 → P8 接 RootView 时删。后续 P8(View 模型 + Theme 下沉 + PaletteAssigner + 接入 + 删旧)。

> **P8a (2026-06-01) 完成后**: 视图容器 + 调色引擎(additive,未接 RootView)。
> `MapView` @Model(spec 的 "View";命名避撞 SwiftUI.View;enabledLayerIds + primaryFilterJSON
> + normalFiltersJSON + paletteId + copy/camera)。`Layer` + zIndex(渲染叠放)+ themeId(layer→theme)。
> `PaletteAssigner.assign`(FNV-1a + 同屏线性探测去重 + 8 色高对比内置板 `highContrast`)。
> `StyleResolver.resolvePin` 加 `groupFillHex:String?=nil`(分类色覆盖 fill,在 rules 后/override 前;
> 优先级 builtin<theme<rules<groupFill<entity-override)。migrator seed 每 theme 一个 MapView
> (normalFilters 由 FilterFieldConfig 派生,primaryFilter 空 groupBy)+ defaultLayer zIndex/themeId。
> Theme 旧字段/FilterFieldConfig/RootView **未动** → P8b 切 View-driven + 删旧。

> **P8b (2026-06-01) 完成后**: 视图驱动集成 + 删旧。RootView/抽屉/工具栏切到
> `MapViewContext`(active MapView + 派生 active theme = 启用图层 zIndex 最高且有 themeId 者,回退
> dataset.activeThemeId)。可见集走 `VisibilityResolver`;图例走 `DimensionLegendCounter`(primary
> groupBy 彩色 chip[PaletteAssigner] + 每 NormalFilter 灰 chip #8E8E93 + 视口/总数);染色走
> `GroupColorResolver`→`resolvePin(groupFillHex:)`。`DimensionFilterState` 替 FilterState。新增
> `ValueFormat`(原 FilterPredicate.display/key)、`GroupColorResolver`、`MapViewContext`、
> `LayerEvaluator.membership`、`MapView.visibilityJSON`。**删** FilterState/FilterPredicate/旧 LegendCounter + 测试。
> **Theme 删 9 字段**(visibilityJSON/defaultEnabledLayerIds/drawEdgeLines/copy*/bgMapStyle/cameraPresetId/
> spotlightOnSelect)→ 移到 MapView;migrator 用 `ViewSeed` 直接写视图字面量。Theme 仅剩
> styleRuleIds/defaultStylesJSON/showLegend/name/sortOrder/isActive。schema 破坏 → 已清库重迁 smoke 验证。
> **务实单 active theme**(逐图层 theme 延后)。保留待 P9:FilterFieldConfig @Model、LegendSwatch。
> 后续 P9:Settings 编辑 UI + CloudKit .private + 删 Legacy*。

> **P9a (2026-06-01) 完成后**: Studio 内 Settings 编辑 UI(纯 additive,无 schema 变更)。
> 工具栏 ⚙️ → `SettingsSheet`(四 tab 分段:视图/图层/调色板/枚举)。`ViewSettingsTab` 编辑 active
> MapView 全字段 + `PrimaryFilterEditor`(groupBy + AND 条件,经 `DimensionPicker`)+ NormalFilters,
> 新建/切换/删视图;`LayerSettingsTab`(zIndex/themeId/色/zoom/启用 CRUD);`PaletteSettingsTab`
> (色数组 CRUD);`EnumOptionSettingsTab`(按 scope 增删值,含 edge.label)。新增纯逻辑(有单测):
> `ViewConfigCodec`(MapView filter JSON ⇄ 值)、`FieldKeyCatalog`(字段 base+custom / 枚举 / edge 标签源)、
> `ColorHexField.normalize`;组件 `DimensionPicker`/`FilterConditionRow`/`AnyJSONValueField`。
> `StyleConditionOp` 加 `Hashable`。配置改动直接 mutate + `updatedAt`,SwiftData 自动保存,软删 `deleted=true`。
> **延后 P9b/余项**:Theme/StyleRule/CameraPreset/CustomFieldDef 编辑器、CloudKit `.private`、删 Legacy*、
> 删 FilterFieldConfig/LegendSwatch、逐实体-逐图层 theme 解析。

> **P9b (2026-06-01) 完成后**: 删 `FilterFieldConfig` @Model(schema 移表)+ `LegendSwatch`(P8b 后零生产引用)。
> migrator `seedMapViews` 的 NormalFilter 改**硬编码 7 项**(原由 FilterFieldConfig 按 slot 派生,实测顺序对齐:
> 精装类型/阶段/POI 类型/区域类型/等级/新房二手/学制 —— 行为等价且现确定);删 `seedFilterFields` stage +
> `cleanupOrphans` purge + ModelSchema 条目 + FilterFieldConfig/LegendSwatch 测试。清库重迁 smoke 验丢表不崩 +
> normalFilters 仍 7 + 实体数不变。**CloudKit 延后**(iOS 未上手,Catalyst 保持 `.none`)、**Legacy* @Model 删除 +
> seed 管线重写(JSON→新实体直写)→ P9c**。Theme/StyleRule/Camera/Custom 编辑器、逐实体-逐图层 theme 仍延后。

> **P9c (2026-06-02) 完成后**: seed 管线直写 + 删 Legacy* @Model。Legacy* 及供给类(10 类)从
> @Model 降级为 `*Seed` Codable struct(`ZoneSeed`/`SchoolSeed`/`CompoundSeed`/`GroupSeed`/`MatchSeed`/
> `PolicySeed`/`AdmissionRateSeed`,在 `Models/Seeds/`,移出 ModelSchema)；死代码 `LegacyAdmissionDoc`/
> `BuiltinTag`/`SchoolScore` + `migrateAdmissionDocs`/`migrateTags` 两 stage 直接删。`GeoJSONHelper` 抽到
> `Models/Entities/GeoJSONHelper.swift`(Area/UserArea 依赖)。`SeedImporter` 用现有 dict 解析装 `SeedBundle`,
> `LegacyMigrator.run(in:)` → `run(seeds:in:)` 改读内存数组,转换逻辑不变;删 `needsImport` guard。
> **一次启动**即完成 seed+migrate(原两次)。清库重迁 smoke(单启动)验:Legacy 表全无、实体数不变
> (174/823/101)、ZMAPVIEW=4 各 7 normals、无 crash。CloudKit 仍延后(Catalyst `.none`)。后续 P9 余项:
> Theme/StyleRule/CameraPreset/CustomFieldDef 编辑器、逐实体-逐图层 theme 解析。

> **P9d (2026-06-02) 完成后**: Studio Settings 补齐四编辑器(纯 additive,无 schema 变更)。`SettingsSheet`
> 扩 8 段(+主题/样式/相机/字段)。`CameraSettingsTab`(机位 CRUD,pitch/heading 经 `CameraFieldClamp`)、
> `CustomFieldSettingsTab`(按 entityType 分组,key 持久后只读)、`ThemeSettingsTab`(styleRuleIds 多选 +
> defaultStylesJSON 原文校验)、`StyleRuleSettingsTab`(entityType + applies* 全字段 + 条件经 `StyleConditionRow`)。
> 新纯逻辑(有单测):`StyleConditionCodec`(conditionsJSON ⇄ [StyleCondition])、`CameraFieldClamp`
> (pitch 0–85 / heading 0–360)。组件 `StyleConditionRow`。改动直接 mutate + `updatedAt`,软删 `deleted=true`。
> **逐实体-逐图层 theme 明确延后**(单 active theme + StyleRule 已覆盖)。CloudKit 仍延后(Catalyst `.none`)。

> **Studio 地图性能优化 (2026-06-05)**: 拖/缩卡顿根因 = `regionDidChange` 高频触发 → `StudioRootView.body`
> 整条重算(`styleEntity`×全实体 + 可见性×2 + 图例 N 维×全集 + 染色)+ `updateUIView` 每帧全量拆建
> annotation。五处修复(纯 Catalyst 渲染路径,无 schema/行为变更):①`MapKitView` region 写回 debounce 0.12s
> (连续触发塌缩成 1 次,期间不更新 `lastAppliedCamera` 防覆盖用户拖动);②`updateUIView` 用 annotation 内容
> 签名(`Coordinator.annotationSignature`:id/坐标/PinStyle/dim/highlight)比对,未变跳过 `removeAll+addAll`;
> ③`PinAnnotationView` shapeLayer 设 `shadowPath`(阴影从每帧离屏渲染→O(1));④`RootView` **内容签名缓存**
> (`StudioRenderCache` 存 pins/overlays/styleMap/`LegendSpec`;签名含 dataset/可见类型/过滤 JSON/调色板/
> 主题+规则+图层 updatedAt/chip 隐藏/启用图层/选中/各实体 count+maxUpdatedAt,**不含 visibleRegion**;
> 经 `MapEntityVersioning` 协议读版本)→ pan/zoom 停手只走 `renderLegendSections`(`DimensionLegendCounter.
> rowsFromEntries` 预解析 entries + bbox 计数,无 styleEntity/resolve);⑤zoom 仅当有图层设 `minZoom/maxZoom`
> 才计入签名(默认图层无限制→缩放零重建);⑥`PinAnnotationView` 标签受 zoom 门控(`labelMinZoom=13`,
> Coordinator region settle 跨阈值才刷新可见 view,不重建 annotation)。**异步**:SwiftData `@Model`/
> `ModelContext` 是 `@MainActor`+非 Sendable,密集渲染卡在 MapKit 主线程/GPU,异步治不了 → 未做。

> **Studio 视口裁剪 (2026-06-05)**: 开/关默认图层卡 = `cache.pins`(全量 resolve 结果)整批交给
> MapKit,`PinAnnotationView.displayPriority=.required` 不去重 → 全城几百 pin 全量渲染。修:`RootView.
> viewportPins(_:region:)` 在交付前按 `visibleRegion` 外扩 0.5×span margin 各方向做 bbox 过滤,只交视口
> 子集给 MapKit。全量 resolve 仍缓存(pan 不 re-resolve);该过滤每 body 跑(O(N) 廉价,同图例计数)。
> region=nil(首帧)→ 全留。pan settle(debounce 0.12s)重裁,margin 掩边缘弹出。

> **Studio rebuild 提速 11.7× (2026-06-05)**: os.Logger 埋点实测开图层 rebuildContent=821ms,三杀手
> visibility=400/groupColors=194/legendSpecs=196,根因 = **edgeField 维度 resolve 每实体一次
> `EdgeStore.relatedFieldValues`(`FetchDescriptor<Edge>` fetch + per-edge 实体 fetch)**,且同维度同实体被
> visibility(×2)/groupColors/legend 重复调 ~4× ×823 ≈ 3300 次 DB fetch。修:①`StyleResolver.parseDefaults`
> 把 theme defaultStylesJSON 解析从 per-pin 提到一次(buildPins 传 `themeDefaults`);②`MapDimension.Input`
> 注入 `EdgeProjection`(一次 Edge fetch + 全实体 `entityById` 内存查表,取代 per-entity DB)+ `DimResolveCache`
> (引用类型 per-rebuild 跨 stage 共享,同 dimKey#entityId 只算一次);③`buildEntityIndex` 全实体 styleEntity
> 只 decode 一次,`buildCandidates`/`buildEdgeProjection` 共用(去重复 JSON decode)。结果 ON 821→70ms
> (visibility 5.5/group 2.8/legend 2.5/entityIndex 15/edgeIndex 18/buildPins 21)。**pan/zoom 不进 rebuildContent**
> (签名不含 region),其顺滑来自上面的视口裁剪,与本次无关。旧 `EdgeStore.relatedFieldValues` DB 路径保留作
> 测试/无投影回退。

### School district logic

- **小学** (primary): one compound → one school (`Compound.primarySchoolId`)
- **初中** (middle): one zone → lottery pool of schools (`Compound.zoneId` + `School.zoneId`)

不要把 初中 建模成 single-school assignment.

### Seed pipeline

Public data **bundled offline** (不运行时 fetch). 5 源 → Python scripts → JSON → bundle → `SeedImporter` 首启动跑. 详情见 `docs/claude/data-pipeline.md`.

### CloudKit constraints

- Private database only (`ModelConfiguration(cloudKitDatabase: .private(...))`)
- All `@Model` properties need default values or `?` optional
- Photo compression: 1280px max, HEIC format, quality 0.8
- Mac Catalyst 下不开 CloudKit

## Code Standards

- **SwiftLint** required — `swiftlint lint` before committing
- Max file size: 300 lines
- Swift Testing framework (not XCTest) for unit tests
- iOS 17+ minimum — `Map(position:)`, not deprecated `Map(coordinateRegion:)`

## CI

- iOS: Xcode Cloud (ADP included)
- Android / backend (future): GitHub Actions
