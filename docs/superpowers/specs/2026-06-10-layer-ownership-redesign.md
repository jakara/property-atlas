# 图层显式归属 + DB-first 重设计 Spec

> 2026-06-10。承接「图层中心化重构 (2026-06-10)」。本次**部分反转**其「成员派生」决定:
> 成员资格从「entityType ∩ primaryFilter 实时派生」改为「`entity.layerId` 显式归属」。
> 同时移除启动 seed 导入,转为 DB-first。

## 背景与动机

图层中心化重构后,图层成员 = `entityType` 匹配 ∩ `primaryFilter` 命中(实时派生,无 `entity.layerId`)。
用户反馈两点不满:

- **A. 概念**:图层应是「往里放东西的桶」(显式归属),filter 派生成员像「保存的查询/视图」,不像图层。
- **B. 重叠**:同一实体可同时命中多个图层(OR 并集),一个实体出现在多层。不想要,要「一个实体恰属一个图层」。

## 核心模型

**图层 = 限定单一 `entityType` 的实体容器。**

- **成员(归属)** = `entity.layerId == layer.id`。显式、永久、无重叠。一个实体恰属一个图层。
- **`entityType`** 建层时定死,只能装该类型实体。
- **多图层同类型**:允许。同 entityType 的实体被**分区**进不同层(经赋值)。

### 显示管线(图层内,全实时,不改归属)

```
对每个启用图层 L:
  容器   = { e | e.entityType == L.entityType AND e.layerId == L.id }
  可显示 = 容器 ∩ L.primaryFilter 命中          (AND 条件,显示基线门)
  可见   = 可显示 ∩ ¬L.normalFilter 隐藏chip     (运行时交互缩小)
  对可见实体: groupBy 字段 → 调色板取一色 = 主 color
最终地图 = ⋃ 各启用图层的可见集 (OR);重叠时 zIndex 高者胜
```

**归属 ≠ 显示**:被 primaryFilter/normalFilter 藏掉的实体**仍属本层**(仍有 layerId),只是当前不画。

对比旧逻辑:**容器从「entityType ∩ primaryFilter」改为「entityType ∩ layerId」**;`primaryFilter`
从「成员选择器(跨全类型选成员)」降级为「容器内显示基线门」。`normalFilter` 角色不变(交互 chip)。

## §1 数据模型改动

**`Layer`**(`Models/Display/Layer.swift`,现有字段全保留):
- **加回 `isDefault: Bool = false`**(图层中心化重构时删过)。标记「该 entityType 的默认层」。
  每 entityType 恰一个 `isDefault=true`。默认层:不可删;删其他层时成员回落于此;新建实体落于此。

**4 实体**(`Compound`/`School`/`POI`/`Area`,`Models/Entities/`)各加:
- `layerId: UUID? = nil` —— 显式归属外键。
  - 可空**仅**为 SwiftData 轻量迁移加列方便(加 optional/defaulted 属性 = 安全轻量迁移)。
  - 迁移后业务上恒非空,由默认层不变式保证。

## §2 解析管线重写(`MapRender/LayerResolver.swift`)

当前 `resolve` 循环:`for layer in active where layer.entityType == type { guard layer.primary.matches(input) ... }`。

改动:`ActiveLayer` 的匹配条件加入 layerId 容器判定。候选实体需携 `layerId`:

- `Candidate` 或 `StyleEntity` 携带 `layerId: UUID?`。
- 循环内匹配条件:`layer.entityType == type AND candidate.layerId == layer.id`,**之后**再 `layer.primary.matches`(显示门)+ `isHidden`(chip)。
- 其余(zIndex 最高者胜、多层 OR 并集 = 结果 keys)不变。

即:`primaryFilter` 不再决定「是否在本层」,只决定「在本层内是否显示」。

## §3 赋值机制 + 默认层不变式

**默认层指定**(现有 6 层):
- 楼盘(compound)/ 学校(school)/ POI(poi):各仅一层 → `isDefault=true`。
- area 有 3 层(片区/行政区/路网)→ **片区 = area 默认**(承接兜底;新画 area 进片区)。

**赋值机制**(均写 `entity.layerId`):
1. **批量按条件**(图层设置内「按条件赋值」动作):选 `FilterCondition`(复用现有过滤机器)→ 预览命中数 →
   应用 → 命中实体 `layerId` 改为本层(**移动**语义,覆盖旧归属)。一次性快照,非实时。
2. **手动移动**:地图选中实体 → 「移到图层」→ 选目标(仅列同 entityType 的层)→ 写 layerId。
3. **新建实体**:地图绘制 → `layerId` = 该 entityType 的默认层。
4. **删图层**:
   - 非默认 + 有成员 → 成员 `layerId` 回落该 entityType 默认层。
   - 默认层 → 禁删(UI 删除按钮灰掉/隐藏)。

**不变式**:每实体恒有非空 `layerId`,指向同 entityType 的某存在图层。每 entityType 恒有一个 `isDefault` 层。

## §4 Bootstrap 改动 + 一次性迁移

### 启动移除(转 DB-first)

- 移除 `States/SeedProgressView.swift` 的 `SeedImporter.runIfNeeded` 调用(及其触发的整条 seed 路径)。
- 移除启动对 `LegacyMigrator` / `StyleConsolidationMigrator` / `LayerMigratorV3` 的调用。
- 启动 = 仅开库读数据。SwiftData 轻量迁移(加 `layerId`/`isDefault` 列)在 `ModelContainer` init 自动发生,**无需迁移码**。
- 6 层已在库,删调用不丢层。
- **保留在磁盘但断开**:bundled JSON + python 脚本,供将来「seed 导出 / 重导入」功能用。

### 一次性 `layerId` 迁移(手动跑一次,不进启动)

顺序(每步前已运行的 app 必须退出;改库前备份):
1. @Model 加 `layerId` + `Layer.isDefault` → build → **启动一次**(SwiftData 自动加 nil/false 列)→ 退出。
2. 备份库 → SQL 写 `layerId`:
   - `ZCOMPOUND.ZLAYERID` = 楼盘层 id
   - `ZSCHOOL.ZLAYERID` = 学校层 id
   - `ZPOI.ZLAYERID` = POI 层 id
   - `ZAREA.ZLAYERID`:`ZCATEGORY='道路'`→路网层;`ZCATEGORY='行政区'`→行政区层;其余→片区层
3. SQL 置 `ZLAYER.ZISDEFAULT=1` 于 楼盘/学校/POI/片区。
4. SQL **清空 6 层 primaryFilter**(`ZPRIMARYFILTERJSON` 置回 `{"conditions":[],"groupBy":null}`)。
   成员已由 layerId 编码;primaryFilter 归零 = 显示全部成员,留用户日后按需设显示门。`normalFiltersJSON`/chip 不动。

> SwiftData store 字段名为 Core Data 风格大写前缀(`Z<UPPER>`)。`UUID` 列存为字符串。
> 写 layerId 用对应图层的 `ZID`(UUID 字符串)。

### Stage B(图层中心化重构遗留,本次一并做)

删除生产已死的旧样式模型(被 `ViewEntityStyle`/`ViewStyleRule` 取代):
- 删 @Model:`StyleRule`、`Theme`、`Palette`(及其 `ModelSchema` 条目)。
- 删 `StyleConsolidationMigrator` + 其测试。
- 删随之死亡的类型(若仍存在且零生产引用):`StyleRuleMatcher`/`ConditionEvaluator` 等按编译错误清理。
- 后果:`ZSTYLERULE`/`ZTHEME`/`ZPALETTE` 表由轻量迁移移除(数据为 legacy seed,已被新模型取代,接受丢弃)。

## §5 UI 改动

- **图层设置 tab**(`Studio/Settings/LayerSettingsTab.swift` + `LayerConfigSections.swift`):
  - 加「按条件赋值」动作:`FilterCondition` 选择器 + 命中数预览 + 应用按钮 → 写 layerId。
  - `primaryFilter` 编辑器保留(语义改「显示门」,文案相应调整)。
  - 默认层显徽标 + 删除按钮灰掉/隐藏。
- **实体卡/编辑器**(`EntityCard`/`EntityEditor`):加「移到图层」选择(仅同 entityType 的层)。
- **抽屉/图例**:基本不动(逐层 toggle + 逐层图例,图层中心化已多层)。

## §6 验证(DB-first 单机,手动为主 + 单测)

**迁移后 SQL 核**:
- 每实体 `ZLAYERID` 非空(零 null)。
- 各层成员数:compound 174→楼盘;school 823→学校;area 按 category 22→路网 / 16→行政区 / 101→片区;poi 0。
- 4 默认层 `ZISDEFAULT=1`;其余 0。
- 6 层 `ZPRIMARYFILTERJSON` = 空条件。

**单测**:
- `LayerResolver` 改 layerId 容器逻辑后重写测试(成员 = layerId,primaryFilter = 显示门)。
- 删层成员回落默认层逻辑测试。
- 新建实体→默认层逻辑测试。

**运行验证**:多层 OR 渲染正常;按条件赋值生效(移动语义);删非默认层成员回落;默认层不可删;新画实体进默认层;Stage B 删模型后 build 绿、三表消失。

## 非目标(YAGNI)

- 多命名视图状态(每层只一套实时显示配置)。
- seed 导出/重导入(将来另立)。
- 启动迁移 runner(用户选「启动完全裸」;layerId 迁移手动一次性跑)。
- 逐实体-逐图层 theme 解析(早已延后)。
- CloudKit(Catalyst 保持 `.none`)。
