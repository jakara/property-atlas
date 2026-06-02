# P9c Seed 管线直写 + 删 Legacy* @Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"JSON → Legacy* @Model(存库)→ LegacyMigrator → 正式实体"的两次启动管线,压成一次启动直写;删除全部废弃 @Model。

**Architecture:** 方案 B(最小风险)。Legacy* 及供给类从 `@Model class` 降级为纯 `Codable struct`(`*Seed`,不进库的内存 DTO);`SeedImporter` 用现有 dict 解析把 JSON 装进 `SeedBundle`;`LegacyMigrator.run` 改读 `SeedBundle` 数组而非 `ctx.fetch(FetchDescriptor<Legacy*>())`,转换逻辑内容不变;一次启动完成 seed+migrate。死代码(LegacyAdmissionDoc/BuiltinTag/SchoolScore 及其 stage)直接删。

**Tech Stack:** Swift / SwiftData / Swift Testing(`import Testing`,非 XCTest)/ Mac Catalyst(`xcodebuild`)。

**Spec:** `docs/superpowers/specs/2026-06-02-p9c-seed-pipeline-direct-write-design.md`

---

## 构建 / 测试命令(本仓固定)

工作目录:执行时的 worktree 内 `PropertyAtlas/`(含 `.xcodeproj`)。

- 构建:
  ```bash
  xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -5
  ```
  期望末行 `** BUILD SUCCEEDED **`。
- 全量单测:
  ```bash
  xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -15
  ```
  期望 `** TEST SUCCEEDED **`(唯一已知 flaky:`PropertyAtlasUITests.testLaunchPerformance` "Received unexpected number of metrics: 0",与本计划无关,忽略)。
- 单个测试套件(加速迭代):在上面 test 命令后加 `-only-testing:PropertyAtlasTests/<SuiteName>`。

> **重要**:SourceKit/IDE 的 "No such module 'Testing'" / "Cannot find type X" 是陈旧索引噪声,只有 `xcodebuild build`/`test` 的输出权威。

---

## 文件结构

**新建:**
- `PropertyAtlas/PropertyAtlas/Models/Entities/GeoJSONHelper.swift` —— 把现在嵌在 `LegacySchoolZone.swift` 里的**自由 enum `GeoJSONHelper`** 原样搬出(被 `Area.swift`/`UserArea.swift`/`GeoJSONTests` 依赖,绝不能随 Legacy 文件删除)。
- `PropertyAtlas/PropertyAtlas/Models/Seeds/ZoneSeed.swift` —— `ZoneSeed` struct(含 `decodedCoordinates`/`decodeRaster`/`RasterGeometry`,从 LegacySchoolZone 搬来)。
- `PropertyAtlas/PropertyAtlas/Models/Seeds/SchoolSeed.swift` —— `SchoolSeed` struct。
- `PropertyAtlas/PropertyAtlas/Models/Seeds/CompoundSeed.swift` —— `CompoundSeed` struct。
- `PropertyAtlas/PropertyAtlas/Models/Seeds/SupportSeeds.swift` —— `GroupSeed`/`MatchSeed`/`PolicySeed`/`AdmissionRateSeed` + `SeedBundle`。
- `PropertyAtlas/PropertyAtlasTests/Models/SeedDTOTests.swift` —— DTO 解码 + ZoneSeed.decodeRaster 单测。

**修改:**
- `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift` —— `run(in:)` → `run(seeds:in:)`;各 stage 读 `seeds.*`;删 `migrateAdmissionDocs`/`migrateTags`。
- `PropertyAtlas/PropertyAtlas/States/SeedImporter.swift` —— import* 返回 `*Seed` 数组;`aggregateZoneTier(&bundle)`;删 `needsImport`;`runIfNeeded` 组 bundle + 调新 run。
- `PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift` —— `allTypes` 移除 10 个 Legacy*/供给类。
- `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift` —— 改喂 `SeedBundle` + `run(seeds:in:)`;删 admissionDocs/builtinTags 两用例。
- `PropertyAtlas/PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift` —— `LegacySchoolZone` → `ZoneSeed`。
- `PropertyAtlas/PropertyAtlasTests/Studio/SchoolModelGeocodeTests.swift` —— `LegacySchool` → `SchoolSeed`。
- `CLAUDE.md` —— P9c 节点 + 计划列表。

**删除(T2):**
- `Models/Public/LegacyCompound.swift`、`LegacySchool.swift`、`LegacySchoolZone.swift`、`LegacyAdmissionDoc.swift`、`SchoolGroup.swift`、`CompoundSchoolMatch.swift`、`Policy.swift`、`AdmissionRate.swift`、`SchoolScore.swift`、`BuiltinTag.swift`。

---

## Task 0: 抽出 GeoJSONHelper + 建 *Seed DTO 层

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Entities/GeoJSONHelper.swift`
- Create: `PropertyAtlas/PropertyAtlas/Models/Seeds/ZoneSeed.swift`
- Create: `PropertyAtlas/PropertyAtlas/Models/Seeds/SchoolSeed.swift`
- Create: `PropertyAtlas/PropertyAtlas/Models/Seeds/CompoundSeed.swift`
- Create: `PropertyAtlas/PropertyAtlas/Models/Seeds/SupportSeeds.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Models/Public/LegacySchoolZone.swift`(摘除 `GeoJSONHelper` enum)
- Test: `PropertyAtlas/PropertyAtlasTests/Models/SeedDTOTests.swift`

纯 additive(Legacy* @Model 仍在,迁移仍用旧 `run(in:)`)。Xcode 工程用文件系统同步组,新增 `.swift` 自动纳入 target;若构建报 "Cannot find type",检查文件确实落在 `PropertyAtlas/PropertyAtlas/...` 下。

- [ ] **Step 1: 把 GeoJSONHelper 搬到独立文件**

新建 `Models/Entities/GeoJSONHelper.swift`,内容为从 `LegacySchoolZone.swift` 第 77–102 行原样剪切的自由 enum:

```swift
import CoreLocation
import Foundation

enum GeoJSONHelper {
    static func decodePolygon(_ geojson: String) throws -> [CLLocationCoordinate2D] {
        guard let data = geojson.data(using: .utf8) else {
            throw GeoJSONError.invalidUTF8
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let coords = dict["coordinates"] as? [[[Double]]],
              let ring = coords.first
        else {
            throw GeoJSONError.invalidStructure
        }
        return ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }

    static func encodePolygon(_ coords: [CLLocationCoordinate2D]) throws -> String {
        let ring = coords.map { [$0.longitude, $0.latitude] }
        let dict: [String: Any] = ["type": "Polygon", "coordinates": [ring]]
        let data = try JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8)!
    }

    enum GeoJSONError: Error {
        case invalidUTF8, invalidStructure
    }
}
```

然后从 `LegacySchoolZone.swift` **删除**第 77–102 行那段 `enum GeoJSONHelper { ... }`(文件其余不动,`decodedCoordinates`/`decodeRaster` 仍引用 `GeoJSONHelper`,现指向新文件)。

- [ ] **Step 2: 验证 build 通过(搬迁无回归)**

Run: `xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`(`Area.swift`/`UserArea.swift`/`GeoJSONTests` 仍找得到 `GeoJSONHelper`)。

- [ ] **Step 3: 建 ZoneSeed**

新建 `Models/Seeds/ZoneSeed.swift`:

```swift
import CoreLocation
import Foundation

/// JSON 输入 DTO(对应 zones.json,原 LegacySchoolZone)。不进 SwiftData。
struct ZoneSeed: Codable {
    var id: UUID
    var name: String
    var tier: String = "普通"          // aggregateZoneTier 会覆盖
    var primaryDistrict: String
    var geometry: String
    var geometryStage: String = "hull"
    var residencyYears: Int?
    var strokeColorHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String?
    var note: String?
    var structureJSON: String?
    var middleSchoolPoolJSON: String?
    var sensitiveHighlight: String?
    var sensitiveSource: String?
    var sensitiveNote: String?

    var decodedCoordinates: [CLLocationCoordinate2D] {
        (try? GeoJSONHelper.decodePolygon(geometry)) ?? []
    }

    struct RasterGeometry {
        let image: String
        let corners: [CLLocationCoordinate2D]
    }

    static func decodeRaster(_ json: String) throws -> RasterGeometry {
        guard let data = json.data(using: .utf8) else {
            throw GeoJSONHelper.GeoJSONError.invalidUTF8
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let image = dict["image"] as? String,
              let corners = dict["corners"] as? [[Double]],
              corners.count == 4
        else {
            throw GeoJSONHelper.GeoJSONError.invalidStructure
        }
        return RasterGeometry(
            image: image,
            corners: corners.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
        )
    }
}
```

- [ ] **Step 4: 建 SchoolSeed**

新建 `Models/Seeds/SchoolSeed.swift`:

```swift
import Foundation

/// JSON 输入 DTO(对应 schools.json,原 LegacySchool)。不进 SwiftData。
struct SchoolSeed: Codable {
    var id: UUID
    var name: String
    var type: String = "小学"
    var zoneId: UUID?
    var zoneName: String?
    var district: String
    var tier: String = "普通"
    var address: String?
    var phone: String?
    var campuses: String?
    var communitiesText: String?
    var tuition: String?
    var isPublicSchool: Bool = true
    var isJiunian: Bool = false
    var is12Year: Bool = false
    var isMarketFive: Bool = false
    var isMarketKey: Bool = false
    var sourceCode: String?
    var notes: String?
    var motto: String?
    var websiteUrl: String?
    var foundedYear: Int?
    var sourceUrl: String?
    var lat: Double?
    var lon: Double?
    var geocodeSource: String?
    var geocodeConfidence: String?
    var sensitiveTierLetter: String?
    var sensitiveTierLabel: String?
    var sensitiveRankOverall: Int?
    var sensitiveTopPercentile: Int?
    var sensitiveTierRank: Int?
    var sensitiveComment: String?
    var sensitiveDataOrigin: String?
    var sensitiveSource: String?
    var sensitiveSourceUrl: String?
    var sensitiveNote: String?
}
```

- [ ] **Step 5: 建 CompoundSeed**

新建 `Models/Seeds/CompoundSeed.swift`:

```swift
import Foundation

/// JSON 输入 DTO(对应 compounds.json,原 LegacyCompound)。不进 SwiftData。
struct CompoundSeed: Codable {
    var id: UUID
    var amapPoiId: String?
    var name: String
    var aliases: [String] = []
    var district: String
    var districtGroup: String?
    var streetBlock: String?
    var address: String = ""
    var latitude: Double = 39.1
    var longitude: Double = 117.2
    var zoneId: UUID?
    var primarySchoolId: UUID?
    var buildYear: Int?
    var developer: String?
    var propertyMgmt: String?
    var totalBuildings: Int?
    var greeningRatio: Double?
    var parkingRatio: Double?
    var propertyFeeCents: Int?
    var landYears: Int?
    var sourceUrl: String?
    var contributedBy: String?
    var verifiedAt: Date?
    var availableUnits: String?
    var areaSegments: String?
    var priceSegments: String?
    var finishType: String?
    var deliveryTime: String?
    var isNewHouse: Bool = true
    var sourceCode: String?
    var sourceRow: Int?
    var sensitivePros: String?
    var sensitiveCons: String?
    var sensitiveSource: String?
    var sensitiveNote: String?
}
```

- [ ] **Step 6: 建 SupportSeeds + SeedBundle**

新建 `Models/Seeds/SupportSeeds.swift`:

```swift
import Foundation

/// 对应 groups.json(原 SchoolGroup)。
struct GroupSeed: Codable {
    var id: UUID
    var name: String
    var district: String
    var leadsJSON: String = "[]"
    var membersJSON: String = "[]"
    var note: String?
}

/// 对应 compound_school_match.json(原 CompoundSchoolMatch)。
struct MatchSeed: Codable {
    var id: UUID
    var compoundId: UUID
    var compoundName: String
    var district: String
    var mappedDistrict: String?
    var primaryMatchesJSON: String = "[]"
    var middleMatchesJSON: String = "[]"
    var needsManualReview: Bool = false
}

/// 对应 policies.json(原 Policy)。保险:解码留存,无下游消费。
struct PolicySeed: Codable {
    var id: UUID
    var category: String
    var name: String
    var subcategory: String?
    var sourceCode: String?
    var note: String?
    var description_: String?
    var effectiveDate: String?
    var timing: String?
    var eligibilityJSON: String?
    var docsJSON: String?
    var applicableJSON: String?
    var caveatsJSON: String?
    var rulesJSON: String?
    var rulesByDistrictJSON: String?
    var schoolsJSON: String?
    var specificSchools3yrJSON: String?
    var stepsJSON: String?
    var processJSON: String?
}

/// 对应 admission_rates.json(原 AdmissionRate)。保险:无下游消费。
struct AdmissionRateSeed: Codable {
    var id: UUID
    var district: String
    var year: Int
    var gaokaoAdmitPct: Int = 0
    var vocationalAdmitPct: Int = 0
    var sourceCode: String?
}

/// 一次启动 seed 的全部内存输入。migrator 直接消费此结构。
struct SeedBundle {
    var zones: [ZoneSeed] = []
    var schools: [SchoolSeed] = []
    var compounds: [CompoundSeed] = []
    var groups: [GroupSeed] = []
    var matches: [MatchSeed] = []
    var policies: [PolicySeed] = []          // 保险:无下游
    var admissionRates: [AdmissionRateSeed] = []  // 保险:无下游
}
```

- [ ] **Step 7: 写 DTO 单测**

新建 `PropertyAtlasTests/Models/SeedDTOTests.swift`:

```swift
import CoreLocation
import Foundation
import Testing
@testable import PropertyAtlas

@Suite("Seed DTOs")
struct SeedDTOTests {
    @Test("ZoneSeed default geometryStage is hull")
    func zoneDefaultStage() {
        let z = ZoneSeed(id: UUID(), name: "t", primaryDistrict: "和平区", geometry: "{}")
        #expect(z.geometryStage == "hull")
        #expect(z.tier == "普通")
        #expect(z.fillOpacity == 0.2)
    }

    @Test("ZoneSeed.decodeRaster parses image+corners")
    func zoneDecodeRaster() throws {
        let json = #"{"image":"和平区学片.png","corners":[[39.13,117.20],[39.13,117.22],[39.12,117.22],[39.12,117.20]]}"#
        let r = try ZoneSeed.decodeRaster(json)
        #expect(r.image == "和平区学片.png")
        #expect(r.corners.count == 4)
        #expect(r.corners[0].latitude == 39.13)
        #expect(r.corners[0].longitude == 117.20)
    }

    @Test("SchoolSeed defaults: lat/lon nil, public true")
    func schoolDefaults() {
        let s = SchoolSeed(id: UUID(), name: "Test", district: "和平区")
        #expect(s.lat == nil)
        #expect(s.lon == nil)
        #expect(s.isPublicSchool == true)
        #expect(s.type == "小学")
    }

    @Test("Seed structs are Codable round-trip")
    func codableRoundTrip() throws {
        var c = CompoundSeed(id: UUID(), name: "中海", district: "河北区")
        c.finishType = "精装"
        c.isNewHouse = false
        let data = try JSONEncoder().encode(c)
        let back = try JSONDecoder().decode(CompoundSeed.self, from: data)
        #expect(back.name == "中海")
        #expect(back.finishType == "精装")
        #expect(back.isNewHouse == false)
    }
}
```

- [ ] **Step 8: 跑 DTO 单测**

Run: `xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/SeedDTOTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`(4 tests pass)。

- [ ] **Step 9: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Entities/GeoJSONHelper.swift \
        PropertyAtlas/PropertyAtlas/Models/Seeds/ \
        PropertyAtlas/PropertyAtlas/Models/Public/LegacySchoolZone.swift \
        PropertyAtlas/PropertyAtlasTests/Models/SeedDTOTests.swift
git commit -m "feat(seed): add *Seed Codable DTOs + extract GeoJSONHelper (P9c T0)"
```

---

## Task 1: 切到 SeedBundle 直写(migrator + importer 一次切换)

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlas/States/SeedImporter.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/SeedBundleMigrateTests.swift`(新建)

两文件共享 `SeedBundle` 数据契约,必须同一任务落地才能编译。转换逻辑**内容不变**,仅把数据来源从 `ctx.fetch(FetchDescriptor<Legacy*>())` 换成 `seeds.*` 数组。

- [ ] **Step 1: 先写失败测试(新 run(seeds:in:) 入口)**

新建 `PropertyAtlasTests/DataKit/SeedBundleMigrateTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct SeedBundleMigrateTests {
    private func run(_ bundle: SeedBundle) throws -> ModelContext {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        try LegacyMigrator.run(seeds: bundle, in: ctx)
        return ctx
    }

    @Test("empty bundle creates no Dataset")
    func emptyNoOp() throws {
        let ctx = try run(SeedBundle())
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).isEmpty)
    }

    @Test("school seed → School + Dataset")
    func schoolMigrates() throws {
        var b = SeedBundle()
        var s = SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")
        s.type = "小学"; s.tier = "重点"; s.lat = 39.122; s.lon = 117.193; s.isMarketKey = true
        b.schools = [s]
        let ctx = try run(b)
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).count == 1)
        let schools = try ctx.fetch(FetchDescriptor<School>())
        #expect(schools.count == 1)
        #expect(schools.first?.grade == "重点")
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>()).filter { $0.entityType == "school" }
        #expect(defs.contains { $0.key == "isMarketKey" })
    }

    @Test("compound-school match seed → 对口小学 Edge")
    func matchMigrates() throws {
        var b = SeedBundle()
        let cid = UUID(); let sid = UUID()
        b.compounds = [CompoundSeed(id: cid, name: "x", district: "和平区")]
        var sch = SchoolSeed(id: sid, name: "鞍山道小学", district: "和平区"); sch.lat = 39.1; sch.lon = 117.2
        b.schools = [sch]
        var m = MatchSeed(id: UUID(), compoundId: cid, compoundName: "x", district: "和平区")
        m.primaryMatchesJSON = #"[{"school_id":"\#(sid.uuidString)","school_name":"鞍山道小学"}]"#
        b.matches = [m]
        let ctx = try run(b)
        let primary = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "对口小学" }
        #expect(primary.count == 1)
        #expect(primary.first?.fromId == cid)
        #expect(primary.first?.toId == sid)
    }

    @Test("seeds 4 MapViews with 7 normalFilters")
    func seedsMapViews() throws {
        var b = SeedBundle()
        b.schools = [SchoolSeed(id: UUID(), name: "x", district: "和平区")]
        let ctx = try run(b)
        let views = try ctx.fetch(FetchDescriptor<MapView>())
        #expect(views.count == 4)
        let v = try #require(views.first { $0.isActive })
        let nfs = (try? JSONDecoder().decode([NormalFilter].self, from: Data(v.normalFiltersJSON.utf8))) ?? []
        #expect(nfs.count == 7)
        #expect(nfs.contains { $0.name == "精装类型" })
        #expect(nfs.contains { $0.name == "等级" })
    }
}
```

- [ ] **Step 2: 跑测试确认失败(编译错误:run(seeds:in:) 不存在)**

Run: `xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/SeedBundleMigrateTests 2>&1 | tail -15`
Expected: 编译失败,提示 `extra argument 'seeds'` / `incorrect argument label`(`run` 仍是 `run(in:)`)。

- [ ] **Step 3: 改 LegacyMigrator.run 签名 + 守卫**

`LegacyMigrator.swift` 第 42–64 行 `run(in:)` 替换为:

```swift
static func run(seeds: SeedBundle, in ctx: ModelContext) throws {
    if try !ctx.fetch(FetchDescriptor<Dataset>()).isEmpty { return }
    let hasData = !seeds.zones.isEmpty || !seeds.schools.isEmpty || !seeds.compounds.isEmpty
    if !hasData { return }

    let dataset = Dataset(name: datasetName)
    dataset.id = stableDatasetId(name: datasetName)
    ctx.insert(dataset)
    try migrateAreas(seeds.zones, dataset: dataset, in: ctx)
    try migrateSchools(seeds.schools, dataset: dataset, in: ctx)
    try migrateCompounds(seeds.compounds, dataset: dataset, in: ctx)
    try migrateEdges(seeds, dataset: dataset, in: ctx)
    try seedEnumOptions(dataset: dataset, in: ctx)
    try seedPalettesThemesLayers(dataset: dataset, in: ctx)
    try seedCameraPresets(dataset: dataset, in: ctx)
    try ctx.save()
}
```

(删掉了 `migrateAdmissionDocs` / `migrateTags` 两行调用;`hasLegacy` fetch 块整体由 `hasData` 取代。)

- [ ] **Step 4: 各 migrate stage 改读 seed 数组(逐函数,逻辑不变)**

下列每处把"内部 `ctx.fetch(FetchDescriptor<Legacy*>())`"改为"函数入参数组",并把循环变量类型从 Legacy 类换成对应 `*Seed`(字段名完全一致,函数体其余不动):

1. `migrateAreas`(第 68 行):
   ```swift
   private static func migrateAreas(_ zones: [ZoneSeed], dataset: Dataset, in ctx: ModelContext) throws {
       for z in zones {
   ```
   (删除原 `let zones = try ctx.fetch(...)`;`z.name`/`z.geometryStage`/`z.geometry`/`z.fillOpacity`/`z.textDescription`/`z.strokeColorHex`/`z.sensitive*`/`z.residencyYears`/`z.tier`/`z.id` 均同名可用。)

2. `migrateSchools`(第 123 行):
   ```swift
   private static func migrateSchools(_ legacySchools: [SchoolSeed], dataset: Dataset, in ctx: ModelContext) throws {
       for ls in legacySchools {
   ```
   (删除 `let legacySchools = try ctx.fetch(...)`;`ls.*` 同名。)

3. `migrateCompounds`(第 225 行):
   ```swift
   private static func migrateCompounds(_ legacy: [CompoundSeed], dataset: Dataset, in ctx: ModelContext) throws {
       for lc in legacy {
   ```
   (删除 `let legacy = try ctx.fetch(...)`;`lc.*` 同名。)

4. `migrateEdges`(第 323 行):改为接收整个 bundle 并分发数组:
   ```swift
   private static func migrateEdges(_ seeds: SeedBundle, dataset: Dataset, in ctx: ModelContext) throws {
       try migrateCompoundSchoolMatches(seeds.matches, dataset: dataset, in: ctx)
       try migratePrimarySchoolId(seeds.compounds, dataset: dataset, in: ctx)
       try migrateZoneMiddleSchoolPool(seeds.zones, seeds.schools, dataset: dataset, in: ctx)
       try migrateSchoolGroups(seeds.groups, dataset: dataset, in: ctx)
       try migratePrimaryArea(seeds.compounds, seeds.schools, dataset: dataset, in: ctx)
   }
   ```

5. `migratePrimaryArea`(第 331 行):
   ```swift
   private static func migratePrimaryArea(_ compounds: [CompoundSeed], _ schools: [SchoolSeed], dataset: Dataset, in ctx: ModelContext) throws {
       let dsId = dataset.id
       for lc in compounds {
           guard let to = lc.zoneId else { continue }
           ctx.insert(Edge(datasetId: dsId, fromId: lc.id, fromType: "compound", toId: to, toType: "area", label: "所属片区", directed: true))
       }
       for ls in schools {
           guard let to = ls.zoneId else { continue }
           ctx.insert(Edge(datasetId: dsId, fromId: ls.id, fromType: "school", toId: to, toType: "area", label: "所属片区", directed: true))
       }
   }
   ```

6. `migrateCompoundSchoolMatches`(第 359 行):
   ```swift
   private static func migrateCompoundSchoolMatches(_ matches: [MatchSeed], dataset: Dataset, in ctx: ModelContext) throws {
       for m in matches {
   ```
   (删除 `let matches = try ctx.fetch(...)`;`m.primaryMatchesJSON`/`m.middleMatchesJSON`/`m.compoundId` 同名。)

7. `migratePrimarySchoolId`(第 389 行):
   ```swift
   private static func migratePrimarySchoolId(_ compounds: [CompoundSeed], dataset: Dataset, in ctx: ModelContext) throws {
       for lc in compounds {
   ```
   (删除 `let compounds = try ctx.fetch(...)`;函数体含 `#Predicate` 去重查询不变。)

8. `migrateZoneMiddleSchoolPool`(第 412 行):
   ```swift
   private static func migrateZoneMiddleSchoolPool(_ zones: [ZoneSeed], _ allSchools: [SchoolSeed], dataset: Dataset, in ctx: ModelContext) throws {
       var schoolByName: [String: SchoolSeed] = [:]
       for s in allSchools { schoolByName[s.name] = s }
       for z in zones {
   ```
   (删除两处 `try ctx.fetch(...)`;`schoolByName` 字典值类型由 `LegacySchool` 改 `SchoolSeed`;其余不变。)

9. `migrateSchoolGroups`(第 436 行):
   ```swift
   private static func migrateSchoolGroups(_ groups: [GroupSeed], dataset: Dataset, in ctx: ModelContext) throws {
       for g in groups {
   ```
   (删除 `let groups = try ctx.fetch(...)`;`g.leadsJSON`/`g.membersJSON`/`g.name` 同名。)

- [ ] **Step 5: 删除死 stage 函数**

从 `LegacyMigrator.swift` 删除整段 `migrateAdmissionDocs`(第 693–712 行)和 `migrateTags`(第 714–734 行)函数定义。(其调用已在 Step 3 移除。)`seedEnumOptions`/`seedPalettesThemesLayers`/`seedMapViews`/`seedSchoolStyleRules`/`seedCameraPresets`/`registerCustomFieldDef`/`addCustom`/`MatchEntry`/`GroupEntry`/`ViewSeed` 全部**不动**。

- [ ] **Step 6: 改 SeedImporter——import* 返回 *Seed 数组**

`SeedImporter.swift` 改动:

(a) 删除 `needsImport(_:)`(第 27–31 行)整个函数。

(b) `runIfNeeded`(第 34–104 行)替换为:

```swift
@discardableResult
static func runIfNeeded(
    into context: ModelContext,
    progress: @escaping (Double, String) -> Void = { _, _ in }
) throws -> Bool {
    // 每次启动清理无主实体(独立于 seed 守卫)
    LegacyMigrator.cleanupOrphans(in: context)
    // 已有 Dataset → 已 seed,跳过
    if try !context.fetch(FetchDescriptor<Dataset>()).isEmpty {
        progress(1.0, "已就绪")
        return false
    }

    progress(0.05, "读取 JSON")
    var bundle = SeedBundle()
    let zones = try loadJSON("zones")
    let schools = try loadJSON("schools")
    bundle.zones = parseZones(zones)
    bundle.schools = parseSchools(schools)
    if let compounds = try? loadJSON("compounds") { bundle.compounds = parseCompounds(compounds) }
    if let groups = try? loadJSON("groups") { bundle.groups = parseGroups(groups) }
    if let policies = try? loadJSON("policies") { bundle.policies = parsePolicies(policies) }
    if let admission = try? loadJSON("admission_rates") { bundle.admissionRates = parseAdmissionRates(admission) }
    if let matches = try? loadJSON("compound_school_match") { bundle.matches = parseMatches(matches) }

    progress(0.50, "聚合 zone tier")
    aggregateZoneTier(&bundle)

    progress(0.70, "迁移写入实体")
    try LegacyMigrator.run(seeds: bundle, in: context)

    progress(0.95, "保存")
    try context.save()
    progress(1.0, "完成")
    return true
}
```

(c) `aggregateZoneTier`(第 107–123 行)改为就地改 bundle:

```swift
private static func aggregateZoneTier(_ bundle: inout SeedBundle) {
    let priority = ["重点": 2, "区重点": 1, "普通": 0]
    var byZone: [UUID: [SchoolSeed]] = [:]
    for s in bundle.schools {
        guard let zid = s.zoneId else { continue }
        byZone[zid, default: []].append(s)
    }
    for i in bundle.zones.indices {
        let members = byZone[bundle.zones[i].id] ?? []
        if members.isEmpty { continue }
        let best = members.map(\.tier).max { (priority[$0] ?? 0) < (priority[$1] ?? 0) }
        bundle.zones[i].tier = best ?? "普通"
    }
}
```

(d) 七个 `importXxx(_ root:into context:)` 改名为 `parseXxx(_ root:) -> [XxxSeed]`,把 `context.insert(x)` 改为构造 `*Seed` 并 `append` 到本地数组后 `return`。解析逻辑(每个 `item["..."] as? ...`)**一字不改**,只换构造目标。例如 `parseZones`:

```swift
private static func parseZones(_ root: [String: Any]) -> [ZoneSeed] {
    guard let items = root["items"] as? [[String: Any]] else { return [] }
    var out: [ZoneSeed] = []
    for item in items {
        guard let seedId = item["id"] as? String,
              let district = item["district"] as? String,
              let zoneName = item["zone_name"] as? String
        else { continue }
        let stage = (item["geometry_stage"] as? String) ?? "hull"
        let geometryString: String
        if let geom = item["geometry"], !(geom is NSNull) {
            let data = (try? JSONSerialization.data(withJSONObject: geom)) ?? Data()
            geometryString = String(data: data, encoding: .utf8) ?? ""
        } else {
            geometryString = ""
        }
        var zone = ZoneSeed(
            id: uuid(from: seedId),
            name: zoneName,
            primaryDistrict: district,
            geometry: geometryString,
            geometryStage: stage
        )
        zone.textDescription = item["areas_text"] as? String
        zone.note = item["note"] as? String
        zone.structureJSON = encodeIfPresent(item["structure"])
        zone.middleSchoolPoolJSON = encodeIfPresent(item["middle_school_pool"])
        if let sens = item["sensitive"] as? [String: Any] {
            zone.sensitiveHighlight = sens["highlight"] as? String
            zone.sensitiveSource = sens["source"] as? String
            zone.sensitiveNote = sens["note"] as? String
        }
        out.append(zone)
    }
    return out
}
```

`parseSchools`/`parseCompounds`/`parseGroups`/`parsePolicies`/`parseAdmissionRates`/`parseMatches` 同法转换(原第 187–374 行的解析体逐行保留,把 `let x = LegacyXxx(...)` 改 `var x = XxxSeed(...)`、删 `context.insert`、改 `out.append(x)`、函数返回 `[XxxSeed]`)。`loadJSON`/`encodeIfPresent`/`coarseTierFromSensitive`/`uuid(from:)` **不动**。

> 注意:`SchoolSeed`/`CompoundSeed` 等无便利 init,用成员逐字段构造(`var x = SchoolSeed(id:name:district:)` 因为有默认值的可省;无默认值字段必须给 —— ZoneSeed 必填 `id/name/primaryDistrict/geometry`,SchoolSeed 必填 `id/name/district`,CompoundSeed 必填 `id/name/district`,GroupSeed 必填 `id/name/district`,MatchSeed 必填 `id/compoundId/compoundName/district`,PolicySeed 必填 `id/category/name`,AdmissionRateSeed 必填 `id/district/year`)。Swift 合成的逐成员 init 含默认值参数,可只传必填 + 需要的可选。

- [ ] **Step 7: build + 跑新测试**

Run: `xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/SeedBundleMigrateTests 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`(4 tests pass)。

> 旧 `LegacyMigratorTests` 此刻**编译不过**(仍调 `run(in:)`)——Task 2 修。本步只验新入口 + importer 编译通过。若想本步全绿,可临时只跑指定 suite(上面命令已限定),全量 test 放到 Task 2 之后。

- [ ] **Step 8: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift \
        PropertyAtlas/PropertyAtlas/States/SeedImporter.swift \
        PropertyAtlasTests/DataKit/SeedBundleMigrateTests.swift
git commit -m "refactor(seed): single-launch direct write — run(seeds:) reads SeedBundle (P9c T1)"
```

---

## Task 2: 删 Legacy* @Model + 迁移旧测试

**Files:**
- Delete: `Models/Public/{LegacyCompound,LegacySchool,LegacySchoolZone,LegacyAdmissionDoc,SchoolGroup,CompoundSchoolMatch,Policy,AdmissionRate,SchoolScore,BuiltinTag}.swift`
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift`
- Modify: `PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`
- Modify: `PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift`
- Modify: `PropertyAtlasTests/Studio/SchoolModelGeocodeTests.swift`

- [ ] **Step 1: 从 ModelSchema.allTypes 移除 10 类**

`ModelSchema.swift` 第 20–24 行那段删掉(整块 "Legacy ... SchoolScore.self," 共 4 行),`allTypes` 只保留 New core/entities/style/display/schema/media + User/*。改后:

```swift
    static let allTypes: [any PersistentModel.Type] = [
        // New core
        Dataset.self, Edge.self, Tag.self, CameraPreset.self,
        // New entities
        Compound.self, School.self, POI.self, Area.self,
        // New style
        StyleRule.self, Palette.self, Theme.self,
        // New display
        Layer.self, MapView.self,
        // New schema registry
        CustomFieldDef.self, EnumOption.self,
        // New media
        Photo.self, Document.self,
        // User/* (orthogonal)
        VisitPhoto.self, PropertyMark.self, Visit.self, TagExtension.self,
        VisitTag.self, UserArea.self, ShareSubmission.self,
    ]
```

并把第 5 行注释 `+ Legacy* (for LegacyMigrator)` 去掉。

- [ ] **Step 2: 删 10 个 Legacy* 文件**

```bash
git rm PropertyAtlas/PropertyAtlas/Models/Public/LegacyCompound.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/LegacySchool.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/LegacySchoolZone.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/LegacyAdmissionDoc.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/SchoolGroup.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/CompoundSchoolMatch.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/Policy.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/AdmissionRate.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/SchoolScore.swift \
       PropertyAtlas/PropertyAtlas/Models/Public/BuiltinTag.swift
```

> 注:`LegacySchoolZone.swift` Task 0 已摘走 `GeoJSONHelper`,此处删除安全。删除后若有遗留引用,Step 4 build 会报错;此时 grep `grep -rn "LegacyCompound\|LegacySchool\|LegacySchoolZone\|LegacyAdmissionDoc\|SchoolGroup\|CompoundSchoolMatch\|\bPolicy\b\|AdmissionRate\|SchoolScore\|BuiltinTag" PropertyAtlas/PropertyAtlas` 找漏网(应只剩 SeedImporter/Migrator 已无引用)。

- [ ] **Step 3: 迁移 LegacyMigratorTests 到 SeedBundle**

`LegacyMigratorTests.swift` 全量重写为喂 `SeedBundle` + `run(seeds:in:)`。**删除**两个用例:`migrateConvertsAdmissionDocsToDocuments`、`migrateConvertsBuiltinTagsToTags`(stage 已删)。其余用例改造模式:把 `let x = LegacyXxx(...); ctx.insert(x); ... try ctx.save(); try LegacyMigrator.run(in: ctx)` 改为 `var b = SeedBundle(); b.xxx = [XxxSeed(...)]; try LegacyMigrator.run(seeds: b, in: ctx)`。完整新内容:

```swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LegacyMigratorTests {
    private func newCtx() throws -> ModelContext {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        return ModelContext(container)
    }

    @Test func migrateCreatesTianjinDemoDatasetWhenDataExists() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: UUID(), name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.count == 1)
        #expect(datasets.first?.name == "天津 demo")
    }

    @Test func migrateIsIdempotent() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: UUID(), name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)]
        try LegacyMigrator.run(seeds: b, in: ctx)
        try LegacyMigrator.run(seeds: b, in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).count == 1)
    }

    @Test func migrateNoOpWhenEmptyBundleAndNoDataset() throws {
        let ctx = try newCtx()
        try LegacyMigrator.run(seeds: SeedBundle(), in: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).isEmpty)
    }

    @Test func migrateConvertsSchoolsToNewSchools() throws {
        let ctx = try newCtx()
        var s = SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")
        s.type = "小学"; s.tier = "重点"; s.lat = 39.122; s.lon = 117.193
        s.isMarketKey = true; s.communitiesText = "静安社区..."; s.foundedYear = 1954
        var b = SeedBundle(); b.schools = [s]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let schools = try ctx.fetch(FetchDescriptor<School>())
        #expect(schools.count == 1)
        let sc = try #require(schools.first)
        #expect(sc.name == "鞍山道小学")
        #expect(sc.category == "小学")
        #expect(sc.grade == "重点")
        #expect(sc.form == "普通")
        #expect(sc.latitude == 39.122)
        #expect(sc.foundYear == 1954)
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>()).filter { $0.entityType == "school" }
        #expect(defs.contains { $0.key == "isMarketKey" })
    }

    @Test func migrateConvertsCompoundsToNewCompounds() throws {
        let ctx = try newCtx()
        var c = CompoundSeed(id: UUID(), name: "中海西派国印", district: "河北区", latitude: 39.155, longitude: 117.190)
        c.buildYear = 2022; c.developer = "中海"; c.propertyMgmt = "中海物业"; c.propertyFeeCents = 580
        c.finishType = "毛坯/精装"; c.deliveryTime = "现房"; c.isNewHouse = true
        c.availableUnits = "10-50"; c.areaSegments = "105,125"; c.priceSegments = "现房105精装"
        c.sourceCode = "YH-XLSX"; c.amapPoiId = "B0FFK1H7MQ"; c.greeningRatio = 35.0
        c.sensitivePros = "现房, 即买即住"; c.sensitiveCons = "价格高"
        var b = SeedBundle(); b.compounds = [c]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let compounds = try ctx.fetch(FetchDescriptor<Compound>())
        #expect(compounds.count == 1)
        let cc = try #require(compounds.first)
        #expect(cc.name == "中海西派国印")
        #expect(cc.buildYear == 2022)
        #expect(cc.propertyFeeCents == 580)
        #expect(cc.finishType == "毛坯/精装")
        #expect(cc.privateNotes?.contains("现房") == true)
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>()).filter { $0.entityType == "compound" }
        #expect(defs.contains { $0.key == "sourceCode" })
        #expect(defs.contains { $0.key == "amapPoiId" })
        #expect(defs.contains { $0.key == "greeningRatio" })
    }

    @Test func migrateConvertsZonesToAreas() throws {
        let ctx = try newCtx()
        var z = ZoneSeed(
            id: UUID(), name: "第一学片", primaryDistrict: "和平区",
            geometry: #"{"type":"Polygon","coordinates":[[[117.1,39.1],[117.2,39.1],[117.2,39.2],[117.1,39.2],[117.1,39.1]]]}"#
        )
        z.tier = "重点"; z.residencyYears = 3; z.fillOpacity = 0.3; z.textDescription = "包含...居委会"
        var b = SeedBundle()
        b.zones = [z]
        b.compounds = [CompoundSeed(id: UUID(), name: "dummy", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let areas = try ctx.fetch(FetchDescriptor<Area>())
        let area = try #require(areas.first { $0.name == "第一学片" })
        #expect(area.geometryKind == "polygon")
        #expect(area.fillOpacity == 0.3)
        #expect(area.textDescription == "包含...居委会")
        let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
        #expect(defs.contains { $0.key == "residencyYears" })
        #expect(defs.contains { $0.key == "tier" })
    }

    @Test func migrateConvertsMatchToEdges() throws {
        let ctx = try newCtx()
        let cid = UUID(); let sid = UUID()
        var sch = SchoolSeed(id: sid, name: "鞍山道小学", district: "和平区"); sch.tier = "重点"; sch.lat = 39.12; sch.lon = 117.19
        var m = MatchSeed(id: UUID(), compoundId: cid, compoundName: "x", district: "和平区")
        m.primaryMatchesJSON = #"[{"school_id":"\#(sid.uuidString)","school_name":"鞍山道小学","match_kind":"name"}]"#
        var b = SeedBundle()
        b.compounds = [CompoundSeed(id: cid, name: "x", district: "和平区")]
        b.schools = [sch]; b.matches = [m]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let primary = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "对口小学" }
        #expect(primary.count == 1)
        #expect(primary.first?.fromId == cid)
        #expect(primary.first?.toId == sid)
        #expect(primary.first?.directed == true)
    }

    @Test func migrateConvertsGroupToEdges() throws {
        let ctx = try newCtx()
        let leaderId = UUID(); let memberId = UUID()
        var leader = SchoolSeed(id: leaderId, name: "实验中学", district: "和平区"); leader.type = "初中"; leader.lat = 39.1; leader.lon = 117.2
        var member = SchoolSeed(id: memberId, name: "实验中学分校", district: "和平区"); member.type = "初中"; member.lat = 39.11; member.lon = 117.21
        var g = GroupSeed(id: UUID(), name: "实验集团", district: "和平区")
        g.leadsJSON = #"[{"name":"实验中学","school_id":"\#(leaderId.uuidString)"}]"#
        g.membersJSON = #"[{"name":"实验中学分校","school_id":"\#(memberId.uuidString)"}]"#
        var b = SeedBundle()
        b.schools = [leader, member]; b.groups = [g]
        b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let edges = try ctx.fetch(FetchDescriptor<Edge>())
        #expect(edges.contains { $0.label == "集团成员" && $0.fromId == leaderId && $0.toId == memberId })
    }

    @Test func migrateConvertsZonePoolToEdges() throws {
        let ctx = try newCtx()
        let mid = UUID()
        var middle = SchoolSeed(id: mid, name: "耀华中学", district: "和平区"); middle.type = "初中"; middle.tier = "重点"; middle.lat = 39.12; middle.lon = 117.19
        var z = ZoneSeed(
            id: UUID(), name: "第一学片", primaryDistrict: "和平区",
            geometry: #"{"type":"Polygon","coordinates":[[[117,39],[118,39],[118,40],[117,40],[117,39]]]}"#
        )
        z.tier = "重点"; z.middleSchoolPoolJSON = #"["耀华中学"]"#
        var b = SeedBundle()
        b.schools = [middle]; b.zones = [z]
        b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let pool = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "片内中学" && $0.fromType == "area" }
        #expect(pool.count == 1)
        #expect(pool.first?.toId == mid)
    }

    @Test func migratesPrimaryAreaToEdge() throws {
        let ctx = try newCtx()
        let zid = UUID(); let cid = UUID(); let sid = UUID()
        var z = ZoneSeed(id: zid, name: "和平一片区", primaryDistrict: "和平区", geometry: "")
        var c = CompoundSeed(id: cid, name: "测试小区", district: "和平区"); c.zoneId = zid
        var s = SchoolSeed(id: sid, name: "测试小学", district: "和平区"); s.zoneId = zid
        var b = SeedBundle(); b.zones = [z]; b.compounds = [c]; b.schools = [s]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let edges = try ctx.fetch(FetchDescriptor<Edge>()).filter { $0.label == "所属片区" }
        #expect(edges.contains { $0.fromId == cid && $0.toId == zid && $0.fromType == "compound" })
        #expect(edges.contains { $0.fromId == sid && $0.toId == zid && $0.fromType == "school" })
    }

    @Test func migrateSeedsDefaultEnumOptions() throws {
        let ctx = try newCtx()
        var b = SeedBundle(); b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let enums = try ctx.fetch(FetchDescriptor<EnumOption>())
        let scopes = Set(enums.map(\.scope))
        #expect(scopes.contains("school.category"))
        #expect(scopes.contains("school.grade"))
        #expect(scopes.contains("edge.label"))
        #expect(scopes.contains("area.category"))
        let cat = enums.filter { $0.scope == "school.category" }.map(\.label)
        #expect(cat.contains("小学"))
    }

    @Test func migrateSeedsPalettesThemesAndLayer() throws {
        let ctx = try newCtx()
        var b = SeedBundle(); b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let names = Set(try ctx.fetch(FetchDescriptor<Palette>()).map(\.name))
        #expect(names.contains("default-rainbow"))
        let themes = try ctx.fetch(FetchDescriptor<Theme>())
        #expect(themes.contains { $0.name == "字段总览" })
        #expect(themes.contains { $0.name == "新房地图" })
        let layers = try ctx.fetch(FetchDescriptor<Layer>())
        #expect(layers.contains { $0.isDefault && $0.name == "全部" })
        #expect(try ctx.fetch(FetchDescriptor<Dataset>()).first?.activeThemeId != nil)
    }

    @Test func migrateSeedsCameraPresets() throws {
        let ctx = try newCtx()
        var b = SeedBundle(); b.compounds = [CompoundSeed(id: UUID(), name: "x", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let presets = try ctx.fetch(FetchDescriptor<CameraPreset>())
        #expect(Set(presets.map(\.name)) == ["和平区", "河西区", "南开区", "河东区", "河北区", "红桥区"])
        let heping = try #require(presets.first { $0.name == "和平区" })
        #expect(heping.centerLat == 39.125)
        #expect(heping.distance == 12000)
    }

    @Test func datasetIdIsStableAcrossRuns() throws {
        func runOnce() throws -> UUID {
            let ctx = try newCtx()
            var b = SeedBundle()
            b.schools = [SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")]
            try LegacyMigrator.run(seeds: b, in: ctx)
            return try #require(try ctx.fetch(FetchDescriptor<Dataset>()).first).id
        }
        #expect(try runOnce() == runOnce())
    }

    @Test func seedsSchoolStyleRulesAndAttachesToThemes() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.schools = [SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let rules = try ctx.fetch(FetchDescriptor<StyleRule>()).filter { $0.entityType == "school" }
        #expect(rules.contains { $0.appliesGlyph == "重" })
        #expect(rules.contains { $0.appliesGlyph == "普" })
        let overview = try #require(try ctx.fetch(FetchDescriptor<Theme>()).first { $0.name == "字段总览" })
        #expect(!overview.styleRuleIds.isEmpty)
    }

    @Test func seedsMapViewsWithDefaults() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.schools = [SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let views = try ctx.fetch(FetchDescriptor<MapView>())
        #expect(views.count == 4)
        let v = try #require(views.first { $0.isActive })
        #expect(!v.enabledLayerIds.isEmpty)
        #expect(v.paletteId != nil)
        #expect((try? JSONDecoder().decode(PrimaryFilter.self, from: Data(v.primaryFilterJSON.utf8))) != nil)
        let nfs = (try? JSONDecoder().decode([NormalFilter].self, from: Data(v.normalFiltersJSON.utf8))) ?? []
        #expect(nfs.count == 7)
        #expect(nfs.contains { $0.name == "精装类型" })
        #expect(nfs.contains { $0.name == "等级" })
    }

    @Test func seededMapViewHasVisibilityJSON() throws {
        let ctx = try newCtx()
        var b = SeedBundle()
        b.schools = [SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")]
        try LegacyMigrator.run(seeds: b, in: ctx)
        let v = try #require(try ctx.fetch(FetchDescriptor<MapView>()).first { $0.isActive })
        let obj = try #require(try? JSONSerialization.jsonObject(with: Data(v.visibilityJSON.utf8)) as? [String: Bool])
        #expect(obj["school"] != nil)
    }
}
```

- [ ] **Step 4: 迁移 ZoneGeometryImporterTests + SchoolModelGeocodeTests**

`ZoneGeometryImporterTests.swift` 全量替换:

```swift
import CoreLocation
import Foundation
import Testing
@testable import PropertyAtlas

@Suite("ZoneSeed geometry stage")
struct ZoneSeedGeometryStageTests {
    @Test("default stage is hull")
    func defaultStage() {
        let z = ZoneSeed(id: UUID(), name: "test", primaryDistrict: "和平区", geometry: "{}")
        #expect(z.geometryStage == "hull")
    }

    @Test("decodeRaster parses image+corners")
    func decodeRaster() throws {
        let json = #"{"image":"和平区学片.png","corners":[[39.13,117.20],[39.13,117.22],[39.12,117.22],[39.12,117.20]]}"#
        let r = try ZoneSeed.decodeRaster(json)
        #expect(r.image == "和平区学片.png")
        #expect(r.corners.count == 4)
        #expect(r.corners[0].latitude == 39.13)
        #expect(r.corners[0].longitude == 117.20)
    }
}
```

`SchoolModelGeocodeTests.swift` 全量替换:

```swift
import Foundation
import Testing
@testable import PropertyAtlas

@Suite("SchoolSeed geocode fields")
struct SchoolSeedGeocodeTests {
    @Test("accepts lat/lon/geocodeSource/geocodeConfidence")
    func acceptsGeocode() {
        var s = SchoolSeed(id: UUID(), name: "鞍山道小学", district: "和平区")
        s.lat = 39.1234; s.lon = 117.1234
        s.geocodeSource = "CLGeocoder"; s.geocodeConfidence = "address"
        #expect(s.lat == 39.1234)
        #expect(s.geocodeConfidence == "address")
    }

    @Test("default lat/lon nil")
    func defaultsNil() {
        let s = SchoolSeed(id: UUID(), name: "Test", district: "和平区")
        #expect(s.lat == nil)
        #expect(s.lon == nil)
    }
}
```

> 这两套与 Task 0 的 `SeedDTOTests` 部分重叠。保留它们(套件名不同,不冲突),作为旧测试的等价迁移而非删除——避免覆盖率回退。

- [ ] **Step 5: 全量 build + test**

Run: `xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -15`
Expected: `** TEST SUCCEEDED **`(除已知 flaky `testLaunchPerformance` 外全绿)。若报 "Cannot find 'LegacyXxx'",grep 修残留引用。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(model): delete 10 Legacy* @Model; migrate tests to *Seed (P9c T2)"
```

---

## Task 3: 清库重迁 smoke(1 次启动)+ CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 确认 app 未运行 + 备份并清库**

> ⚠️ 破坏性操作。先备份再删。需用户确认 app 已退出(若由控制者执行,在终端确认无 PropertyAtlas 进程)。

```bash
pkill -x PropertyAtlas 2>/dev/null; sleep 1
STORE="$HOME/Library/Application Support/default.store"
BK="$HOME/Library/Application Support/propatlas-store-backup-$(date +%Y%m%d-%H%M)-p9c"
mkdir -p "$BK"
cp "$STORE" "$STORE-shm" "$STORE-wal" "$BK"/ 2>/dev/null
rm -f "$STORE" "$STORE-shm" "$STORE-wal"
echo "backed up to $BK; store removed"
```

- [ ] **Step 2: build worktree app + 取确切产物路径**

```bash
xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -3
DIR=$(xcodebuild -showBuildSettings -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR /{print $3}')
echo "APP=$DIR/PropertyAtlas.app/Contents/MacOS/PropertyAtlas"
```

- [ ] **Step 3: 一次启动完成 seed+migrate(P9c 的核心收益:不再需要两次)**

后台跑该 app 二进制约 25s 后 kill(前台 sleep 被禁,用后台任务):

```bash
APP="$DIR/PropertyAtlas.app/Contents/MacOS/PropertyAtlas"
"$APP" >/tmp/p9c-launch.log 2>&1 &
PID=$!; sleep 25; kill $PID 2>/dev/null; sleep 2
echo "launch done"
```

- [ ] **Step 4: SQLite 验证(一次启动后即应完整)**

```bash
STORE="$HOME/Library/Application Support/default.store"
echo "--- Legacy tables (应全无) ---"
sqlite3 "$STORE" ".tables" | tr ' ' '\n' | grep -iE 'ZLEGACY|ZSCHOOLGROUP|ZCOMPOUNDSCHOOLMATCH|ZPOLICY|ZADMISSIONRATE|ZSCHOOLSCORE|ZBUILTINTAG' || echo "(none — 正确)"
echo "--- 实体数 ---"
for t in ZCOMPOUND ZSCHOOL ZAREA ZMAPVIEW; do echo -n "$t="; sqlite3 "$STORE" "SELECT COUNT(*) FROM $t;"; done
echo "--- normalFilters per view ---"
sqlite3 "$STORE" "SELECT ZNAME, (LENGTH(ZNORMALFILTERSJSON)-LENGTH(REPLACE(ZNORMALFILTERSJSON,'\"name\"',''))) / LENGTH('\"name\"') FROM ZMAPVIEW;"
echo "--- crash check ---"
grep -i "fatal\|crash\|exception" /tmp/p9c-launch.log || echo "(no crash)"
```

Expected:① Legacy 表全无;② ZCOMPOUND=174、ZSCHOOL=823、ZAREA=101、ZMAPVIEW=4;③ 4 视图各 7 normals;④ 无 crash。

> 若实体数为 0:可能一次启动 25s 不足以完成 seed(数据量大)。延长到 40s 重跑 Step 3。仍为 0 再排查(查 /tmp/p9c-launch.log)。

- [ ] **Step 5: 更新 CLAUDE.md**

在 CLAUDE.md 的计划列表把 "P9c 计划: 待写..." 行替换为已完成节点,并在 P9b 节点后追加 P9c 节点(风格对齐既有 `> **P9b ...` 块):

```markdown
> **P9c (2026-06-02) 完成后**: seed 管线直写 + 删 Legacy* @Model。Legacy* 及供给类(10 类)从
> @Model 降级为 `*Seed` Codable struct(`ZoneSeed`/`SchoolSeed`/`CompoundSeed`/`GroupSeed`/`MatchSeed`/
> `PolicySeed`/`AdmissionRateSeed`,`Models/Seeds/`,移出 ModelSchema)；死代码 `LegacyAdmissionDoc`/
> `BuiltinTag`/`SchoolScore` + `migrateAdmissionDocs`/`migrateTags` 两 stage 直接删。`GeoJSONHelper` 抽到
> `Models/Entities/GeoJSONHelper.swift`(Area/UserArea 依赖)。`SeedImporter` 用现有 dict 解析装 `SeedBundle`,
> `LegacyMigrator.run(in:)` → `run(seeds:in:)` 改读内存数组,转换逻辑不变;删 `needsImport` guard。
> **一次启动**即完成 seed+migrate(原两次)。清库重迁 smoke 验:Legacy 表全无、实体数不变(174/823/101)、
> ZMAPVIEW=4 各 7 normals、无 crash。CloudKit 仍延后(Catalyst `.none`)。后续 P9 余项:
> Theme/StyleRule/CameraPreset/CustomFieldDef 编辑器、逐实体-逐图层 theme 解析。
```

同时把列表行 `- P9c 计划: 待写 ...` 改为 `- 实施计划 P9c (已完成): \`docs/superpowers/plans/2026-06-02-p9c-seed-pipeline-direct-write.md\``。

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): note P9c seed pipeline direct-write completion"
```

---

## Self-Review(写计划者自检结论)

1. **Spec coverage**:① 一次启动直写 → T1 run(seeds:)+importer;② Legacy*→*Seed 重命名(7)→ T0+T2;③ 死代码删除(3 类 + 2 stage)→ T1 Step5 + T2;④ DTO 保险层(policies/admissionRates)→ T0 SupportSeeds + importer parse;⑤ ModelSchema 移除 → T2;⑥ GeoJSONHelper 保命搬迁 → T0;⑦ 测试迁移 → T2;⑧ 1 次启动 smoke → T3。全覆盖。
2. **Placeholder scan**:无 TBD/TODO;每代码步给完整代码或精确逐行 diff 指令。
3. **Type consistency**:`run(seeds: SeedBundle, in:)` 在 T1/T2/T3 一致;`*Seed` 字段名 = 原 Legacy* 字段名(逐字段核对 importer 设值点 + migrator 读取点);`SeedBundle` 字段 `zones/schools/compounds/groups/matches/policies/admissionRates` 在 importer/migrator/tests 一致。
4. **风险点**:T1 是最大改动(2 文件原子切换),已给逐函数精确 diff;migrator 转换体一字不改,仅换数据源,降低回归面。
