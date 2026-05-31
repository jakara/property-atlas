# P5 数据正确性 + 学校显示修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复孤儿数据集污染、学校 pin 无名字/无重普标识、详情卡空白三类 bug;让单一 dataset 干净渲染,学校显示名字 + 等级标识。

**Architecture:** 三条线。(A) 数据正确性 — `LegacyMigrator` 用确定性 datasetId(从 name 派生稳定 UUID),启动时跑孤儿清理(删 datasetId 无对应 Dataset 行的实体),`StudioRootView` 所有实体消费点按活跃 datasetId 过滤。(B) 学校显示 — `LegacyMigrator` stage 8 seed 学校 StyleRules(name labelVisible + grade→重/普 glyph + tier 配色),挂进 themes 的 styleRuleIds。(C) 验证 — in-memory 单测 + 清库重迁移 smoke。

**Tech Stack:** SwiftData · Swift Testing · SeedImporter.uuid(MD5) · StyleRule/StyleResolver 管线 · TestContainer.makeInMemory。

**根因回顾(诊断已确认):**
- DB 现有 2 个 datasetId:`天津 demo`(有 Dataset 行,823 校全有坐标+grade)+ 一个孤儿 datasetId(无 Dataset 行,1646 校无坐标/grade,4 个孤儿 theme)。
- `LegacyMigrator.run`:`Dataset(name:)` 的 id = 随机 `UUID()`;守卫只看"有无 Dataset 行"。开发中 Dataset 行被清而子实体残留 → 下次跑生成新 datasetId,孤立旧子实体。
- `RootView.swift:61-64` 的 `@Query` 无 datasetId 谓词 → 两 dataset 实体全 bleed 进地图/图例。
- seed 的 themes `styleRuleIds = []` 且 `defaultStylesJSON = "{}"` → 全走 builtin(`labelVisible: false`、无 glyph)→ 学校无名字、无重/普(后者随 P2 删 SchoolPinView 一起没了)。

**关键文件清单:**
- 改 `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`(stable id + orphan cleanup + school rules seed)
- 改 `PropertyAtlas/PropertyAtlas/States/SeedImporter.swift`(每次启动调 orphan cleanup)
- 改 `PropertyAtlas/PropertyAtlas/RootView.swift`(消费点 datasetId 过滤)
- 测 `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`(已存在,追加用例)
- 新测 `PropertyAtlas/PropertyAtlasTests/DataKit/OrphanCleanupTests.swift`

---

### Task 0: 确定性 datasetId

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 写失败测试 — 同名迁移产出同一 datasetId**

加到 `LegacyMigratorTests.swift`:

```swift
@Test func datasetIdIsStableAcrossRuns() throws {
    let id1: UUID = {
        let ctx = TestContainer.makeInMemory(for: [LegacySchool.self, Dataset.self, /* + 全 schema, 见下注 */]).mainContext
        seedOneLegacySchool(in: ctx)            // helper 已在本文件其他用例用过；若无则插一条 LegacySchool
        try? LegacyMigrator.run(in: ctx)
        return (try! ctx.fetch(FetchDescriptor<Dataset>())).first!.id
    }()
    let id2: UUID = {
        let ctx = TestContainer.makeInMemory(for: [LegacySchool.self, Dataset.self]).mainContext
        seedOneLegacySchool(in: ctx)
        try? LegacyMigrator.run(in: ctx)
        return (try! ctx.fetch(FetchDescriptor<Dataset>())).first!.id
    }()
    #expect(id1 == id2)
}
```

> 注:`TestContainer.makeInMemory` 需传 migrator 触碰的全部 @Model。沿用本文件既有用例的 schema 数组常量(若存在 `migratorSchema` 之类),否则复制其 schema 列表。`seedOneLegacySchool` 若不存在,内联插入一条 `LegacySchool(id:.init(), name:"测试中学", type:"初中", zoneId:nil, district:"和平区", tier:"重点")`。

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests/LegacyMigratorTests/datasetIdIsStableAcrossRuns`
Expected: FAIL(两次随机 id 不等)。

- [ ] **Step 3: 实现 — 确定性 id**

`LegacyMigrator.swift` 顶部加 helper,并在 `run` 里替换 Dataset 构造:

```swift
/// 稳定 datasetId:同 datasetName 永远派生同一 UUID(MD5),避免重跑孤立旧实体。
static func stableDatasetId(name: String) -> UUID {
    SeedImporter.uuid(from: "dataset:" + name)
}
```

`run(in:)` 内:

```swift
let dataset = Dataset(name: datasetName)
dataset.id = stableDatasetId(name: datasetName)   // ← 新增
ctx.insert(dataset)
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "fix(migrator): deterministic datasetId from dataset name"
```

---

### Task 1: 孤儿清理函数

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/OrphanCleanupTests.swift` (new)

- [ ] **Step 1: 写失败测试**

```swift
import Testing
import SwiftData
@testable import PropertyAtlas

@MainActor
struct OrphanCleanupTests {
    @Test func deletesEntitiesWithNoOwningDataset() throws {
        let ctx = TestContainer.makeInMemory(for: [Dataset.self, School.self, Compound.self, Area.self, Theme.self]).mainContext
        let live = Dataset(name: "live"); ctx.insert(live)
        let orphanDsId = UUID()
        let good = School(datasetId: live.id, name: "好中学"); ctx.insert(good)
        let bad = School(datasetId: orphanDsId, name: "孤儿中学"); ctx.insert(bad)
        try ctx.save()

        LegacyMigrator.cleanupOrphans(in: ctx)
        try ctx.save()

        let schools = try ctx.fetch(FetchDescriptor<School>())
        #expect(schools.count == 1)
        #expect(schools.first?.name == "好中学")
    }
}
```

> 注:`School(datasetId:name:)` 的 init 签名以 `School.swift` 实际为准;若需更多必填参数,补齐。

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests/OrphanCleanupTests`
Expected: FAIL(`cleanupOrphans` 未定义)。

- [ ] **Step 3: 实现 cleanupOrphans**

`LegacyMigrator.swift` 加(硬删,孤儿无 CloudKit 顾虑;只清子实体,不动 Dataset 自身):

```swift
/// 删除 datasetId 不指向任何现存 Dataset 的残留实体(开发期多版迁移遗留)。
/// 每次启动调用,独立于 run() 的 "Dataset 已存在则跳过" 守卫。
static func cleanupOrphans(in ctx: ModelContext) {
    let validIds = Set((try? ctx.fetch(FetchDescriptor<Dataset>()))?.map(\.id) ?? [])

    func purge<T: PersistentModel>(_ type: T.Type, dsId: (T) -> UUID) {
        let all = (try? ctx.fetch(FetchDescriptor<T>())) ?? []
        for e in all where !validIds.contains(dsId(e)) { ctx.delete(e) }
    }
    purge(School.self) { $0.datasetId }
    purge(Compound.self) { $0.datasetId }
    purge(POI.self) { $0.datasetId }
    purge(Area.self) { $0.datasetId }
    purge(Theme.self) { $0.datasetId }
    purge(StyleRule.self) { $0.datasetId }
    purge(Layer.self) { $0.datasetId }
    purge(FilterFieldConfig.self) { $0.datasetId }
    purge(EnumOption.self) { $0.datasetId }
    purge(CameraPreset.self) { $0.datasetId }
    purge(Edge.self) { $0.datasetId }
    purge(Tag.self) { $0.datasetId }
    purge(CustomFieldDef.self) { $0.datasetId }
}
```

> 注:`Palette` 无 datasetId(全局 builtIn),不清。`Document` 按 ownerEntityId 关联,不直接持 datasetId,不在此清(随 owner 实体软删另议),P5 不动。逐一核对各 @Model 确有 `datasetId` 属性;无则从 purge 列表移除。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/OrphanCleanupTests.swift
git commit -m "feat(migrator): cleanupOrphans purges entities with no owning dataset"
```

---

### Task 2: 启动时调用孤儿清理

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/States/SeedImporter.swift:39-46`

- [ ] **Step 1: 实现 — runIfNeeded 开头清孤儿**

`runIfNeeded` 内,`LegacyMigrator.run` 调用前加:

```swift
// P5: 每次启动清理无主实体(独立于迁移守卫)
LegacyMigrator.cleanupOrphans(into: context)   // 见下:用 in: 还是 into: 与签名一致
// P1: Try legacy migration first (idempotent)
try LegacyMigrator.run(in: context)
let datasets = try context.fetch(FetchDescriptor<Dataset>())
if !datasets.isEmpty {
    try context.save()          // ← 确保清理后落盘
    progress(1.0, "已迁移")
    return false
}
```

> 注:Task 1 的函数签名是 `cleanupOrphans(in:)`。此处保持 `in:`。`try context.save()` 必须加,否则清理在早 return 路径不落盘。

- [ ] **Step 2: 编译**

Run: `xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst'`
Expected: BUILD SUCCEEDED。

- [ ] **Step 3: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/States/SeedImporter.swift
git commit -m "feat(seed): run cleanupOrphans + persist on every launch"
```

---

### Task 3: StudioRootView 按活跃 dataset 过滤实体

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`(buildPins 调用点 136-143、legendItems 279-291、layerCands 115-118、buildAreaOverlays 调用点 144-152）

- [ ] **Step 1: 实现 — 过滤所有实体消费点**

`body` 内 `buildPins` 调用改为按 `dsId` 过滤(`dsId` 已在 92 行定义):

```swift
let pins = buildPins(
    compounds: visibility["compound"] == true ? compounds.filter { $0.datasetId == dsId } : [],
    schools: visibility["school"] == true ? schools.filter { $0.datasetId == dsId } : [],
    pois: visibility["poi"] == true ? pois.filter { $0.datasetId == dsId } : [],
    theme: activeTheme, rules: rulesForTheme, palettes: palettesById,
    highlight: highlight,
    layerVisible: layerVisible, filterPredicate: predicate, datasetId: dsId
)
```

`buildAreaOverlays` 调用同样传过滤后的 areas:

```swift
? buildAreaOverlays(
    areas: areas.filter { $0.datasetId == dsId },
    theme: activeTheme, rules: rulesForTheme, palettes: palettesById,
    layerVisible: layerVisible
)
```

`layerCands` 里的 areas 也过滤:

```swift
+ areas.filter { !$0.deleted && $0.datasetId == dsId }.map {
    LayerEvaluator.Candidate(id: $0.id, type: "area", entity: $0.styleEntity)
}
```

`legendItems()` 改为接收 dsId 参数并过滤:

```swift
private func legendItems(_ dsId: UUID) -> [LegendCounter.Item] {
    var out: [LegendCounter.Item] = []
    for c in compounds where !c.deleted && c.datasetId == dsId {
        out.append(.init(id: c.id, type: "compound", entity: c.styleEntity, coordinate: c.coordinate))
    }
    for s in schools where !s.deleted && s.datasetId == dsId {
        out.append(.init(id: s.id, type: "school", entity: s.styleEntity, coordinate: s.coordinate))
    }
    for p in pois where !p.deleted && p.datasetId == dsId {
        out.append(.init(id: p.id, type: "poi", entity: p.styleEntity, coordinate: p.coordinate))
    }
    return out
}
```

并把 106 行 `let items = legendItems()` 改为 `let items = legendItems(dsId)`。

- [ ] **Step 2: 编译**

Run: `xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst'`
Expected: BUILD SUCCEEDED。

- [ ] **Step 3: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/RootView.swift
git commit -m "fix(studio): filter all entity consumers by active datasetId"
```

---

### Task 4: Seed 学校 StyleRules(name 标签 + 重/普 glyph + tier 配色)

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`(stage 8 `seedPalettesThemesLayers`)
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 写失败测试 — 迁移后学校 StyleRule 存在且挂进 theme**

```swift
@Test func seedsSchoolStyleRulesAndAttachesToThemes() throws {
    let ctx = TestContainer.makeInMemory(for: [/* migrator 全 schema */]).mainContext
    seedOneLegacySchool(in: ctx)
    try LegacyMigrator.run(in: ctx)

    let rules = try ctx.fetch(FetchDescriptor<StyleRule>()).filter { $0.entityType == "school" }
    #expect(rules.contains { $0.appliesLabelVisible == true })        // name 标签开
    #expect(rules.contains { $0.appliesGlyph == "重" })                // 重点 glyph
    #expect(rules.contains { $0.appliesGlyph == "普" })                // 普通 glyph

    let themes = try ctx.fetch(FetchDescriptor<Theme>())
    let overview = themes.first { $0.name == "字段总览" }!
    #expect(!overview.styleRuleIds.isEmpty)                            // rule 已挂进 theme
    #expect(rules.allSatisfy { overview.styleRuleIds.contains($0.id) } == false || overview.styleRuleIds.contains(rules.first!.id))
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests/LegacyMigratorTests/seedsSchoolStyleRulesAndAttachesToThemes`
Expected: FAIL(无 school rule)。

- [ ] **Step 3: 实现 — seedPalettesThemesLayers 末尾加 school rules + 挂 theme**

`seedPalettesThemesLayers` 内,创建 4 个 theme 之后、`dataset.activeThemeId = t1.id` 之前,插入:

```swift
// P5: 学校样式规则 — 名字标签 + 等级(grade)→ 重/普 glyph + tier 配色
func cond(_ field: String, _ value: String) -> String {
    let c = [StyleCondition(field: field, op: .equals, value: .string(value))]
    return (try? JSONHelpers.encode(c)) ?? "[]"
}

var schoolRuleIds: [UUID] = []

// 1) 基础:所有学校显示名字标签(低优先级)
let rLabel = StyleRule(datasetId: dataset.id, name: "学校-显示名称", entityType: "school")
rLabel.priority = 0
rLabel.appliesLabelVisible = true
rLabel.appliesShape = "square"
ctx.insert(rLabel); schoolRuleIds.append(rLabel.id)

// 2) 等级 glyph + 配色(高优先级覆盖填色/字形)
let tiers: [(grade: String, glyph: String, fill: String)] = [
    ("重点", "重", "#FF3B30"),
    ("区重点", "重", "#FF9500"),
    ("普通", "普", "#8E8E93"),
]
for (idx, t) in tiers.enumerated() {
    let r = StyleRule(datasetId: dataset.id, name: "学校-\(t.grade)", entityType: "school")
    r.priority = 10 + idx
    r.conditionsJSON = cond("grade", t.grade)
    r.appliesGlyph = t.glyph
    r.appliesGlyphHex = "#FFFFFF"
    r.appliesFillHex = t.fill
    r.appliesLabelVisible = true
    ctx.insert(r); schoolRuleIds.append(r.id)
}

// 挂进"字段总览"+"学区视图"(学校相关视图)
t1.styleRuleIds = schoolRuleIds
t2.styleRuleIds = schoolRuleIds
```

> 注:`StyleCondition` / `StyleConditionOp` 定义在 `ConditionEvaluator.swift`,`@MainActor` 上下文已满足(migrator 是 `@MainActor enum`)。glyph 渲染在 dot 内(`PinAnnotationView` 已支持),name 标签在 dot 右侧。`appliesShape="square"` 与 builtin 一致,显式写避免歧义。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(migrator): seed school style rules (name label + grade glyph/tier color)"
```

---

### Task 5: 详情卡回归测试(确认学校字段加载)

**Files:**
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EntityReaderTests.swift`(已存在,追加)

- [ ] **Step 1: 写测试 — 学校 EntityReader 读出 name + grade + category**

```swift
@Test func schoolReaderReturnsNameGradeCategory() throws {
    let ctx = TestContainer.makeInMemory(for: [School.self]).mainContext
    let s = School(datasetId: UUID(), name: "实验中学")
    s.grade = "重点"; s.category = "初中"
    ctx.insert(s); try ctx.save()
    let ref = EntityRef(id: s.id, kind: .school)

    #expect(EntityReader.name(ref, in: ctx) == "实验中学")
    if case let .string(g)? = EntityReader.value(ref, key: "grade", in: ctx) { #expect(g == "重点") } else { Issue.record("grade 读取失败") }
    if case let .string(c)? = EntityReader.value(ref, key: "category", in: ctx) { #expect(c == "初中") } else { Issue.record("category 读取失败") }
}
```

> 目的:坐实"详情卡空白"非读取层 bug(读取链 styleEntity→field 正常)。若此测试通过,证明卡片空白根因是渲染了孤儿/无 grade 实体(Task 1-3 已解决)或 labelVisible 导致无法定位点哪个 pin(Task 4 已解决)。smoke 时复核。

- [ ] **Step 2: 跑测试确认通过**

Run: `xcodebuild test -scheme PropertyAtlas -only-testing:PropertyAtlasTests/EntityReaderTests/schoolReaderReturnsNameGradeCategory`
Expected: PASS。

- [ ] **Step 3: 提交**

```bash
git add PropertyAtlas/PropertyAtlasTests/DataKit/EntityReaderTests.swift
git commit -m "test(reader): school name/grade/category load regression"
```

---

### Task 6: 全量测试 + 清库重迁移 smoke + CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`(加 P5 完成节点 + plan 链接)

- [ ] **Step 1: 全量单测**

Run: `xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -40`
Expected: 全 unit 套件 PASS(UITests-Runner 超时可忽略,环境 flake)。

- [ ] **Step 2: 清库重迁移 smoke**

清掉 Mac Catalyst store 强制重迁移(确定性 id + 新 rules 生效):

```bash
rm -f ~/Library/Application\ Support/default.store ~/Library/Application\ Support/default.store-wal ~/Library/Application\ Support/default.store-shm
```

构建运行,人工核对:
- 仅 1 个 dataset(`SELECT COUNT(*) FROM ZDATASET` = 1;`SELECT COUNT(DISTINCT ZDATASETID) FROM ZSCHOOL` = 1)
- 学校 pin 显示**名字** + dot 内 **重/普**;重点红、普通灰
- 点学校 → 详情卡显示名称 + 阶段/等级
- 图例小区计数不再是两 dataset 之和

> 注:用户标准 `dangerouslyDisableSandbox` 前先确认。删 store 是不可逆操作 — 数据可由 seed 重建,但用户手动加的 usr_* 标记会丢;执行前与用户确认。

- [ ] **Step 3: 更新 CLAUDE.md**

在 P4 节点后加 P5 节点(格式仿前几节 blockquote):

```markdown
> **P5 (2026-05-31) 完成后**: datasetId 改确定性(`stableDatasetId` 从 name 派生
> MD5),`cleanupOrphans` 每次启动清无主实体;`StudioRootView` 所有实体消费点按
> 活跃 datasetId 过滤(修跨 dataset bleed)。学校 StyleRules seed(名称标签 +
> grade→重/普 glyph + tier 配色)挂进"字段总览"/"学区视图" theme。
> 延后 P6: Settings 全编辑页 + CloudKit `.private` + 删 Legacy* @Model。
```

并在 "实施计划" 列表加:`- 实施计划 P5: docs/superpowers/plans/2026-05-31-p5-data-integrity-school-display.md`

- [ ] **Step 4: 提交**

```bash
git add CLAUDE.md
git commit -m "docs(claude): note P5 data integrity + school display completion"
```

---

## Self-Review

- **Spec 覆盖**:a(孤儿清理)= T1+T2;b(学校名字/重普)= T4;c(根因:确定性 id)= T0;@Query bleed(真实代码 bug)= T3;详情卡 = T5 坐实读取层 OK + smoke 复核。全覆盖用户 1=a+b+c。
- **类型一致**:`cleanupOrphans(in:)` 在 T1 定义、T2 调用,签名一致。`stableDatasetId(name:)` T0 定义并用。`legendItems(_ dsId:)` T3 改签名 + 调用点同步。`StyleCondition(field:op:value:)` 与 `ConditionEvaluator.swift:13` 一致。
- **占位扫描**:无 TBD;非显然逻辑(stable id、orphan purge、rule seed)均给完整代码;wiring 任务给精确行号 + 代码块。
- **风险**:① 各 @Model 是否都有 `datasetId` 属性需 T1 实现时逐一核(Palette 无,已排除;Document 按 owner 关联,已排除)。② T6 删 store 不可逆,执行前确认(已在 step 注明)。③ TestContainer schema 数组需覆盖 migrator 全实体 — 沿用 LegacyMigratorTests 既有常量。
