# P9c 设计:删 Legacy* @Model + seed 管线直写(方案 B)

> Spec 日期:2026-06-02。承接 P9b。执行用 superpowers:writing-plans → subagent-driven-development。

## 目标

把"JSON → Legacy* @Model(存库)→ LegacyMigrator → 正式实体"的**两次启动**管线,压成**一次启动直写**:JSON 解码进内存 DTO,直接转换写正式实体。同时删除全部废弃 `@Model`(Legacy* + 供给类),它们只剩中转作用,正式实体早已接管真实数据。

**非目标**:不改"公共种子来自打包 JSON、运行时读 DB"这一大架构(CLAUDE.md 数据流水线设计不动);不动 CloudKit(Catalyst 保持 `.none`,iOS 上手再说);不改任何硬编码 seed(EnumOption/Palette/Theme/Layer/StyleRule/MapView/CameraPreset)的内容。

## 背景:为什么现在是两次启动

`Legacy*` 类身兼两职——既是 JSON 解码的接收容器(字段对得上 JSON),又是 `@Model`(存进 DB 的表)。因为它持久化了,转换成正式实体得等下一次启动(migrator guard 检测 Dataset 是否存在)才跑。这是清库重迁要开两遍 app 的根因。

**方案 B**:把 Legacy* 从 `@Model class` 降级为纯 `Codable struct`(不进库的内存 DTO),migrator 改读传入的 DTO 数组而非 `ctx.fetch`。两个文件分工(SeedImporter / LegacyMigrator)保留,风险最小。

## 架构

### 新管线形状(一次启动)

```
SeedImporter.runIfNeeded(into:progress:)
  guard: 若 Dataset 已存在 → 整段跳过(return)
  ├─ 解码 7 JSON ──▶ SeedBundle { zones:[ZoneSeed], schools:[SchoolSeed], ... } (内存,不进库)
  ├─ aggregateZoneTier(&bundle)  在 DTO 数组上跑(max-tier 聚合)
  ├─ LegacyMigrator.run(seeds: bundle, dataset:, in: ctx)  ──▶ 直接写正式实体
  └─ ctx.save()
```

- 删除旧 `needsImport()`(查 `LegacySchoolZone` 行数的 guard)。新 guard 只有"`Dataset` 存在"一个,放在 `runIfNeeded` 开头。
- `LegacyMigrator.cleanupOrphans(in:)` 不变,继续每次启动跑(独立于 seed guard)。
- `devSourceDir` 热重载路径不变。

### DTO 层(对应 JSON schema 的模型集,"防万一"保险)

Legacy* 及供给类:`@Model final class` → `struct: Codable`,字段照旧对着 JSON,**移出 `ModelSchema.allTypes`**(不再是 DB 表)。**重命名**为语义清晰的 `*Seed`。新建文件夹 `PropertyAtlas/DataKit/Seeds/`(或 `Models/Seeds/`,执行时按既有约定定)。

| 新 DTO 名(原名) | JSON 源 | 喂 migrator? | 下游 |
|---|---|---|---|
| `CompoundSeed`(LegacyCompound) | compounds.json | ✅ | Compound + Edges(对口小学/所属片区) |
| `SchoolSeed`(LegacySchool) | schools.json | ✅ | School + Edges(片内中学/所属片区) |
| `ZoneSeed`(LegacySchoolZone) | zones.json | ✅ | Area + Edges |
| `GroupSeed`(SchoolGroup) | groups.json | ✅ | Edge "集团成员" |
| `MatchSeed`(CompoundSchoolMatch) | compound_school_match.json | ✅ | Edge "对口小学"/"片内中学" |
| `PolicySeed`(Policy) | policies.json | ❌ 留作保险 | 无 |
| `AdmissionRateSeed`(AdmissionRate) | admission_rates.json | ❌ 留作保险 | 无 |

DTO 须完整保留原 Legacy* 的全部字段(含 sensitive* 字段)+ 解码辅助方法(如 `ZoneSeed.decodedCoordinates`/`decodeRaster`/内嵌 `GeoJSONHelper`,从 LegacySchoolZone 原样搬来)。`PolicySeed`/`AdmissionRateSeed` 仍解码(`SeedImporter` 读入 bundle)但不传给任何 migrate stage——保证 JSON schema 在代码里有对应、可供未来取用。

### 直接删除(无 JSON 源,死代码,无需 DTO)

经全工程 grep 确认从未被构造、无下游消费:

- `LegacyAdmissionDoc`(无 admission_docs.json;`migrateAdmissionDocs` fetch 恒 0,Document seeding 一直 no-op)→ 删类 + 删 `migrateAdmissionDocs` stage + 从 `run()` 摘掉调用。
- `BuiltinTag`(从未构造;`migrateTags` fetch 恒 0,no-op)→ 删类 + 删 `migrateTags` stage + 摘调用。
- `SchoolScore`(仅 @Model 声明 + schema 条目 + 注释,无构造无读取)→ 删类。

三者均从 `ModelSchema.allTypes` 移除。

### Migrator 改动

- `run()` → `run(seeds: SeedBundle, dataset: Dataset, in ctx: ModelContext)`。Dataset 检测/创建逻辑:由 `SeedImporter` 在 guard 处用 `stableDatasetId` 创建并传入(或 migrator 内建,执行时择一,保持 `stableDatasetId` 行为不变)。
- 各 migrate stage 把 `try ctx.fetch(FetchDescriptor<LegacyXxx>())` 改为读 `seeds.xxx`(DTO 数组)。转换逻辑(几何解析、自定义字段抽取、5 个 edge 子 stage:对口小学/片内中学/集团成员/所属片区)**内容不变**,仅数据来源从持久化 fetch 改为内存数组。
- 硬编码 stage(`seedEnumOptions`/`seedPalettesThemesLayers`/`seedCameraPresets`/`seedMapViews`)完全不动。
- `stableDatasetId`、`cleanupOrphans` 不动。

`SeedBundle` 结构:
```swift
struct SeedBundle {
    var zones: [ZoneSeed]
    var schools: [SchoolSeed]
    var compounds: [CompoundSeed]
    var groups: [GroupSeed]
    var matches: [MatchSeed]
    // policies / admissionRates 解码后留在此或丢弃(无下游);保险起见保留字段:
    var policies: [PolicySeed]
    var admissionRates: [AdmissionRateSeed]
}
```

## 数据流

```
bundle JSON ──Codable──▶ SeedBundle (内存)
                            │ aggregateZoneTier
                            ▼
                     LegacyMigrator.run(seeds:)
                            │  (geometry / custom fields / edges / 硬编码 seed)
                            ▼
                  正式 @Model 实体 ──save──▶ DB(SwiftData)
                            │
                运行时全程读 DB,不再碰 JSON(除非清库)
```

## 错误处理

- JSON 缺失/解码失败:沿用现有 `bundleResourceMissing` / decode 抛错路径,`SeedProgressView` 已有错误展示。可选 JSON(groups/policies/admission_rates/compound_school_match)缺失时按现状容错跳过(空数组)。
- guard 幂等:`Dataset` 存在即跳过全部 seed+migrate,零开销。

## 测试

- **迁移受影响单测**:
  - `ZoneGeometryImporterTests`:`LegacySchoolZone(...).decodeRaster()` → `ZoneSeed(...).decodeRaster()`。
  - `SchoolModelGeocodeTests`:`LegacySchool(...)` → `SchoolSeed(...)`。
  - `LegacyMigratorTests`:依赖"持久化 Legacy 行 + fetch"的用例改为"构造 DTO 数组 + `run(seeds:)`";断言不变(实体数、Edge 数、enum/palette/theme/mapview seed、7 normals)。
- **新增单测**:`SeedBundle` 解码——喂样例 JSON,断言 DTO 字段映射正确(至少 zones/schools/compounds 各一例 + 一个 sensitive 字段)。
- **清库重迁 smoke(关键收益验证)**:现在**只需启动 1 次**。验:① 实体数不变(ZCOMPOUND=174/ZSCHOOL=823/ZAREA=101);② ZMAPVIEW=4 且各视图 normalFiltersJSON 解出 7 项;③ 被删的 Legacy 表(ZLEGACYCOMPOUND/ZLEGACYSCHOOL/ZLEGACYSCHOOLZONE/ZLEGACYADMISSIONDOC/ZSCHOOLGROUP/ZCOMPOUNDSCHOOLMATCH/ZPOLICY/ZADMISSIONRATE/ZSCHOOLSCORE/ZBUILTINTAG)全部不存在;④ 无 crash。备份 `default.store` 后再删(遵循 CLAUDE.md 备份约束)。

## 验证执行前需 grep 确认的细节(交给 plan)

- `district_bboxes.json` 当前是否被任何代码消费(camera preset 据查是硬编码;若该 JSON 无消费,P9c 不引入新依赖,保持现状)。
- `SeedImporter` 里 `aggregateZoneTier` 当前对 `@Model` 的依赖点,改为对 DTO 数组的就地 mutate。
- Dataset 创建时机(SeedImporter vs Migrator)二选一,确保 `stableDatasetId("天津 demo")` 派生值不变。

## 影响面小结

- **删**:10 个废弃 @Model 中的 3 个无源类(LegacyAdmissionDoc/BuiltinTag/SchoolScore)整体删除;另 7 个降级为 `*Seed` struct。`migrateAdmissionDocs`/`migrateTags` 两 stage 删除。`needsImport()` guard 删除。
- **改**:`SeedImporter`(解码进 DTO + 传 migrator,删 Legacy 写库路径)、`LegacyMigrator.run` 签名 + 各 stage 数据源、`ModelSchema.allTypes`(移除 10 类)。
- **不动**:正式实体、硬编码 seed 内容、StyleResolver/渲染、Studio UI、CloudKit 配置、JSON 文件本身。
- **收益**:清库重迁 1 次启动;schema 去掉 10 张冗余表;"JSON 输入"在代码里有清晰 DTO 对应。
