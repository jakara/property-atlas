# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project

iPad-first iOS 17+ app for property research in Tianjin. Stack: SwiftUI · MapKit · SwiftData · CloudKit private DB.

## Key Documents

- Design spec: `@docs/superpowers/specs/2026-05-19-tianjin-house-design.md`
- Implementation plan: `@docs/superpowers/plans/2026-05-20-tianjin-house-app.md`
- Design tokens & colors: `design/colors_and_type.css`

## Critical Architecture

### Layout — floating chrome, NOT rigid split

The map is always full-screen (`ignoresSafeArea()`). Toolbar and drawer float above it as glass cards using `ZStack`, not an `HStack`:

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
| `pub_*` | School zones, compounds, schools (read-only seed data) | SwiftData, no CloudKit |
| `usr_*` | User marks, visit records, custom zones, photos | SwiftData + CloudKit private DB |
| `loc_*` | App settings | SwiftData local only |

Never sync `pub_*` or `loc_*` to CloudKit.

### School district logic

- **小学** (primary): one compound → one school (`Compound.primarySchoolId`)
- **初中** (middle): one zone → lottery pool of schools (`Compound.zoneId` + `School.zoneId`)

Do not model 初中 as a single-school assignment.

### Seed pipeline

Public data is **bundled offline** — not fetched at runtime. Flow:
1. `Scripts/SeedExtractor/` (Mac CLI) converts Markdown reports → JSON
2. JSON bundled into app
3. `SeedImporter` runs on first launch with progress UI

### CloudKit constraints

- Private database only (`ModelConfiguration(cloudKitDatabase: .private(...))`)
- All `@Model` properties need default values or `?` optional
- Photo compression: 1280px max, HEIC format, quality 0.8

## Design Tokens

Colors defined in `design/colors_and_type.css`, mirrored in `TianjinHouse/Extensions/Color+Hex.swift`.

| Token | Value | Use |
|-------|-------|-----|
| `accent500` | #B5703A | Buttons, selection |
| `tierTop` | #C99B2C | 顶尖 school zone |
| `tierGood` | #5B7C9C | 优质 school zone |
| `tierNormal` | #9C968B | 普通 school zone |
| `tierWeak` | #B8736B | 薄弱 school zone |
| `statusWant` | #5B7C9C | 想看 pin |
| `statusVisited` | #7A9A7E | 看过 pin |
| `statusExcluded` | #A85040 | 排除 pin |
| `statusUnvisited` | #9C968B | 未看 pin (default) |

## Code Standards

- **SwiftLint** required — run `swiftlint lint` before committing
- Max file size: 300 lines
- Use Swift Testing framework (not XCTest) for unit tests
- iOS 17+ minimum — use `Map(position:)`, not the deprecated `Map(coordinateRegion:)`

## CI

- iOS: Xcode Cloud (ADP included)
- Android / backend (future): GitHub Actions
