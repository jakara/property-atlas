# Studio Mode (Mac Catalyst)

Studio Mode 把 PropertyAtlas 扩展为 Mac 端学区图截屏工具。仅 Mac Catalyst 编译 (`#if targetEnvironment(macCatalyst)`)；iPad/iPhone 不参与。

**Mac 端默认进 Studio** (`AppMode(.studio)`, iPad 仍 `.explore`)。`⌘⇧S` 切换。

## 架构约束 (spec §3.5)
- ❌ Studio 不写 `pub_*` / `usr_*`（只读消费 SwiftData 种子）
- ✅ Studio 写 `loc_*` (本地, 不同步 CloudKit)
- ❌ Mac 端不开 CloudKit (`ModelConfiguration` 在 `targetEnvironment(macCatalyst)` 下不带 cloudKitDatabase)

## 数据先决条件
- `schools.json` 各条目要有 `lat`/`lon`：`swift scripts/geocode_schools.swift` (约 14 分钟, 1 req/sec)
- `zones.json` 各条目要有 `geometry_stage`+`geometry`：
  - Stage A (raster, 手描)：`cd scripts/calibrate_raster && swift run Calibrator <district>` (18 区每个约 5 分钟)
  - Stage B (convex/alpha hull, 自动)：`python3 scripts/build_zone_hulls.py`（保留 Stage A，覆盖 hull）
  - Stage C (街道 GeoJSON, 未来)

## Studio 输出
- 4K PNG → `~/Pictures/PropertyAtlas/<district>学片图_<YYYYMMDD_HHmm>.png`
- 6 种画布比例: 16:9 / 1:1 / 4:5 / 9:16 / 3:4 / 2:1
- 录屏由 CleanShot / ScreenStudio 等外部工具完成

## Studio UI 布局
- Map 全屏 (ignoresSafeArea)
- 左上 `StudioLegend` (200pt 宽, 固定)
- 右上 `SchoolDetailCard` (320pt, 选中 pin 时浮出)
- 底部 `StudioToolbar` (图层/比例/⌘⇧R 重载/⌘E 截屏)
- 标题/水印 component 保留但默认不画 (snapshot 仍可用)

## Pin 三通道编码
| 通道 | 维度 | 值 |
|---|---|---|
| **颜色** | 学片 (zone) | viewport-aware: 同屏 visible zones index → `ZoneColorPalette.colors[i % 8]` (ColorBrewer Set1, 高对比) |
| **形状** | level / 九年一贯 | `isJiunian` → 六边形 (CAShapeLayer); `小学` → 圆; `初中` → 圆角方 |
| **glyph 字** | tier | "重" / "区" / "普" (白字, dot 内) |

Pin + nameplate 同色 (= zone color). Nameplate 显隐由 toolbar `学校名牌` toggle。

## Zone 显示名
`ZoneShortLabel.displayName(district, zoneName)`:
- 学区/学片 → `和平一片` / `河西二片`
- "(北片)/(中片)/(南片)" → `南开北片`
- 带 "-" 郊区 → `津南-七`
- 全区招生/特殊学校 → `和平·特殊学校` (district + "·" + 完整 zoneName)

## Legend 行为
- **学片行**: 视图内 (viewport bbox 内有学校的) zones 动态列出, 每行 `[色块] <displayName> ──── <count>`
- count = **全 zone 内符合 filter 的学校数** (不限 viewport, 仅 filter)
- **不可点过滤** (信息性)
- **类型行**: 小学 (○) / 初中 (▢) / 九年一贯 (⬡) — 可点过滤
- **梯队行**: 重 / 区 / 普 — 可点过滤
- 关掉某行 → opacity 0.4 + eye.slash 图标

## Filter (`PinFilter`)
3 正交维度:
```swift
var tiers: Set<String> = ["重点", "区重点", "普通"]      // tier_letter/label 映射
var levels: Set<String> = ["小学", "初中"]                // school.type (仅 2 值)
var jiunianVisible: Bool = true                            // school.isJiunian (独立维度)
```
`includes(school)`: tier ∈ tiers AND type ∈ levels AND (!isJiunian || jiunianVisible)

## School.type vs isJiunian (重要!)
- **type 仅 2 值**: "小学" (level=primary) / "初中" (level=middle). 不再有 "九年一贯".
- **isJiunian: Bool**: 独立维度, 由 JSON `is_jiunian` 决定. 影响 pin shape (六边形) 但不影响 type 分类.
- 即"第二南开学校小学部" type=小学 + isJiunian=true → 在 "小学" 列计数 (符合表格分类) + 渲染六边形 pin.

## Tier 3 档映射 (`SeedImporter.tierFromSensitive`)
| coarse tier | tier_letter | tier_label fallback |
|---|---|---|
| 重点 | A++, A+ | 重点, 顶尖, 强校 |
| 区重点 | A, B+ | 区重点, 优质, 中上 |
| 普通 | 其余 / null | 其余 / null |

**Zone tier 聚合**: `SeedImporter.aggregateZoneTier()` 取 zone 内成员学校最高 coarse tier 写入 `SchoolZone.tier`. polygon renderer 读 `polygon.title` (hex of zone color).

## Camera 不回弹 (要点)
`MapKitView.updateUIView` 必须 gating: 仅当 `camera` (Binding) 真改才 `setCamera`. 否则用户拖/缩被覆盖.
- `Coordinator.cameraBinding: Binding<MKMapCamera>?` 持有 binding
- `regionDidChangeAnimated` → 写 `mv.camera` 回 binding + 更新 `lastAppliedCamera`
- `updateUIView` 比较 `cameraEquals(lastAppliedCamera, camera)` — 不等才推

## Hot Reload (`⌘⇧R`)
- Toolbar `↻ 重载数据` 发 `.reloadSeeds` notification
- `StudioRootView.reloadSeeds()`: delete all `SchoolZone/School/Compound` → `context.save()` → `SchoolRegistry.invalidate()` → `SeedImporter.runIfNeeded()`
- @Query 自动刷新

## Dev 数据源 (Bundle 旁路)
`SeedImporter.devSourceDir = "/Users/fujie/projects/天津买房/reports/extracted"`. `SeedImporter.loadJSON` **优先读源目录**, fallback bundle. Skill/手改 JSON 后无需 rebuild app, 点 ↻ 即生效.

## DB 为单一数据源 (2026-05-28 重构)
**所有 7 个 JSON 字段 100% 入 SwiftData**. SchoolRegistry 已删. UI 不再读 raw JSON.

| @Model | 来源 JSON | 字段策略 |
|---|---|---|
| `School` (33) | schools.json | 全字段; sensitive 平摊 `sensitiveXxx` 前缀 |
| `SchoolZone` | zones.json | 含 `middleSchoolPoolJSON` / `structureJSON` (复杂结构 JSON-encoded) |
| `Compound` | compounds.json | 含 xlsx 全字段 + 永辉 `sensitivePros/Cons`. JSON 无 lat/lon/address → 默认 (39.1, 117.2) 兜底 |
| `SchoolGroup` (新) | groups.json (32) | leads/members 编 JSON string |
| `Policy` (新) | policies.json (25) | 10+ 数组字段编 JSON string (`eligibilityJSON` 等) |
| `AdmissionRate` (新) | admission_rates.json (19) | district + year 复合 id |
| `CompoundSchoolMatch` (新) | compound_school_match.json (174) | bridge entity, matches 编 JSON |

UI / 业务逻辑只用 `@Query` + `FetchDescriptor`. `SchoolDetailCard` 用 `FetchDescriptor<School>(#Predicate { $0.id == X })` 拉记录, 按分组渲染所有 DB 字段.

**Schema 改动后必须 wipe store** (见 `docs/claude/swiftdata-store.md`), 否则 SwiftData 不迁移并 crash.

## 完整 Studio 数据流水线
```bash
swift scripts/geocode_schools.swift          # → schools.json 各项加 lat/lon
cd scripts/calibrate_raster && swift run Calibrator 和平区  # 弹窗校准 (重复 18 区)
cd - && python3 scripts/build_zone_hulls.py  # → zones.json 升级到 hull (保留 raster)
python3 scripts/validate.py                  # → 校验 schema
```

## Spec & Plan
- Spec: `docs/superpowers/specs/2026-05-26-studio-mode-design.md`
- Plan: `docs/superpowers/plans/2026-05-26-studio-mode.md`

## Mac Catalyst 构建
```bash
xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas \
    -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
```
当前 pbxproj 已加 `SUPPORTS_MACCATALYST=YES`、`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD=NO`、`MACOSX_DEPLOYMENT_TARGET=14.0`。
