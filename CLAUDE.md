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
- P2-P5 计划: 待写

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
