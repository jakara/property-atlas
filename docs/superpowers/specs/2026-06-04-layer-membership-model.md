# 设计 spec:图层成员归属模型(单归属)

_日期:2026-06-04 · 状态:已与用户确认,待写实施计划_

## 背景与问题

当前图层引擎是「**类型白名单并集**」模型:

- 图层用 `staticRefsJSON` / `dynamicQueryJSON` 描述成员;两者皆空 → `LayerQuery.isMatchAll == true`。
- 种子图层【全部】正是空/空 → match-all → 显示所有实体。
- `LayerEvaluator` 规则:任一启用图层是 match-all → 返回全部;否则「未被任何启用图层覆盖的类型默认放行」。

由此产生两个用户痛点:

1. **新建图层 = 第二个【全部】**:新图层也空/空 → 也是 match-all → 强制显示全部实体,无法做成「空图层」。
2. 语义不直观:图层不真正「持有」实体,只是按类型放行。

## 目标

把图层改成**严格的单归属成员模型**:

- **每个实体恰好归属一个图层**(单归属)。
- 现有数据迁移进【默认】图层(原【全部】改名)。
- 新建图层默认**空**,只能手动把实体移进来。
- 实体可见 ⟺ 其所属图层「启用且在 zoom 范围内」(再 ∩ 现有过滤/染色)。

## 非目标(YAGNI)

- 不引入实体存储层公共基类(SwiftData 类继承风险大,另行立项)。沿用现有独立 `@Model` + `StyleEntity` 只读投影。
- 不做多归属。
- 不动过滤/图例/染色/出图等其它链路。
- `staticRefsJSON` / `dynamicQueryJSON` / `LayerQuery` 字段**保留**(避免 schema 翻动),仅停止用于成员判定。

## 数据模型

### 实体加 `layerId`

四个 `@Model` 各加一个可选字段(默认 nil):

```swift
var layerId: UUID?   // Compound / School / POI / Area
```

- `layerId == nil` → 运行时**回退到该 dataset 的【默认】图层**(兜底,旧数据/漏赋值不丢失、不变孤儿)。
- SwiftData 加可选属性属轻量迁移,无需手写迁移代码。

### 【默认】图层

- 种子图层【全部】**改名为「默认」**(`LegacyMigrator` 里),`isDefault = true`,**id 不变**。
- 不再依赖 `isMatchAll`;它只是「实体的家图层」。
- **`isDefault` 图层不可删**(UI 隐藏删除按钮)。

## 引擎重写(`MapRender/LayerEvaluator.swift`)

删掉 match-all 特判 + 「未覆盖类型默认放行」。改为按 `layerId` 归属:

- 新增入参:`defaultLayerId: UUID`(本 dataset 默认层 id,用于 nil 兜底)。
- 候选 `Candidate` 增加 `layerId: UUID?`。
- **可见判定**:
  ```
  let home = candidate.layerId ?? defaultLayerId
  visible ⟺ home ∈ {启用且在 zoom 范围内的图层 id}
  ```
- `membership(...)`:每个实体 → `[home 图层名]`(单元素;供 `MapDimension.layer` 投影 + 可见集 `layerNames` 继续工作)。
- 「未定义任何图层」与「全部禁用」:沿用上一轮修复语义——无图层定义时显示全部(不空屏);定义了但无启用 → 全隐藏。本模型下默认层恒存在,正常情况不触发。

`LayerQuery` 不再被 evaluator 调用(文件保留,标注停用)。

## 候选构建(`RootView.buildCandidates`)

`Cand` 结构增加 `layerId: UUID?`,从各实体读出;映射进 `LayerEvaluator.Candidate` 与 `VisibilityResolver` 路径。默认层 id 从 `layersForDataset(dsId)` 中 `isDefault` 那条取得,传入 evaluator。

## 迁移与兜底(`DataKit/LegacyMigrator.swift` + 启动)

1. **改名**:默认层 `name = "默认"`。
2. **种子赋值**:`run(seeds:in:)` 建完实体后,把该 dataset 全部实体 `layerId = defaultLayer.id`。
3. **旧库兜底 backfill**:启动流程(`SeedImporter.runIfNeeded` → 在 `cleanupOrphans` 邻位加一步)把 `layerId == nil` 的实体补设为本 dataset `isDefault` 图层 id。一次性、幂等。

## UI

### ① 实体编辑器(`Studio/Editor/EditorBasicTab.swift` 或新区块)

- 加「所属图层」下拉(`Picker`,tinted cool,深色玻璃风),列本 dataset 未删图层(`name`)。
- 绑 `layerId`;nil 显示为【默认】。改动即 `EntityWriter` 写入 `layerId` + `updatedAt` + `save()`。
- 经 `EntityReader.layerId(ref)` / `EntityWriter.setLayer(ref, layerId)` 统一读写(按 `EntityRef.kind` 分派四类型)。

### ② 长按新建(`RootView.createPin` / `showCreateMenu`)

- 现 `confirmationDialog` 仅选类型(+小区/+学校/+POI)。改为 **popup 选「实体类型 + 一个启用图层」**:
  - 列出**当前启用的图层**(`layerState.isEnabled` 为真者),用户选一个。
  - 0 个启用图层 → 落到【默认】。
  - 用所选 `layerId` 建 pin。
- 实现:`confirmationDialog` 无法放 Picker,改用小 `.popover` / `.sheet`(类型分段 + 图层列表 + 建立按钮),深色玻璃风。

### ③ 图层设置(`Studio/Settings/LayerSettingsTab.swift`)

- `isDefault` 图层:**隐藏删除按钮**。
- 删其它图层(已是硬删 + `save()`):删前把**该层成员批量 `layerId = 默认层.id`** + `save()`,避免孤儿。

## 边界

- 实体所属层被**禁用** → 实体隐藏(符合预期)。
- 实体所属层被**删** → 成员退回【默认】。
- **取消所有图层勾选** → 全隐藏(上一轮已修 `LayerEvaluator`:有图层定义但无启用 → 空集)。
- 实体 `layerId == nil`(旧库/异常) → 兜底归【默认】。

## 受影响文件清单

| 文件 | 改动 |
|---|---|
| `Models/Entities/{Compound,School,POI,Area}.swift` | 各加 `var layerId: UUID?` |
| `MapRender/LayerEvaluator.swift` | 重写为 layerId 归属判定 + `defaultLayerId` 入参 |
| `RootView.swift` | `Cand` 加 layerId;传 defaultLayerId;`createPin`/新建 popup 改造 |
| `DataKit/LegacyMigrator.swift` | 默认层改名;种子赋 layerId;backfill 步骤 |
| `States/SeedImporter.swift` | 调用 backfill(幂等) |
| `DataKit/EntityReader.swift` / `EntityWriter.swift` | `layerId(ref)` 读 / `setLayer(ref,id)` 写,按 kind 分派 |
| `Studio/Editor/EditorBasicTab.swift` | 「所属图层」下拉 |
| `Studio/Settings/LayerSettingsTab.swift` | 默认层禁删;删层前成员退回默认 |
| (可选)`MapRender/ConditionEvaluator.swift` | 若要把 layerId 进 `StyleEntity.baseFields` 供过滤,后续按需 |

## 验证

- 清库重迁(单启动):实体数不变(174/823/101…),默认层名为「默认」,全部实体 `layerId == 默认层 id`;地图显示全部。
- 新建图层:空,地图无变化;把某实体改到新图层 → 仅启用该层时只见该实体。
- 取消全部勾选 → 空屏;仅勾默认 → 全部回来。
- 删非默认层 → 其成员重新出现在默认层。
- Catalyst build 通过;SwiftLint 触及文件无新违规。
