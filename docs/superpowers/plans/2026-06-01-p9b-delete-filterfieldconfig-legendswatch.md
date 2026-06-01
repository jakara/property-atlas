# P9b 删 FilterFieldConfig + LegendSwatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** 删除 P8b 后已无用的 `FilterFieldConfig` @Model 与 `LegendSwatch` 工具:把 migrator 派生 NormalFilter 的来源从"读 FilterFieldConfig"改成**硬编码同一份列表**(行为不变),删两个文件 + ModelSchema 条目 + 相关 seed/cleanup/测试。

**Architecture (定稿):**
- `FilterFieldConfig` 自 P8b 起仅剩两处用途:① migrator `seedFilterFields` 建它;② `seedMapViews` 读它派生每视图的 NormalFilter JSON。删它 → `seedMapViews` 改用**硬编码 NormalFilter 列表**(与现 seed 完全等价的 7 项),删 `seedFilterFields` stage + `cleanupOrphans` 里的 purge + ModelSchema 条目。
- `LegendSwatch` 自 P8b 起**生产代码零引用**(仅测试),删文件 + 测试。
- **schema 破坏**(移除 FilterFieldConfig 表)→ SwiftData 轻量迁移丢表 → **清库重迁 smoke**(Catalyst,无 CloudKit)验证:迁移不崩 + MapView.normalFilters 仍 7 项 + 实体数不变。
- **CloudKit 不在本期**(延后,见 memory cloudkit-deferred)。**Legacy* @Model 不在本期**(其删除=seed 管线重写 → P9c)。

**Tech Stack:** SwiftData · Swift Testing · 复用 `NormalFilter`/`MapDimension`/`JSONHelpers`。

**前置**: P9a 已合(main @ 9c0eb42)。

**关键现状(已核实,行号以实现期实读为准):**
- `DataKit/ModelSchema.swift` `allTypes`:含 `... Layer.self, FilterFieldConfig.self, MapView.self, ...`。CloudKit 配置 `#if targetEnvironment(macCatalyst)` → `.none`;else `.private(...)`。**本期不动 CloudKit 配置**。
- `DataKit/LegacyMigrator.swift`:
  - `cleanupOrphans(in:)` 含 `purge(FilterFieldConfig.self) { $0.datasetId }`。
  - stage `seedFilterFields(dataset:in:)`(硬编码 7 项 → 建 FilterFieldConfig)+ 在 `run` 里被调用。
  - `seedMapViews(...)` 内:
    ```swift
    let cfgs = try ctx.fetch(FetchDescriptor<FilterFieldConfig>())
        .filter { $0.datasetId == dsId && !$0.deleted }
        .sorted { $0.slot < $1.slot }
    let normals: [NormalFilter] = cfgs.map {
        NormalFilter(name: $0.label, dimension: MapDimension(kind: .field, fieldKey: $0.fieldKey, fieldSource: $0.fieldSource))
    }
    let normalsJSON = (try? JSONHelpers.encode(normals)) ?? "[]"
    ```
  - `seedFilterFields` 的硬编码 seed(顺序即派生 normals 顺序):
    | entityType | fieldKey | label | source | slot |
    |---|---|---|---|---|
    | compound | finishType | 精装类型 | base | 1 |
    | compound | isNewHouse | 新房/二手 | base | 2 |
    | school | category | 阶段 | base | 1 |
    | school | grade | 等级 | base | 2 |
    | school | form | 学制 | base | 3 |
    | poi | category | POI 类型 | base | 1 |
    | area | category | 区域类型 | base | 1 |
    > 注:旧 `seedMapViews` 按 `slot` 排序后 map。跨 entityType 的 slot 会交叉(各 entity 各自 1..n)。**为保持与现 seed 字节级等价**,实现期需先读真实 `seedFilterFields` + `seedMapViews`,确认旧 normals 的**实际顺序**(按 slot 排序会把 4 个 slot=1 排前),并让硬编码列表产出**相同顺序**。最稳妥:实现期跑一次现 migrator,dump 现 `normalFiltersJSON`,让硬编码版输出同序(见 T0 Step 1 验证)。
- `Models/Display/FilterFieldConfig.swift`、`MapRender/LegendSwatch.swift` 待删。
- 测试:`PropertyAtlasTests/Models/FilterFieldConfigTests.swift`、`PropertyAtlasTests/MapRender/LegendSwatchTests.swift`(整删);`PropertyAtlasTests/DataKit/LegacyMigratorTests.swift` 的 `migrateSeedsDefaultFilterFieldConfigs()`(删)+ `seedsMapViewsWithDefaults()`(改:断言 normals 数 = 硬编码常量,不再 fetch FilterFieldConfig)。

> 所有 `xcodebuild` 从 worktree `PropertyAtlas` 子目录运行。Swift Testing。提交 `git -c commit.gpgsign=false commit -am`。SourceKit 诊断陈旧噪声,以 `xcodebuild` 为准。

---

### Task 0: 删 FilterFieldConfig + 硬编码 normals

**Files:** Modify `DataKit/LegacyMigrator.swift`、`DataKit/ModelSchema.swift`; Delete `Models/Display/FilterFieldConfig.swift`、`PropertyAtlasTests/Models/FilterFieldConfigTests.swift`; Modify `PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 0: 读现状 + 记录现 normals 顺序**
读 `LegacyMigrator.swift` 的 `seedFilterFields`、`seedMapViews`、`cleanupOrphans`、`run`。确认 `seedMapViews` 当前如何排序/映射 FilterFieldConfig → normals。在内存 in-memory 测试里(或临时打印)记下现 `seedsMapViewsWithDefaults` 产生的 `normalFiltersJSON` 的 name 顺序,作为硬编码目标顺序。

- [ ] **Step 1: 写/改测试(先红)**
改 `LegacyMigratorTests`:
1. 删除 `migrateSeedsDefaultFilterFieldConfigs()` 整个测试。
2. 改 `seedsMapViewsWithDefaults()`:把
   ```swift
   let cfgCount = try ctx.fetch(FetchDescriptor<FilterFieldConfig>())
       .filter { $0.datasetId == v.datasetId && !$0.deleted }.count
   let nfData = Data(v.normalFiltersJSON.utf8)
   let nfs = (try? JSONDecoder().decode([NormalFilter].self, from: nfData)) ?? []
   #expect(nfs.count == cfgCount)
   ```
   改成:
   ```swift
   let nfData = Data(v.normalFiltersJSON.utf8)
   let nfs = (try? JSONDecoder().decode([NormalFilter].self, from: nfData)) ?? []
   #expect(nfs.count == 7)   // 硬编码 7 项(compound2+school3+poi1+area1)
   #expect(nfs.contains { $0.name == "精装类型" })
   #expect(nfs.contains { $0.name == "等级" })
   ```
   删该测试里任何 `FilterFieldConfig` 引用。
3. 删 `PropertyAtlasTests/Models/FilterFieldConfigTests.swift` 整文件。

- [ ] **Step 2: 跑确认失败**(编译失败/断言失败均可)
`cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/LegacyMigratorTests 2>&1 | tail -30`

- [ ] **Step 3: 实现**
1. `seedMapViews` 内,替换 FilterFieldConfig fetch+map 为硬编码(顺序对齐 Step 0 记录的现序;下列按"4 个 slot=1 在前、再 slot=2、再 slot=3"还是"按 entity 分组"以 Step 0 实测为准):
   ```swift
   let normals: [NormalFilter] = [
       NormalFilter(name: "精装类型", dimension: MapDimension(kind: .field, fieldKey: "finishType", fieldSource: "base")),
       NormalFilter(name: "新房/二手", dimension: MapDimension(kind: .field, fieldKey: "isNewHouse", fieldSource: "base")),
       NormalFilter(name: "阶段", dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base")),
       NormalFilter(name: "等级", dimension: MapDimension(kind: .field, fieldKey: "grade", fieldSource: "base")),
       NormalFilter(name: "学制", dimension: MapDimension(kind: .field, fieldKey: "form", fieldSource: "base")),
       NormalFilter(name: "POI 类型", dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base")),
       NormalFilter(name: "区域类型", dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base")),
   ]
   let normalsJSON = (try? JSONHelpers.encode(normals)) ?? "[]"
   ```
   (若现序是 slot 交叉,把列表重排成与现 dump 一致;normals 数与内容必须等价。)
2. 删 `seedFilterFields(dataset:in:)` 函数 + `run` 里对它的调用。
3. `cleanupOrphans` 删 `purge(FilterFieldConfig.self) { $0.datasetId }` 行。
4. `ModelSchema.swift` `allTypes` 删 `FilterFieldConfig.self,`。
5. 删 `Models/Display/FilterFieldConfig.swift` 文件。

- [ ] **Step 4: 跑确认通过 + 全量 LegacyMigratorTests**
`... -only-testing:PropertyAtlasTests/LegacyMigratorTests 2>&1 | tail -30` → 全过(少了 1 个删掉的测试)。
grep 确认无残留:`cd <worktree> && grep -rn "FilterFieldConfig" PropertyAtlas/PropertyAtlas PropertyAtlas/PropertyAtlasTests` → 空。

- [ ] **Step 5: 提交** `git add -A && git -c commit.gpgsign=false commit -m "refactor(model): delete FilterFieldConfig; hardcode seedMapViews normalFilters"`

---

### Task 1: 删 LegendSwatch

**Files:** Delete `MapRender/LegendSwatch.swift`、`PropertyAtlasTests/MapRender/LegendSwatchTests.swift`

- [ ] **Step 1: 确认无生产引用**
`cd <worktree> && grep -rn "LegendSwatch" PropertyAtlas/PropertyAtlas` → 应空(P8b 后零生产引用)。若有命中,STOP 报告(超范围)。

- [ ] **Step 2: 删文件**
```bash
cd <worktree>/PropertyAtlas/PropertyAtlas && rm MapRender/LegendSwatch.swift
cd <worktree>/PropertyAtlas/PropertyAtlasTests && rm MapRender/LegendSwatchTests.swift
```

- [ ] **Step 3: 编译 + 全量测试**
`cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -20` → `** TEST SUCCEEDED **`(忽略既知 flaky `testLaunchPerformance`,只看 unit)。

- [ ] **Step 4: 提交** `git add -A && git -c commit.gpgsign=false commit -m "refactor(maprender): delete unused LegendSwatch + test"`

---

### Task 2: 全量测试 + 清库重迁 smoke + CLAUDE.md

**Files:** Modify `CLAUDE.md`

- [ ] **Step 1: 全量单测**
`cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED"` → SUCCEEDED。

- [ ] **Step 2: 清库重迁 smoke(主 agent,破坏性 —— schema 移表)**
移除 FilterFieldConfig 表是 schema 破坏 → 验证轻量迁移。主 agent(非 subagent)执行,沿用 memory `p5-smoke-remigrate-procedure`:
1. 确认 app 未运行。
2. 备份 `~/Library/Application Support/default.store`(+ -shm/-wal)到带时间戳目录。
3. 删 store 三件套。
4. worktree 构建(`xcodebuild build` + `BUILT_PRODUCTS_DIR`)launch **两次**(launch1 seed Legacy*;launch2 migrate)。
5. SQLite 验证:`ZFILTERFIELDCONFIG` 表不存在;`ZMAPVIEW` 4 行且 active 视图 `normalFiltersJSON` 解码出 7 项;实体数不变(ZCOMPOUND=174/ZSCHOOL=823/ZAREA=101)。
> subagent-driven 执行到此暂停,主 agent 处理删库 smoke(用户已授权"备份后删库重迁"模式)。

- [ ] **Step 3: 更新 CLAUDE.md** —— P9a 节点后加 P9b 节点:
```markdown
> **P9b (2026-06-01) 完成后**: 删 `FilterFieldConfig` @Model(schema 移表)+ `LegendSwatch`(P8b 后零生产引用)。
> migrator `seedMapViews` 的 NormalFilter 改**硬编码 7 项**(原由 FilterFieldConfig 派生,行为等价);删
> `seedFilterFields` stage + `cleanupOrphans` purge + ModelSchema 条目 + FilterFieldConfig/LegendSwatch 测试。
> 清库重迁 smoke 验证丢表不崩 + normalFilters 仍 7。**CloudKit 延后**(iOS 未上手)、**Legacy* @Model 删除 + seed
> 管线重写 → P9c**(JSON→新实体直写)。Theme/StyleRule/Camera/Custom 编辑器、逐实体-逐图层 theme 仍延后。
```
并更新计划列表:P9b 标完成,P9c 待写(删 Legacy* + seed 管线重写)、CloudKit 待写(iOS 上手后)。

- [ ] **Step 4: 提交** `git add -A && git -c commit.gpgsign=false commit -m "docs(claude): note P9b FilterFieldConfig/LegendSwatch deletion"`

---

## Self-Review

- **Spec 覆盖**:spec §9 P9 余项的"删 FilterFieldConfig/LegendSwatch"本期完成。**延后**:CloudKit `.private`(iOS 未上手)、删 Legacy* @Model + seed 管线重写(P9c)、Theme/StyleRule/Camera/Custom 编辑器、逐实体-逐图层 theme。
- **行为等价**:`seedMapViews` 硬编码 normals 必须与现 FilterFieldConfig 派生序/内容一致(T0 Step 0 实测对齐)。7 项 = compound2+school3+poi1+area1。
- **占位扫描**:无 TBD;硬编码列表完整给出,顺序对齐实测。
- **风险**:① normals 顺序:按 slot 排序的旧逻辑可能使 4 个 slot=1 项交叉在前 —— 实现期必须 dump 现序并对齐(否则 legend 顺序变)。② schema 移表破坏 → 必须清库重迁 smoke(CloudKit Catalyst .none,不受云干扰)。③ grep 确认 FilterFieldConfig/LegendSwatch 零残留再删。④ `migrateSeedsDefaultFilterFieldConfigs` 删除 + `seedsMapViewsWithDefaults` 改断言。
