# 图层显式归属 + DB-first 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把图层成员资格从「entityType ∩ primaryFilter 实时派生」改为「`entity.layerId` 显式归属」,并移除启动 seed 导入转为 DB-first;同时清掉上次重构遗留的 legacy 样式模型(Stage B)。

**Architecture:** 每实体加 `layerId` 外键显式归属某图层(同 entityType 容器);图层内 `primaryFilter`(基线显示门)+ `normalFilter`(交互 chip)+ groupBy 染色只管「已归属成员怎么显示」,不再决定成员。归属赋值经默认层 + 批量按条件 + 手动移动。启动不再 seed/migrate,DB 即权威数据。

**Tech Stack:** Swift / SwiftUI / SwiftData (Mac Catalyst, `cloudKitDatabase: .none`) / Swift Testing / MapKit。

**Spec:** `docs/superpowers/specs/2026-06-10-layer-ownership-redesign.md`

**分支:** `feat/view-owned-style`(已有图层中心化重构 11 commit + spec commit)。

---

## 前置约定(全任务通用)

- **Build(app target)**:
  ```bash
  cd /Users/fujie/projects/天津买房/PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' build 2>&1 | tail -5
  ```
  期望末行 `** BUILD SUCCEEDED **`。SourceKit 的「Cannot find type X」诊断是跨文件噪音,只认 xcodebuild 错误。
- **Test(unit target)**:在上面命令尾部把 `build` 换成 `test -only-testing:PropertyAtlasTests`。`PropertyAtlasUITests` 是独立 UI 自动化 target,其崩溃与本计划无关,勿混淆。
- **SwiftData store**:`~/Library/Application Support/default.store`。字段名 Core Data 风格 `Z<UPPER>` 前缀;`UUID` 列存为字符串。**改库前必须 app 退出 + 备份**:
  ```bash
  cd ~/Library/Application\ Support && cp default.store "default.store.bak-$(date +%Y%m%d-%H%M%S)"
  ```
- **DB-first 警告**:Phase E 后无 JSON 兜底,库删=数据没了。每次破坏性操作前备份。
- **确认 app 未运行**:`ps aux | grep -i propertyatlas | grep -v grep | grep -v Xcode || echo NOT_RUNNING`
- **文件 ≤300 行**(SwiftLint 约束)。新逻辑拆独立文件。

---

## 文件结构总览

| 文件 | 责任 | 动作 |
|---|---|---|
| `Models/Entities/{Compound,School,POI,Area}.swift` | 实体 | 改:各加 `var layerId: UUID?` |
| `Models/Display/Layer.swift` | 图层 | 改:加回 `var isDefault: Bool` |
| `MapRender/ConditionEvaluator.swift` | `StyleEntity` | 改:加 `layerId`,4 个 `.styleEntity` 适配器填值 |
| `MapRender/LayerResolver.swift` | 可见性解析 | 改:容器判定加 `entity.layerId == layer.id` |
| `DataKit/LayerAssign.swift` | 归属赋值逻辑 | 新建:默认层/批量/移动/删层回落 |
| `DataKit/EntityWriter.swift` | 建实体 | 改:`createPin` 赋默认层 |
| `Studio/Settings/LayerConfigSections.swift` | 图层设置区块 | 改:加「按条件赋值」section |
| `Studio/Settings/LayerSettingsTab.swift` | 图层 tab | 改:默认层禁删 |
| `Studio/Editor/EditorBasicTab.swift` | 实体基本编辑 | 改:加「所属图层」Picker |
| `PropertyAtlasApp.swift` | app 入口 | 改:去 seed gate,直接 RootView |
| `DataKit/ModelSchema.swift` | schema 注册 | 改:删 StyleRule/Palette/Theme |
| `Models/Core/Dataset.swift` | dataset | 改:删 `activeThemeId` |
| `States/AppState.swift` | UI 态 | 改:删 `activeThemeId` |
| 删除文件 | — | `SeedProgressView`/`SeedImporter`/`LegacyMigrator`/`LayerMigratorV3`/`StyleConsolidationMigrator`/`Models/Seeds/*`/`Models/Style/{StyleRule,Theme,Palette}.swift`/`MapRender/{StyleRuleMatcher,PaletteResolver,ThemeContext}.swift` + 对应测试 |

---

# Phase A — Schema:加列 + 一次性 SQL 迁移

> 目标:DB 与模型加上 `layerId`/`isDefault` 并把存量实体的 `layerId` 写好。此阶段**不改解析逻辑**(仍派生),app 照常工作,只是新列就位。

### Task A1: Layer 加回 `isDefault`,4 实体加 `layerId`

**Files:**
- Modify: `PropertyAtlas/Models/Display/Layer.swift`
- Modify: `PropertyAtlas/Models/Entities/Compound.swift`
- Modify: `PropertyAtlas/Models/Entities/School.swift`
- Modify: `PropertyAtlas/Models/Entities/POI.swift`
- Modify: `PropertyAtlas/Models/Entities/Area.swift`

- [ ] **Step 1: Layer 加 `isDefault`**

`Layer.swift` 在 `var showLegend: Bool = true` 行后加:

```swift
    var showLegend: Bool = true
    /// 该 entityType 的默认图层标记。每 entityType 恰一个 true。
    /// 默认层不可删;删其他层时成员回落于此;新建实体落于此。
    var isDefault: Bool = false
```

- [ ] **Step 2: 4 实体各加 `layerId`**

在每个实体的 `var deleted: Bool = false` 行后加(4 个文件都加):

```swift
    var deleted: Bool = false
    /// 显式图层归属。可空仅为轻量迁移加列方便;迁移后业务上恒非空(默认层不变式保证)。
    var layerId: UUID?
```

- [ ] **Step 3: Build**

Run build 命令。Expected: `** BUILD SUCCEEDED **`。(新增 optional/defaulted 属性 = SwiftData 安全轻量迁移。)

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/Models/Display/Layer.swift PropertyAtlas/Models/Entities/Compound.swift PropertyAtlas/Models/Entities/School.swift PropertyAtlas/Models/Entities/POI.swift PropertyAtlas/Models/Entities/Area.swift
git commit -m "feat(model): add entity.layerId + Layer.isDefault for explicit ownership"
```

### Task A2: 迁移启动 + SQL 写 layerId(操作任务,非代码)

> ⚠️ 这是操作步骤,需 app 退出 + 备份。由执行者(人/operator)跑,不写进代码。

- [ ] **Step 1: 确认 app 未运行**

```bash
ps aux | grep -i propertyatlas | grep -v grep | grep -v Xcode || echo NOT_RUNNING
```
Expected: `NOT_RUNNING`。

- [ ] **Step 2: 启动 app 一次(Xcode ⌘R),让 SwiftData 加新列,然后退出 app**

启动后 `layerId` 列 = NULL,`ZISDEFAULT` 列 = 0。确认无崩溃后退出 app。

- [ ] **Step 3: 备份库**

```bash
cd ~/Library/Application\ Support && cp default.store "default.store.bak-$(date +%Y%m%d-%H%M%S)-pre-layerid"
```

- [ ] **Step 4: 取各图层 id(字符串)**

```bash
cd ~/Library/Application\ Support && sqlite3 default.store "SELECT ZNAME, ZENTITYTYPE, ZID FROM ZLAYER WHERE ZDELETED=0 ORDER BY ZZINDEX;"
```
Expected: 6 行(片区/行政区/路网=area, 楼盘=compound, 学校=school, POI=poi)各带 ZID。

- [ ] **Step 5: SQL 写 layerId(按 entityType / area 按 category)**

```bash
cd ~/Library/Application\ Support && sqlite3 default.store <<'SQL'
UPDATE ZCOMPOUND SET ZLAYERID = (SELECT ZID FROM ZLAYER WHERE ZENTITYTYPE='compound' AND ZDELETED=0 LIMIT 1) WHERE ZDELETED=0;
UPDATE ZSCHOOL   SET ZLAYERID = (SELECT ZID FROM ZLAYER WHERE ZENTITYTYPE='school'   AND ZDELETED=0 LIMIT 1) WHERE ZDELETED=0;
UPDATE ZPOI      SET ZLAYERID = (SELECT ZID FROM ZLAYER WHERE ZENTITYTYPE='poi'      AND ZDELETED=0 LIMIT 1) WHERE ZDELETED=0;
UPDATE ZAREA SET ZLAYERID = (SELECT ZID FROM ZLAYER WHERE ZNAME='路网'   AND ZDELETED=0 LIMIT 1) WHERE ZCATEGORY='道路'   AND ZDELETED=0;
UPDATE ZAREA SET ZLAYERID = (SELECT ZID FROM ZLAYER WHERE ZNAME='行政区' AND ZDELETED=0 LIMIT 1) WHERE ZCATEGORY='行政区' AND ZDELETED=0;
UPDATE ZAREA SET ZLAYERID = (SELECT ZID FROM ZLAYER WHERE ZNAME='片区'   AND ZDELETED=0 LIMIT 1) WHERE (ZCATEGORY IS NULL OR ZCATEGORY NOT IN ('道路','行政区')) AND ZDELETED=0;
SQL
```

- [ ] **Step 6: SQL 置 isDefault + 清 primaryFilter**

```bash
cd ~/Library/Application\ Support && sqlite3 default.store <<'SQL'
UPDATE ZLAYER SET ZISDEFAULT=1 WHERE ZNAME IN ('楼盘','学校','POI','片区') AND ZDELETED=0;
UPDATE ZLAYER SET ZISDEFAULT=0 WHERE ZNAME IN ('行政区','路网') AND ZDELETED=0;
UPDATE ZLAYER SET ZPRIMARYFILTERJSON='{"conditions":[],"groupBy":null}' WHERE ZDELETED=0;
SQL
```

- [ ] **Step 7: 验证(零 null + 成员数 + 默认层)**

```bash
cd ~/Library/Application\ Support && sqlite3 default.store <<'SQL'
SELECT 'compound null', COUNT(*) FROM ZCOMPOUND WHERE ZDELETED=0 AND ZLAYERID IS NULL;
SELECT 'school null',   COUNT(*) FROM ZSCHOOL   WHERE ZDELETED=0 AND ZLAYERID IS NULL;
SELECT 'poi null',      COUNT(*) FROM ZPOI      WHERE ZDELETED=0 AND ZLAYERID IS NULL;
SELECT 'area null',     COUNT(*) FROM ZAREA     WHERE ZDELETED=0 AND ZLAYERID IS NULL;
SELECT ZNAME, ZISDEFAULT, (SELECT COUNT(*) FROM ZCOMPOUND c WHERE c.ZLAYERID=l.ZID AND c.ZDELETED=0)
                        + (SELECT COUNT(*) FROM ZSCHOOL s WHERE s.ZLAYERID=l.ZID AND s.ZDELETED=0)
                        + (SELECT COUNT(*) FROM ZPOI p WHERE p.ZLAYERID=l.ZID AND p.ZDELETED=0)
                        + (SELECT COUNT(*) FROM ZAREA a WHERE a.ZLAYERID=l.ZID AND a.ZDELETED=0) AS members
  FROM ZLAYER l WHERE l.ZDELETED=0 ORDER BY l.ZZINDEX;
SQL
```
Expected: 4 个 null 计数全 0;成员数 楼盘=174 / 学校=823 / POI=0 / 路网=22 / 行政区=16 / 片区=101;`ZISDEFAULT` 在 楼盘/学校/POI/片区 = 1,行政区/路网 = 0。

> 此 Task 无 commit(纯 DB 操作,DB 不进 git)。记录验证输出到执行日志。

---

# Phase B — 解析:layerId 容器(派生 → 显式)

> 目标:把成员判定从 primaryFilter 切到 layerId。**必须在 Phase A SQL 跑完后**做,否则 layerId 全 nil → 地图空。

### Task B1: `StyleEntity` 携带 `layerId`

**Files:**
- Modify: `PropertyAtlas/MapRender/ConditionEvaluator.swift`
- Test: `PropertyAtlasTests/MapRender/StyleEntityLayerIdTests.swift` (Create)

- [ ] **Step 1: 写失败测试**

`PropertyAtlasTests/MapRender/StyleEntityLayerIdTests.swift`:

```swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleEntityLayerIdTests {
    @Test func carriesLayerId() {
        let lid = UUID()
        let se = StyleEntity(entityType: "school", id: UUID(), baseFields: [:], customFields: [:], layerId: lid)
        #expect(se.layerId == lid)
    }
    @Test func defaultsNil() {
        let se = StyleEntity(entityType: "poi", id: UUID(), baseFields: [:], customFields: [:])
        #expect(se.layerId == nil)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run test 命令(可加 `-only-testing:PropertyAtlasTests/StyleEntityLayerIdTests`)。Expected: 编译失败 `extra argument 'layerId'`。

- [ ] **Step 3: `StyleEntity` 加 `layerId`**

`ConditionEvaluator.swift` 改 `StyleEntity`:

```swift
struct StyleEntity {
    let entityType: String
    let id: UUID
    private let baseFields: [String: AnyJSON]
    private let customFields: [String: AnyJSON]
    /// 实体级 override（typed 列 → partial）。空 partial = 无 override。
    let overridePin: PartialPinStyle
    let overrideArea: PartialAreaStyle
    /// 显式图层归属(图层中心化-显式归属重构)。
    let layerId: UUID?

    init(
        entityType: String,
        id: UUID,
        baseFields: [String: AnyJSON],
        customFields: [String: AnyJSON],
        overridePin: PartialPinStyle = PartialPinStyle(),
        overrideArea: PartialAreaStyle = PartialAreaStyle(),
        layerId: UUID? = nil
    ) {
        self.entityType = entityType
        self.id = id
        self.baseFields = baseFields
        self.customFields = customFields
        self.overridePin = overridePin
        self.overrideArea = overrideArea
        self.layerId = layerId
    }

    func field(_ name: String) -> AnyJSON? {
        if let val = baseFields[name] { return val }
        return customFields[name]
    }
}
```

- [ ] **Step 4: 4 个 `.styleEntity` 适配器填 `layerId`**

`ConditionEvaluator.swift` 内 School/Compound/POI/Area 的 `var styleEntity: StyleEntity` 适配器(约 line 94-186),每个在 `StyleEntity(...)` 构造尾部加 `layerId: layerId`。例(Compound):

```swift
    var styleEntity: StyleEntity {
        StyleEntity(
            entityType: "compound", id: id,
            baseFields: [...],          // 原内容不变
            customFields: [...],        // 原内容不变
            overridePin: ...,           // 原内容不变
            layerId: layerId
        )
    }
```
对 School/POI/Area 同样在末尾加 `layerId: layerId`(它们的 @Model 已在 A1 有 `layerId` 属性)。

- [ ] **Step 5: 跑测试确认通过 + build**

Run test。Expected: PASS。再跑 build,Expected `** BUILD SUCCEEDED **`。

- [ ] **Step 6: Commit**

```bash
git add PropertyAtlas/MapRender/ConditionEvaluator.swift PropertyAtlasTests/MapRender/StyleEntityLayerIdTests.swift
git commit -m "feat(render): thread layerId into StyleEntity"
```

### Task B2: `LayerResolver` 容器改用 layerId

**Files:**
- Modify: `PropertyAtlas/MapRender/LayerResolver.swift`
- Test: `PropertyAtlasTests/MapRender/LayerResolverTests.swift` (Modify/重写)

- [ ] **Step 1: 重写测试(成员=layerId,primaryFilter=显示门)**

替换 `PropertyAtlasTests/MapRender/LayerResolverTests.swift` 全文:

```swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerResolverTests {
    private func se(_ id: UUID, type: String, layerId: UUID?, fields: [String: AnyJSON] = [:]) -> LayerResolver.Candidate {
        LayerResolver.Candidate(id: id, entity: StyleEntity(
            entityType: type, id: id, baseFields: fields, customFields: [:], layerId: layerId
        ))
    }
    private func layer(_ id: UUID, type: String, z: Int, primary: PrimaryFilter = PrimaryFilter(conditions: [], groupBy: nil)) -> LayerResolver.ActiveLayer {
        LayerResolver.ActiveLayer(id: id, name: "L", entityType: type, zIndex: z, enabled: true, minZoom: nil, maxZoom: nil, primary: primary, normals: [])
    }

    @Test func memberByLayerIdOnly() {
        let lid = UUID(); let e1 = UUID(); let e2 = UUID()
        let cands = [se(e1, type: "school", layerId: lid), se(e2, type: "school", layerId: UUID())]
        let res = LayerResolver.resolve(candidates: cands, layers: [layer(lid, type: "school", z: 0)],
                                        zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil)
        #expect(res[e1] == lid)      // 归属本层 → 命中
        #expect(res[e2] == nil)      // 归属别层 → 不在本层
    }

    @Test func wrongTypeExcluded() {
        let lid = UUID(); let e = UUID()
        let cands = [se(e, type: "compound", layerId: lid)]
        let res = LayerResolver.resolve(candidates: cands, layers: [layer(lid, type: "school", z: 0)],
                                        zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil)
        #expect(res[e] == nil)       // entityType 不符,即便 layerId 相同也排除
    }

    @Test func primaryFilterIsDisplayGate() {
        let lid = UUID(); let e = UUID()
        let primary = PrimaryFilter(conditions: [FilterCondition(field: "grade", op: .equals, values: [.string("重点")])], groupBy: nil)
        let hit  = [se(e, type: "school", layerId: lid, fields: ["grade": .string("重点")])]
        let miss = [se(e, type: "school", layerId: lid, fields: ["grade": .string("普通")])]
        let L = layer(lid, type: "school", z: 0, primary: primary)
        let rHit  = LayerResolver.resolve(candidates: hit,  layers: [L], zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil)
        let rMiss = LayerResolver.resolve(candidates: miss, layers: [L], zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil)
        #expect(rHit[e] == lid)      // 归属 + primary 命中 → 显示
        #expect(rMiss[e] == nil)     // 归属但 primary 不命中 → 当前不显示(仍属本层)
    }

    @Test func nilLayerIdNeverShows() {
        let lid = UUID(); let e = UUID()
        let cands = [se(e, type: "school", layerId: nil)]
        let res = LayerResolver.resolve(candidates: cands, layers: [layer(lid, type: "school", z: 0)],
                                        zoom: 14, filterState: DimensionFilterState(), context: nil, datasetId: nil)
        #expect(res[e] == nil)
    }
}
```

> 注:`FilterCondition` 的真实 init 签名以 `States/PrimaryFilter.swift` 为准;若字段名/参数不同,按实际调整测试构造。

- [ ] **Step 2: 跑测试确认失败**

Run test `-only-testing:PropertyAtlasTests/LayerResolverTests`。Expected: `memberByLayerIdOnly`/`nilLayerIdNeverShows` 失败(当前 resolver 不看 layerId,e2/nil 仍可能命中)。

- [ ] **Step 3: resolve 循环加 layerId 容器判定**

`LayerResolver.swift` 的 resolve 内层循环(line 48-57)改为先判 layerId:

```swift
        for c in candidates {
            let type = c.entity.entityType
            for layer in active where layer.entityType == type {
                // 显式归属:实体 layerId 必须等于本层 id(容器判定)
                guard c.entity.layerId == layer.id else { continue }
                let input = MapDimension.Input(
                    entity: c.entity, layerNames: [layer.name], context: context, datasetId: datasetId,
                    edgeProjection: edgeProjection, cache: cache
                )
                guard layer.primary.matches(input) else { continue }   // primaryFilter = 显示门
                if isHidden(input: input, layer: layer, filterState: filterState) { continue }
                if let existing = winner[c.id], existing.zIndex >= layer.zIndex { continue }
                winner[c.id] = (layer.id, layer.zIndex)
            }
        }
```

更新文件顶部注释:成员 = layerId 容器,primaryFilter 为显示门。

- [ ] **Step 4: 跑测试确认通过 + build**

Run test。Expected: 4 测全 PASS。Build。Expected `** BUILD SUCCEEDED **`。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/MapRender/LayerResolver.swift PropertyAtlasTests/MapRender/LayerResolverTests.swift
git commit -m "feat(render): LayerResolver membership by explicit layerId; primaryFilter as display gate"
```

### Task B3: 图例/染色按 layerId 容器对齐

> `DimensionLegendCounter` / `GroupColorResolver` 当前在 RootView 里按「命中图层」分组喂数据(`entityToLayer`)。Phase B2 后 `entityToLayer` 已是 layerId 容器结果,故图例/染色**自动**只统计本层成员 —— 无需改这两个文件。本 Task 仅验证。

**Files:**
- Read-only verify: `PropertyAtlas/Studio/StudioRootView.swift`(`buildLegendSpecs`/`GroupColorResolver.colors` 调用处,约 line 685-764)

- [ ] **Step 1: 确认图例/染色消费 `entityToLayer`**

阅读 `buildLegendSpecs` 与 group color 调用:确认它们按 `entityToLayer[id]`(B2 的 layerId 结果)分组,而非独立重算成员。若发现独立重算(不经 entityToLayer),记录为缺陷反馈给协调者。

- [ ] **Step 2: 无代码改动则跳过 commit**

若验证通过无需改动,本 Task 不产生 commit;在执行日志注明「图例/染色经 entityToLayer,B2 后自动对齐」。

---

# Phase C — 赋值逻辑 + 默认层不变式

### Task C1: `LayerAssign` 服务(纯逻辑 + TDD)

**Files:**
- Create: `PropertyAtlas/DataKit/LayerAssign.swift`
- Test: `PropertyAtlasTests/DataKit/LayerAssignTests.swift`

- [ ] **Step 1: 写失败测试**

`PropertyAtlasTests/DataKit/LayerAssignTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerAssignTests {
    private func ctx() throws -> ModelContext {
        ModelContext(try TestContainer.makeInMemory(for: ModelSchema.allTypes))
    }
    private func mkLayer(_ c: ModelContext, _ ds: UUID, _ name: String, _ type: String, def: Bool, z: Int) -> Layer {
        let l = Layer(datasetId: ds, name: name, entityType: type); l.isDefault = def; l.zIndex = z
        c.insert(l); return l
    }

    @Test func defaultLayerLookup() throws {
        let c = try ctx(); let ds = UUID()
        _ = mkLayer(c, ds, "副", "school", def: false, z: 1)
        let d = mkLayer(c, ds, "默认", "school", def: true, z: 0)
        try c.save()
        #expect(LayerAssign.defaultLayer(entityType: "school", datasetId: ds, in: c)?.id == d.id)
        #expect(LayerAssign.defaultLayer(entityType: "poi", datasetId: ds, in: c) == nil)
    }

    @Test func bulkAssignByConditionMoves() throws {
        let c = try ctx(); let ds = UUID()
        let def = mkLayer(c, ds, "学校", "school", def: true, z: 0)
        let key = mkLayer(c, ds, "重点", "school", def: false, z: 1)
        let s1 = School(datasetId: ds, name: "A"); s1.grade = "重点"; s1.layerId = def.id
        let s2 = School(datasetId: ds, name: "B"); s2.grade = "普通"; s2.layerId = def.id
        c.insert(s1); c.insert(s2); try c.save()
        let n = LayerAssign.bulkAssign(
            entityType: "school",
            conditions: [StyleCondition(field: "grade", op: .equals, value: .string("重点"))],
            toLayerId: key.id, datasetId: ds, in: c
        )
        #expect(n == 1)
        #expect(s1.layerId == key.id)   // 命中 → 移动
        #expect(s2.layerId == def.id)   // 未命中 → 留原层
    }

    @Test func deleteLayerFallsBackToDefault() throws {
        let c = try ctx(); let ds = UUID()
        let def = mkLayer(c, ds, "学校", "school", def: true, z: 0)
        let extra = mkLayer(c, ds, "重点", "school", def: false, z: 1)
        let s = School(datasetId: ds, name: "A"); s.layerId = extra.id
        c.insert(s); try c.save()
        let ok = LayerAssign.deleteLayer(extra, in: c)
        #expect(ok == true)
        #expect(extra.deleted == true)
        #expect(s.layerId == def.id)    // 成员回落默认层
    }

    @Test func cannotDeleteDefault() throws {
        let c = try ctx(); let ds = UUID()
        let def = mkLayer(c, ds, "学校", "school", def: true, z: 0)
        try c.save()
        #expect(LayerAssign.deleteLayer(def, in: c) == false)  // 默认层禁删
        #expect(def.deleted == false)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run test `-only-testing:PropertyAtlasTests/LayerAssignTests`。Expected: 编译失败 `Cannot find 'LayerAssign'`。

- [ ] **Step 3: 实现 `LayerAssign`**

`PropertyAtlas/DataKit/LayerAssign.swift`:

```swift
import Foundation
import SwiftData

/// 图层显式归属赋值逻辑。写 entity.layerId;维持默认层不变式。
@MainActor
enum LayerAssign {
    /// 某 entityType 的默认图层(isDefault=true,未删)。
    static func defaultLayer(entityType: String, datasetId: UUID, in ctx: ModelContext) -> Layer? {
        let d = FetchDescriptor<Layer>(predicate: #Predicate {
            $0.datasetId == datasetId && $0.entityType == entityType && $0.isDefault && !$0.deleted
        })
        return try? ctx.fetch(d).first
    }

    /// 把命中 conditions(AND)的某类型实体移动到 toLayerId。返回移动数。
    static func bulkAssign(
        entityType: String, conditions: [StyleCondition], toLayerId: UUID,
        datasetId: UUID, in ctx: ModelContext
    ) -> Int {
        var count = 0
        for (se, set) in styleEntities(entityType: entityType, datasetId: datasetId, in: ctx) {
            guard conditions.allSatisfy({ ConditionEvaluator.matches(entity: se, condition: $0) }) else { continue }
            set(toLayerId)
            count += 1
        }
        if count > 0 { try? ctx.save() }
        return count
    }

    /// 预览:命中数(不改库)。
    static func previewCount(
        entityType: String, conditions: [StyleCondition], datasetId: UUID, in ctx: ModelContext
    ) -> Int {
        styleEntities(entityType: entityType, datasetId: datasetId, in: ctx)
            .filter { se, _ in conditions.allSatisfy { ConditionEvaluator.matches(entity: se, condition: $0) } }
            .count
    }

    /// 删图层:默认层禁删(返回 false);否则成员回落默认层后软删(返回 true)。
    static func deleteLayer(_ layer: Layer, in ctx: ModelContext) -> Bool {
        guard !layer.isDefault else { return false }
        guard let def = defaultLayer(entityType: layer.entityType, datasetId: layer.datasetId, in: ctx) else { return false }
        reassignMembers(from: layer.id, to: def.id, entityType: layer.entityType, datasetId: layer.datasetId, in: ctx)
        layer.deleted = true
        layer.updatedAt = Date()
        try? ctx.save()
        return true
    }

    // MARK: - helpers

    /// 取某类型全实体的 (StyleEntity, 写 layerId 闭包)。统一 4 类分发。
    private static func styleEntities(
        entityType: String, datasetId: UUID, in ctx: ModelContext
    ) -> [(StyleEntity, (UUID) -> Void)] {
        switch entityType {
        case "compound":
            let xs = (try? ctx.fetch(FetchDescriptor<Compound>(predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }))) ?? []
            return xs.map { e in (e.styleEntity, { e.layerId = $0; e.updatedAt = Date() }) }
        case "school":
            let xs = (try? ctx.fetch(FetchDescriptor<School>(predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }))) ?? []
            return xs.map { e in (e.styleEntity, { e.layerId = $0; e.updatedAt = Date() }) }
        case "poi":
            let xs = (try? ctx.fetch(FetchDescriptor<POI>(predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }))) ?? []
            return xs.map { e in (e.styleEntity, { e.layerId = $0; e.updatedAt = Date() }) }
        case "area":
            let xs = (try? ctx.fetch(FetchDescriptor<Area>(predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted }))) ?? []
            return xs.map { e in (e.styleEntity, { e.layerId = $0; e.updatedAt = Date() }) }
        default:
            return []
        }
    }

    private static func reassignMembers(
        from old: UUID, to new: UUID, entityType: String, datasetId: UUID, in ctx: ModelContext
    ) {
        for (se, set) in styleEntities(entityType: entityType, datasetId: datasetId, in: ctx) where se.layerId == old {
            set(new)
        }
    }
}
```

> 若 `School` 无 `grade` 属性,测试用其真实存在的字段(如 `gradeRaw`/`level`);实现不依赖具体字段。`ConditionEvaluator.matches` 已存在(`ConditionEvaluator.swift`)。`School(datasetId:name:)` init 以实际签名为准。

- [ ] **Step 4: 跑测试确认通过 + build**

Run test。Expected: 4 测 PASS(若 School 字段名不符,先据实修测试构造再跑)。Build。Expected SUCCEEDED。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/DataKit/LayerAssign.swift PropertyAtlasTests/DataKit/LayerAssignTests.swift
git commit -m "feat(layer): LayerAssign — default lookup, bulk-assign by condition, delete-fallback"
```

### Task C2: 新建实体进默认层

**Files:**
- Modify: `PropertyAtlas/DataKit/EntityWriter.swift`

- [ ] **Step 1: `createPin` 赋默认层**

`EntityWriter.createPin`(line 7-36)在创建实体并 `insert` 之后、`return` 之前,加默认层赋值。把 line 15 的注释「创建时不再指派图层」替换为新逻辑。在 `context.insert(...)` 之后插入:

```swift
        // 显式归属:新建实体落入该 entityType 的默认图层(默认层不变式)。
        if let def = LayerAssign.defaultLayer(entityType: kind.entityTypeString, datasetId: datasetId, in: context) {
            switch kind {
            case .compound: (newEntity as? Compound)?.layerId = def.id
            case .school:   (newEntity as? School)?.layerId = def.id
            case .poi:      (newEntity as? POI)?.layerId = def.id
            case .area:     (newEntity as? Area)?.layerId = def.id
            }
        }
```

> 以 `EntityWriter.createPin` 实际的局部变量名 / `EntityKind` case 名 / `entityTypeString` 取法为准(读文件确认)。若 `EntityKind` 已有 entityType 字符串映射,复用之;否则用 switch 直接传 `"compound"` 等字面量给 `defaultLayer(entityType:)`。

- [ ] **Step 2: Build**

Run build。Expected SUCCEEDED。

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/DataKit/EntityWriter.swift
git commit -m "feat(entity): new pins assigned to entityType default layer"
```

---

# Phase D — UI:按条件赋值 / 移到图层 / 默认层禁删

### Task D1: 图层设置「按条件赋值」section

**Files:**
- Modify: `PropertyAtlas/Studio/Settings/LayerConfigSections.swift`
- Read for context: `PropertyAtlas/Studio/Settings/StyleConditionRow.swift`(条件行组件,P9d 已有)

- [ ] **Step 1: 读现有条件行组件签名**

阅读 `StyleConditionRow`(已存在)与 `LayerConfigSections.swift` 的 section 写法(`LayerPrimaryFilterSection`/`LayerStyleSection`),沿用其 `SettingsCard` + binding 风格。

- [ ] **Step 2: 加 `LayerBulkAssignSection`**

在 `LayerConfigSections.swift` 末尾(`#endif` 之前)加一个 section view。它持 `@Bindable var layer: Layer` + `@Environment(\.modelContext)`,本地 `@State var conditions: [StyleCondition] = []`,渲染若干 `StyleConditionRow`(增/删条件)+ 一个「预览 N 个」文本(调 `LayerAssign.previewCount`)+「赋值到本层」按钮(调 `LayerAssign.bulkAssign(entityType: layer.entityType, conditions:, toLayerId: layer.id, datasetId: layer.datasetId, in: ctx)`)。entityType 取 `layer.entityType`,字段候选经现有 `FieldKeyCatalog`(P9a)。

```swift
struct LayerBulkAssignSection: View {
    @Bindable var layer: Layer
    @Environment(\.modelContext) private var ctx
    @State private var conditions: [StyleCondition] = []

    var body: some View {
        SettingsCard("按条件赋值") {
            VStack(alignment: .leading, spacing: 10) {
                Text("把命中以下全部条件(AND)的「\(layer.entityType)」实体移入本图层。")
                    .font(Studio.sans(11)).foregroundStyle(Studio.on2)
                ForEach(conditions.indices, id: \.self) { i in
                    StyleConditionRow(entityType: layer.entityType, datasetId: layer.datasetId,
                                      condition: $conditions[i]) { conditions.remove(at: i) }
                }
                Button { conditions.append(StyleCondition(field: "", op: .equals, value: .string(""))) } label: {
                    Label("加条件", systemImage: "plus")
                }.buttonStyle(.tbtn(.ghost))
                HStack {
                    Text("命中 \(LayerAssign.previewCount(entityType: layer.entityType, conditions: conditions, datasetId: layer.datasetId, in: ctx)) 个")
                        .font(Studio.sans(12)).foregroundStyle(Studio.on2)
                    Spacer()
                    Button("赋值到本层") {
                        _ = LayerAssign.bulkAssign(entityType: layer.entityType, conditions: conditions,
                                                   toLayerId: layer.id, datasetId: layer.datasetId, in: ctx)
                    }
                    .buttonStyle(.tbtn(.solid))
                    .disabled(conditions.isEmpty || conditions.contains { $0.field.isEmpty })
                }
            }
            .padding(.horizontal, 13).padding(.bottom, 12)
        }
    }
}
```

> `StyleConditionRow` 的真实参数签名以现有组件为准(P9d 用于 ViewStyleRule 条件);若签名不同,适配。按钮样式 `.tbtn(...)` 与卡片 `SettingsCard` 已是项目内现成组件。

- [ ] **Step 3: 挂进图层配置**

`LayerSettingsTab.swift` 的 `layerConfig(_:)`(line 57-65)在 `LayerStyleSection(layer: l)` 后加 `LayerBulkAssignSection(layer: l)`。

- [ ] **Step 4: Build**

Run build。Expected SUCCEEDED。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/Studio/Settings/LayerConfigSections.swift PropertyAtlas/Studio/Settings/LayerSettingsTab.swift
git commit -m "feat(settings): bulk-assign entities to layer by condition"
```

### Task D2: 默认层禁删 + 徽标

**Files:**
- Modify: `PropertyAtlas/Studio/Settings/LayerSettingsTab.swift`

- [ ] **Step 1: 删除走 `LayerAssign.deleteLayer` + 默认层禁删**

`LayerSettingsTab.swift` 的 `deleteLayer(_:)`(line 149-153)改为:

```swift
    private func deleteLayer(_ l: Layer) {
        guard !l.isDefault else { return }   // 默认层禁删
        _ = LayerAssign.deleteLayer(l, in: modelContext)
    }
```

`cardHeader(_:)`(line 110-120)的删除按钮:默认层时禁用 + 显徽标:

```swift
    private func cardHeader(_ l: Layer) -> some View {
        HStack(spacing: 8) {
            TextField("名称", text: Binding(get: { l.name }, set: { l.name = $0
                l.updatedAt = Date()
            })).glassField()
            if l.isDefault {
                Text("默认").font(Studio.sans(10, .semibold)).foregroundStyle(Studio.on3)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Studio.glassInput, in: Capsule())
            }
            Button(role: .destructive) { deleteLayer(l)
            } label: {
                Image(systemName: "trash").font(.system(size: 12))
                    .foregroundStyle(l.isDefault ? Studio.on3 : Studio.bad)
            }
            .buttonStyle(.plain)
            .disabled(l.isDefault)
        }
    }
```

- [ ] **Step 2: Build + Commit**

Run build (Expected SUCCEEDED)。

```bash
git add PropertyAtlas/Studio/Settings/LayerSettingsTab.swift
git commit -m "feat(settings): default layer undeletable + badge; delete via LayerAssign"
```

### Task D3: 实体编辑器「所属图层」Picker

**Files:**
- Modify: `PropertyAtlas/Studio/Editor/EditorBasicTab.swift`
- Read for context: `PropertyAtlas/Studio/Editor/EntityEditor.swift`(tab 结构),`PropertyAtlas/DataKit/EntityReader.swift`/`EntityWriter.swift`(实体读写)

- [ ] **Step 1: 读 EditorBasicTab 拿到当前实体引用方式**

确认 `EditorBasicTab` 如何持有当前实体(经 `EntityRef` + reader/writer,还是直接 @Bindable @Model)。「所属图层」需读写实体的 `layerId`,且只列同 entityType 的未删图层。

- [ ] **Step 2: 加「所属图层」Picker**

在 `EditorBasicTab` 基本字段区加一个 field:用 `@Query` 取本 dataset 同 entityType 的 `Layer`(未删),Picker 绑实体 `layerId`,选择即写 `entity.layerId = 选中 id` + `updatedAt`。示意:

```swift
    @Query private var allLayers: [Layer]
    private var typeLayers: [Layer] {
        allLayers.filter { $0.datasetId == datasetId && $0.entityType == entityType && !$0.deleted }
            .sorted { $0.zIndex < $1.zIndex }
    }
    // body 内一个 field:
    field("所属图层") {
        Picker("", selection: layerIdBinding) {
            ForEach(typeLayers, id: \.id) { Text($0.name).tag($0.id as UUID?) }
        }.labelsHidden().tint(Studio.cool)
    }
```
`layerIdBinding` get/set 实体的 `layerId`(经 reader/writer 或直接 @Model 写),set 时 `updatedAt = Date()`。`datasetId`/`entityType` 取自当前编辑实体。

> 实际取实体/写字段的方式以 `EditorBasicTab` 现有 pattern 为准(它已编辑 name/notes 等基本字段,沿用同一写路径)。

- [ ] **Step 3: Build + Commit**

Run build (Expected SUCCEEDED)。

```bash
git add PropertyAtlas/Studio/Editor/EditorBasicTab.swift
git commit -m "feat(editor): move entity to another layer (same entityType)"
```

---

# Phase E — Bootstrap DB-first + Stage B 删 legacy

> ⚠️ 此阶段删 schema 中 3 个 @Model(StyleRule/Theme/Palette)= 第二次 schema 演进(轻量迁移丢这 3 表)。**先备份库**。删码量大但机械。

### Task E1: app 入口去 seed gate

**Files:**
- Modify: `PropertyAtlas/PropertyAtlasApp.swift`
- Delete: `PropertyAtlas/States/SeedProgressView.swift`

- [ ] **Step 1: 入口直接 RootView**

`PropertyAtlasApp.swift`:删 `@State private var seedDone = false`(line 13);body 的 `Group { if seedDone {...} else { SeedProgressView... } }` 改为直接:

```swift
        WindowGroup {
            RootView()
                .environment(selectionState)
                .environment(appMode)
        }
```

- [ ] **Step 2: 删 SeedProgressView**

```bash
git rm PropertyAtlas/States/SeedProgressView.swift
```

- [ ] **Step 3: Build**

Run build。**预期此步会因 SeedImporter/Migrator 仍被引用而成功或仅 SeedProgressView 相关报错消失**;若报 `SeedImporter` 未用警告忽略。Expected SUCCEEDED(SeedImporter 文件此时仍在,E2 才删)。

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlasApp.swift
git commit -m "feat(app): DB-first — remove seed gate, launch straight to RootView"
```

### Task E2: 删 seed 导入码路径

**Files:**
- Delete: `PropertyAtlas/States/SeedImporter.swift`, `PropertyAtlas/DataKit/LegacyMigrator.swift`, `PropertyAtlas/DataKit/LayerMigratorV3.swift`, `PropertyAtlas/Models/Seeds/`(整目录)
- Delete tests: 任何 `LegacyMigratorTests`/`SeedBundleMigrateTests`/`LayerMigratorV3Tests`
- Modify: `PropertyAtlas/Models/Core/Dataset.swift`(删 `layerModelV3` 闸字段,若仅 migrator 用)

- [ ] **Step 1: 找引用**

```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas && grep -rn "SeedImporter\|LegacyMigrator\|LayerMigratorV3\|SeedBundle\|layerModelV3" --include="*.swift" PropertyAtlas PropertyAtlasTests
```

- [ ] **Step 2: 删文件 + 测试**

```bash
git rm PropertyAtlas/States/SeedImporter.swift PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/DataKit/LayerMigratorV3.swift
git rm -r PropertyAtlas/Models/Seeds
git rm PropertyAtlasTests/DataKit/LegacyMigratorTests.swift PropertyAtlasTests/DataKit/SeedBundleMigrateTests.swift 2>/dev/null || true
# LayerMigratorV3 若有测试一并 git rm
```

- [ ] **Step 3: 清残引用**

`Dataset.swift` 删 `var layerModelV3`(line ~28,确认无其他读者后删)。其余 grep 命中处按编译错误清理(应仅剩已删文件内部互引)。

- [ ] **Step 4: Build**

Run build。Expected SUCCEEDED。若报错,按提示删剩余引用。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(bootstrap): delete seed-import code path (DB-first)"
```

### Task E3: Stage B — 删 StyleConsolidationMigrator + 旧样式模型 + 死辅助

**Files:**
- Delete: `PropertyAtlas/DataKit/StyleConsolidationMigrator.swift`, `PropertyAtlas/Models/Style/StyleRule.swift`, `PropertyAtlas/Models/Style/Theme.swift`, `PropertyAtlas/Models/Style/Palette.swift`, `PropertyAtlas/MapRender/StyleRuleMatcher.swift`, `PropertyAtlas/MapRender/PaletteResolver.swift`, `PropertyAtlas/MapRender/ThemeContext.swift`
- Modify: `PropertyAtlas/DataKit/ModelSchema.swift`(删 3 type), `PropertyAtlas/Models/Core/Dataset.swift`(删 `activeThemeId`), `PropertyAtlas/States/AppState.swift`(删 `activeThemeId`), `PropertyAtlas/MapRender/StyleDefaults.swift`(删 `parseThemeDefaults`,保 `builtinPin`/`builtinArea`)
- Delete tests: `StyleRuleTests`/`ThemeTests`/`PaletteTests`/`ThemeContextTests`/`StyleRuleMatcherTests`/`PaletteResolverTests`/`StyleConsolidationMigratorTests`/`StyleConsolidationMigratorRuleTests`,`StyleDefaultsTests` 删 parseThemeDefaults 用例

- [ ] **Step 1: 备份库(Stage B 是破坏性 schema 演进)**

```bash
cd ~/Library/Application\ Support && cp default.store "default.store.bak-$(date +%Y%m%d-%H%M%S)-pre-stageB"
```

- [ ] **Step 2: 删 ModelSchema 3 条目**

`ModelSchema.swift` line 12-13 删掉 `StyleRule.self, Palette.self, Theme.self`(连注释 `// New style`):

```swift
        // New display
        Layer.self, ViewEntityStyle.self, ViewStyleRule.self, ViewStyleCondition.self,
```

- [ ] **Step 3: 删字段**

- `Dataset.swift`:删 `var activeThemeId`(line ~9)。
- `AppState.swift`:删 `activeThemeId`(line ~11)。

- [ ] **Step 4: 删 `StyleDefaults.parseThemeDefaults`**

`StyleDefaults.swift` 删 `parseThemeDefaults`(line ~41),保留 `builtinPin`/`builtinArea`(RootView 仍用)。

- [ ] **Step 5: 删文件 + 测试**

```bash
cd /Users/fujie/projects/天津买房/PropertyAtlas
git rm PropertyAtlas/DataKit/StyleConsolidationMigrator.swift \
       PropertyAtlas/Models/Style/StyleRule.swift PropertyAtlas/Models/Style/Theme.swift PropertyAtlas/Models/Style/Palette.swift \
       PropertyAtlas/MapRender/StyleRuleMatcher.swift PropertyAtlas/MapRender/PaletteResolver.swift PropertyAtlas/MapRender/ThemeContext.swift
git rm PropertyAtlasTests/Models/StyleRuleTests.swift PropertyAtlasTests/Models/ThemeTests.swift PropertyAtlasTests/Models/PaletteTests.swift \
       PropertyAtlasTests/MapRender/ThemeContextTests.swift PropertyAtlasTests/MapRender/StyleRuleMatcherTests.swift PropertyAtlasTests/MapRender/PaletteResolverTests.swift \
       PropertyAtlasTests/DataKit/StyleConsolidationMigratorTests.swift PropertyAtlasTests/DataKit/StyleConsolidationMigratorRuleTests.swift
```

- [ ] **Step 6: 清残引用(编译器驱动)**

```bash
grep -rn "StyleRule\b\|\bTheme\b\|\bPalette\b\|ThemeContext\|StyleRuleMatcher\|PaletteResolver\|parseThemeDefaults\|activeThemeId" --include="*.swift" PropertyAtlas PropertyAtlasTests
```
逐处清理(注意:`ViewStyleRule`/`ResolvedStyleRule`/`StyleResolver` 是新路径,**保留**;只删旧 `StyleRule`/`Theme`/`Palette` 相关)。`StyleDefaultsTests` 删调用 `parseThemeDefaults` 的用例,保留 builtin 用例。

- [ ] **Step 7: Build + Test**

Run build (Expected SUCCEEDED)。Run test `-only-testing:PropertyAtlasTests` (Expected TEST SUCCEEDED;已删测试不再计入)。

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor(style): Stage B — delete legacy StyleRule/Theme/Palette models + dead helpers"
```

---

# Phase F — 验证

### Task F1: 运行时验证(需 app 启动)

> 操作任务。Phase E 改了 schema(删 3 表)→ 启动时 SwiftData 轻量迁移丢表。

- [ ] **Step 1: 确认 app 未运行 + 备份**

```bash
ps aux | grep -i propertyatlas | grep -v grep | grep -v Xcode || echo NOT_RUNNING
cd ~/Library/Application\ Support && cp default.store "default.store.bak-$(date +%Y%m%d-%H%M%S)-pre-F"
```

- [ ] **Step 2: 启动 app(⌘R),确认无崩溃 + 地图渲染**

目视:楼盘/学校/路网图层默认显示(enabled);多图层 toggle OR;按 layerId 容器渲染(无实体凭空消失)。

- [ ] **Step 3: 退出 app,SQL 核 schema + 数据**

```bash
cd ~/Library/Application\ Support && sqlite3 default.store ".tables" | tr ' ' '\n' | grep -E "ZSTYLERULE|ZTHEME|ZPALETTE" || echo "legacy tables GONE"
sqlite3 default.store "SELECT 'compound',COUNT(*) FROM ZCOMPOUND WHERE ZDELETED=0 AND ZLAYERID IS NOT NULL UNION ALL SELECT 'school',COUNT(*) FROM ZSCHOOL WHERE ZDELETED=0 AND ZLAYERID IS NOT NULL;"
```
Expected: `legacy tables GONE`;compound 174 / school 823 layerId 非空。

- [ ] **Step 4: 功能验证(app 内)**

启动 app:① 图层设置「按条件赋值」选条件→预览数→赋值,确认目标层成员增、源层减;② 实体编辑器「所属图层」切换,确认地图归属变;③ 默认层删除按钮灰掉;④ 删非默认层,确认成员回落默认层(仍可见);⑤ 地图新建 pin,确认进默认层。

- [ ] **Step 5: 记录结果**

把 build/test/sqlite 输出与目视结果记入执行日志。无 commit。

### Task F2: 更新 CLAUDE.md 进度块

**Files:**
- Modify: `CLAUDE.md`(项目根 `天津买房/CLAUDE.md`)

- [ ] **Step 1: 加 spec/plan 到文档表 + 进度块**

在 CLAUDE.md 文档列表加本 spec/plan;加「图层显式归属 + DB-first (2026-06-10) 完成后」总结块,记:entity.layerId 显式归属、LayerResolver 容器改 layerId、primaryFilter 降显示门、LayerAssign(默认/批量/移动/删层回落)、启动去 seed 转 DB-first(删 SeedImporter/LegacyMigrator/LayerMigratorV3/SeedProgressView)、Stage B 删 StyleRule/Theme/Palette/StyleConsolidationMigrator/ThemeContext/StyleRuleMatcher/PaletteResolver + Dataset.activeThemeId。注明 seed 导出/重导入为将来工作。

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): record layer-ownership + DB-first refactor"
```

---

## 收尾

全 Phase 完成后:派最终 code-reviewer 审整个实现,再用 `superpowers:finishing-a-development-branch` 处理分支(**不擅自 merge/push,等用户选**)。

## 风险与回滚

- **每次 DB 操作前已备份**(`default.store.bak-*`)。出错可 `cp` 回滚。
- **Phase B 依赖 Phase A SQL**:若 A 的 layerId 未写好就上 B,地图会空。F1 Step 2 是兜底目视。
- **Stage B 不可逆**(丢 3 表)。E3 Step 1 备份是唯一退路。
- **uncommitted 残留**:当前工作区有一处 `LegacyMigrator.swift` 几何剥离改动(已在 DB 层完成几何清除,该代码改动在 E2 删 LegacyMigrator 时一并消失,无需单独处理)+ 未跟踪 `scripts/fetch_street_boundaries.py`(seed 工具,保留)。
