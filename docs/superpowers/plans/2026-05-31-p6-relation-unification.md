# P6 关系统一(primaryAreaId→Edge + 关系投影)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 把"学片归属"从硬编码 FK `primaryAreaId` 迁成通用 `Edge(label="所属片区")`,删字段;新增 `EdgeStore` 关系投影原语,为后续"按 edge 上下游字段过滤/分组/染色"(Dimension.edgeField)铺路。

**Architecture:** 镜像已有 `migratePrimarySchoolId`(它已把 compound→school 的 FK 迁成 "对口小学" edge)。`primaryAreaId` 当前只写不读(`StyleEntity`/`EntityReader`/查询都不碰),删除零风险。投影原语 `EdgeStore.relatedFieldValues` 给定实体 + edge label + 方向 → 对端实体的某字段值集。

**Tech Stack:** SwiftData · Swift Testing · EdgeStore/EntityReader · LegacyMigrator stage 5(migrateEdges)。

**前置**: 见 spec `docs/superpowers/specs/2026-05-31-generic-filter-legend-color-redesign.md`(决策1 A)。

**关键事实:**
- `primaryAreaId` 写入仅 2 处:`LegacyMigrator.swift:138`(`s.primaryAreaId = ls.zoneId`)、`:240`(`c.primaryAreaId = lc.zoneId`)。无任何读取。
- migrator 保留 id:`area.id = z.id`、新 Compound/School 复用 `lc.id`/`ls.id`(`migratePrimarySchoolId` 用 `lc.id` 作 fromId 即证)。故 `Edge(from: 实体.id, to: zoneId)` 自洽。
- edge.label 枚举已 seed(`LegacyMigrator.swift:449`):对口小学/片内中学/周边/集团成员/集团领办/管辖/属于。需加 "所属片区"。
- `EntityReader.value(ref, key:)` / `.name(ref)` 现成,投影用。

---

### Task 0: primaryAreaId → Edge("所属片区")

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
@Test func migratesPrimaryAreaToEdge() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let zone = LegacySchoolZone(name: "和平一片区", tier: "普通", primaryDistrict: "和平区", geometry: "", geometryStage: "hull")
    ctx.insert(zone)
    let lc = LegacyCompound(name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)
    lc.zoneId = zone.id
    ctx.insert(lc)
    let ls = LegacySchool(name: "测试小学", type: "小学", district: "和平区", tier: "普通")
    ls.zoneId = zone.id
    ctx.insert(ls)
    try ctx.save()

    try LegacyMigrator.run(in: ctx)

    let edges = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "所属片区" }
    #expect(edges.contains { $0.fromId == lc.id && $0.toId == zone.id && $0.fromType == "compound" && $0.toType == "area" })
    #expect(edges.contains { $0.fromId == ls.id && $0.toId == zone.id && $0.fromType == "school" && $0.toType == "area" })
}
```
> 注:`LegacySchoolZone`/`LegacyCompound`/`LegacySchool` init 签名以现有测试既用法为准(本文件已多处用 `LegacySchool(name:type:district:tier:)`)。`zoneId` 是可选属性,构造后赋值。若 LegacyCompound init 需更多必填参数,补齐。

- [ ] **Step 2: 跑测试确认失败**

Run: `cd /Users/fujie/projects/天津买房 && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/LegacyMigratorTests/migratesPrimaryAreaToEdge 2>&1 | tail -25`
(注:xcodebuild 须在含 `.xcodeproj` 的目录运行 → `cd .../PropertyAtlas` 子目录。)
Expected: FAIL(无 "所属片区" edge)。

- [ ] **Step 3: 实现**

(a) 删 `LegacyMigrator.swift:138` 的 `s.primaryAreaId = ls.zoneId` 和 `:240` 的 `c.primaryAreaId = lc.zoneId`(两行直接删)。

(b) 在 `migrateEdges(...)` 体内追加调用:
```swift
try migratePrimaryArea(dataset: dataset, in: ctx)
```
(c) 新增私有方法(镜像 `migratePrimarySchoolId`):
```swift
private static func migratePrimaryArea(dataset: Dataset, in ctx: ModelContext) throws {
    let dsId = dataset.id
    // compounds
    for lc in try ctx.fetch(FetchDescriptor<LegacyCompound>()) {
        guard let to = lc.zoneId else { continue }
        let e = Edge(
            datasetId: dsId,
            fromId: lc.id, fromType: "compound",
            toId: to, toType: "area",
            label: "所属片区", directed: true
        )
        ctx.insert(e)
    }
    // schools
    for ls in try ctx.fetch(FetchDescriptor<LegacySchool>()) {
        guard let to = ls.zoneId else { continue }
        let e = Edge(
            datasetId: dsId,
            fromId: ls.id, fromType: "school",
            toId: to, toType: "area",
            label: "所属片区", directed: true
        )
        ctx.insert(e)
    }
}
```
(d) edge.label 枚举 seed(`seedEnumOptions` 里 `("edge.label", [...])`)末尾加 `"所属片区"`。

- [ ] **Step 4: 跑测试确认通过**(同 Step 2 命令)

- [ ] **Step 5: 跑全量 LegacyMigratorTests**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/LegacyMigratorTests 2>&1 | tail -30` — 全过。

- [ ] **Step 6: 提交**

```bash
git -c commit.gpgsign=false commit -am "feat(migrator): migrate primaryAreaId to Edge(所属片区) + add edge.label enum"
```

---

### Task 1: 删除 primaryAreaId 字段

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Models/Entities/Compound.swift`, `School.swift`, `POI.swift`

- [ ] **Step 1: 删字段声明**

三个文件各删一行 `var primaryAreaId: UUID?`(行 15 附近)。POI 虽未被 migrator 写,也删(统一)。

- [ ] **Step 2: 确认无残留引用**

Run: `cd /Users/fujie/projects/天津买房 && grep -rn "primaryAreaId" PropertyAtlas/PropertyAtlas --include="*.swift" | grep -v Legacy`
Expected: 空(Task 0 已删 migrator 写入)。若有残留,处理后再继续。

- [ ] **Step 3: 构建**

Run: `cd PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED。(SwiftData 轻量迁移自动丢弃旧列;CloudKit .none 无碍。)

- [ ] **Step 4: 提交**

```bash
git -c commit.gpgsign=false commit -am "refactor(model): remove non-generic primaryAreaId FK (replaced by Edge)"
```

---

### Task 2: EdgeStore 关系投影原语

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EdgeStoreTests.swift`(已存在则追加,否则新建)

- [ ] **Step 1: 写失败测试**

```swift
@Test func relatedFieldValuesProjectsAcrossEdge() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let dsId = UUID()
    let area = Area(datasetId: dsId, name: "和平一片区", geometryKind: "polygon", geometryJSON: "")
    ctx.insert(area)
    let c = Compound(datasetId: dsId, name: "测试小区", latitude: 39.1, longitude: 117.2)
    ctx.insert(c)
    ctx.insert(Edge(datasetId: dsId, fromId: c.id, fromType: "compound",
                    toId: area.id, toType: "area", label: "所属片区", directed: true))
    try ctx.save()

    let ref = EntityRef(id: c.id, kind: .compound)
    // downstream: compound 是 from,取对端 area 的 name
    let names = EdgeStore.relatedFieldValues(of: ref, edgeLabel: "所属片区", direction: .downstream, targetField: nil, datasetId: dsId, in: ctx)
    #expect(names == ["和平一片区"])
    // 无该 label 关系 → 空
    let none = EdgeStore.relatedFieldValues(of: ref, edgeLabel: "对口小学", direction: .downstream, targetField: nil, datasetId: dsId, in: ctx)
    #expect(none.isEmpty)
}
```
> 注:`Area`/`Compound` init 签名以现有为准(`Area(datasetId:name:geometryKind:geometryJSON:)`、`Compound(datasetId:name:latitude:longitude:)`)。`targetField: nil` 表示取对端实体名。

- [ ] **Step 2: 跑测试确认失败**(`-only-testing:PropertyAtlasTests/EdgeStoreTests/relatedFieldValuesProjectsAcrossEdge`)→ FAIL(方法未定义)。

- [ ] **Step 3: 实现**

EdgeStore 加方向枚举 + 投影方法:
```swift
enum EdgeDirection { case downstream, upstream, either }

/// 投影:ref 经 edgeLabel(按方向)连到的对端实体,取 targetField 字段值(nil=对端名)。
/// 去空、保序、去重前保留(调用方决定)。供 Dimension.edgeField 用。
static func relatedFieldValues(
    of ref: EntityRef,
    edgeLabel: String,
    direction: EdgeDirection,
    targetField: String?,
    datasetId: UUID,
    in context: ModelContext
) -> [String] {
    let id = ref.id, dsId = datasetId
    let fd = FetchDescriptor<Edge>(predicate: #Predicate {
        $0.datasetId == dsId && !$0.deleted && $0.label == edgeLabel &&
            ($0.fromId == id || $0.toId == id)
    })
    let edges = (try? context.fetch(fd)) ?? []
    var out: [String] = []
    for e in edges {
        let other: EntityRef
        if e.fromId == id {
            if direction == .upstream { continue }       // ref 是 from → 这是 downstream 边
            guard let k = EntityKind(rawValue: e.toType) else { continue }
            other = EntityRef(id: e.toId, kind: k)
        } else {
            if direction == .downstream { continue }     // ref 是 to → 这是 upstream 边
            guard let k = EntityKind(rawValue: e.fromType) else { continue }
            other = EntityRef(id: e.fromId, kind: k)
        }
        let value: String?
        if let f = targetField {
            value = EntityReader.value(other, key: f, in: context).flatMap { stringify($0) }
        } else {
            value = EntityReader.name(other, in: context)
        }
        if let v = value, !v.isEmpty { out.append(v) }
    }
    return out
}

private static func stringify(_ v: AnyJSON) -> String? {
    switch v {
    case let .string(s): return s.isEmpty ? nil : s
    case let .int(n): return String(n)
    case let .double(d): return String(d)
    case let .bool(b): return String(b)
    default: return nil
    }
}
```
> `EdgeStore` 是 `@MainActor`(`EntityReader` 也是),调用满足。`EntityKind`/`EntityRef` 在 `DataKit/EntityRef.swift`。

- [ ] **Step 4: 跑测试确认通过**(同 Step 2)

- [ ] **Step 5: 跑全量 EdgeStoreTests** → 全过。

- [ ] **Step 6: 提交**

```bash
git -c commit.gpgsign=false commit -am "feat(edgestore): relatedFieldValues projection primitive for edge-traversal dimensions"
```

---

### Task 3: 全量测试 + smoke + CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 全量单测**

Run: `cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -40`
Expected: 全 unit 套件 PASS(0 failure;UITests flake 忽略)。

- [ ] **Step 2: 清库重迁移 smoke(验 "所属片区" edge)**

> 删 store 不可逆,先备份(见 memory `p5-smoke-remigrate-procedure`):`cp ~/Library/Application\ Support/default.store* /tmp/`。需用户确认。
启动 app 两次(seed→migrate),查:
```bash
DB=~/Library/Application\ Support/default.store
sqlite3 "$DB" "SELECT COUNT(*) FROM ZEDGE WHERE ZLABEL='所属片区';"   # 应 > 0
sqlite3 "$DB" "SELECT name FROM pragma_table_info('ZCOMPOUND') WHERE name='ZPRIMARYAREAID';"  # 应空(列已删)
```
正确 app build 路径用 `xcodebuild -showBuildSettings | grep BUILT_PRODUCTS_DIR` 取(避陈旧构建)。

- [ ] **Step 3: 更新 CLAUDE.md**

P5 节点后加:
```markdown
> **P6 (2026-05-31) 完成后**: 关系模型统一 — `primaryAreaId` FK 删除,迁成
> `Edge(label="所属片区")`(`migratePrimaryArea`);edge.label 枚举加"所属片区"。
> `EdgeStore.relatedFieldValues(of:edgeLabel:direction:targetField:)` 投影原语
> (供后续 Dimension.edgeField 按 edge 上下游字段过滤/分组/染色)。
> 见 spec `docs/superpowers/specs/2026-05-31-generic-filter-legend-color-redesign.md`。
> 后续 P7(Dimension+Filter 引擎)/ P8(View+Theme 下沉+染色)/ P9(Settings+CloudKit)。
```
并在计划列表加 P6 行。

- [ ] **Step 4: 提交**

```bash
git -c commit.gpgsign=false commit -am "docs(claude): note P6 relation unification completion"
```

---

## Self-Review

- **Spec 覆盖**:P6 = spec §9 第 1 项(关系统一 + 投影原语)。primaryAreaId→Edge(T0)、删字段(T1)、EdgeStore 投影(T2)、验证(T3)。Dimension 值类型本身留 P7(本计划只交付投影原语,签名匹配 edgeField 未来用)。
- **类型一致**:`migratePrimaryArea` T0 定义+在 migrateEdges 调用。`relatedFieldValues`/`EdgeDirection` T2 定义+测试用,签名与 spec §3 edgeField 参数(edgeLabel/direction/targetField)对齐。`stringify` 与 PaletteResolver 同名私有,各自文件内,无冲突。
- **占位扫描**:无 TBD;核心逻辑(迁移、投影)给完整代码;删字段给精确行号。
- **风险**:① T1 删 @Model 字段 = schema 变更,靠 SwiftData 轻量迁移丢列(CloudKit .none 无碍);现有 store 旧列自动废弃。② T0 测试 fixture 的 Legacy* init 签名需按实际微调。③ smoke 删库不可逆,T3 已注明备份 + 用户确认。④ `EntityReader.value` 对 area 的 name 读取:area 的 styleEntity 须暴露 "name" —— 现有 Area styleEntity 已含 name(P2),投影 targetField=nil 走 `EntityReader.name` 更稳。
