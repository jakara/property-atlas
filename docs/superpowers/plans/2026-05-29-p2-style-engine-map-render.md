# P2: 样式引擎 + MapRender — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `2026-05-28-generic-map-tool-design.md` § 5（StyleRule + Palette + Theme + Entity override 求值链）+ 新通用 pin/area 渲染器，替换旧 `SchoolPinView` 写死逻辑；Studio toolbar 加 Theme picker；删除 P1 的 `LegacyShim`。

**Architecture:** 新 `MapRender/` 子模块持纯值类型（`PinStyle` / `AreaStyle`）+ 求值器（`ConditionEvaluator`、`PaletteResolver`、`StyleRuleMatcher`、`StyleResolver`）。Studio 通过 `@Observable ThemeContext` 拿到 active theme，调 `StyleResolver` 给每个 entity 计算最终样式，喂给新通用 `PinAnnotationView`（MKAnnotationView 子类）与 `AreaOverlayFactory`（MKPolygon 工厂）。`@Query` 监听 Entity/Theme 改动自动重渲染。

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, MapKit, Mac Catalyst (CloudKit `.none`), Swift Testing.

**前置 (P1 已落地):** 17 个新 @Model（含 `StyleRule`、`Palette`、`Theme`）；`StableHash.fnv1a32`；`AnyJSON` + `JSONHelpers`；`LegacyMigrator` 已种 4 Palette + 4 Theme + 默认 Layer + EnumOption。

**关键决定:**
- P2 范围 = spec § 5.1–5.6。§ 5.7 (FilterFieldConfig 视图内计数) 与 § 5.8 (Layer) **延到 P4**。
- 默认 styles 存于 `Theme.defaultStylesJSON`（已存在字段，P1 默认 "{}"）。P2 决定其 JSON 结构 (per entityType partial style)。
- 旧 `Studio/Layers/SchoolPinView.swift`、`SchoolAnnotation.swift`、`ZoneCentroidAnnotation.swift`、`ZoneGeometryImporter.swift`、`ZoneColorPalette.swift`、`ZoneShortLabel.swift`、`DataKit/LegacyShim.swift` 在 P2 末尾删除。
- `Studio/PinFilter.swift` + `StudioLegend.swift` + `SchoolDetailCard.swift` **保留**（P4 重做）。
- Mac Catalyst CloudKit `.none` 维持。

**最终交付:**
- `MapRender/` 子模块 (13 文件)
- `Studio/StudioToolbar.swift` + `StudioOverlay.swift` 加 Theme picker
- `RootView.swift` (StudioRootView) 重构走 StyleResolver
- 删旧 SchoolPinView/SchoolAnnotation/ZoneCentroidAnnotation/ZoneGeometryImporter/ZoneColorPalette/ZoneShortLabel/LegacyShim
- Studio 启动显新 demo dataset, Theme 切换实时重渲染
- 单测全绿 + 视觉 smoke OK

---

## 测试与开发约定

- 框架 Swift Testing (项目已用). Pure-value 类型 in-process unit tests. UIKit 子类 (MKAnnotationView/Renderer) 用 visual smoke + 提取的可测函数 (PinShapePath).
- 每 Task 一个 commit, message 前缀 `feat(render)` / `refactor(render)` / `test(render)`.
- SwiftLint 0 error 容忍.
- Test 命令模板:
  `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/<SuiteName> 2>&1 | tail -10`

---

## File Structure

```
PropertyAtlas/PropertyAtlas/
├── MapRender/                       (NEW)
│   ├── PinStyle.swift               (PinStyle + PartialPinStyle + PinShape)
│   ├── AreaStyle.swift              (AreaStyle + PartialAreaStyle)
│   ├── StyleDefaults.swift          (builtin + theme defaultStylesJSON parser)
│   ├── ConditionEvaluator.swift     (StyleCondition + 求值 + entity adapter)
│   ├── PaletteResolver.swift        (stableHash 索引)
│   ├── StyleRuleMatcher.swift       (rule 命中 + priority 排序)
│   ├── StyleResolver.swift          (主入口 default→rules→override)
│   ├── ThemeContext.swift           (@Observable activeTheme + switchTheme)
│   ├── PinAnnotation.swift          (MKAnnotation generic wrapper)
│   ├── PinAnnotationView.swift      (MKAnnotationView 通用渲染)
│   ├── PinShapePath.swift           (UIBezierPath 6 shape 工厂)
│   ├── AreaOverlayFactory.swift     (Area → MKPolygon)
│   └── AreaOverlayRenderer.swift    (MKPolygonRenderer + 颜色应用)
├── Studio/
│   ├── StudioToolbar.swift          (MODIFY: Theme picker)
│   ├── StudioOverlay.swift          (MODIFY: 接 ThemeContext)
│   ├── PinFilter.swift              (保留)
│   ├── StudioLegend.swift           (保留)
│   ├── SchoolDetailCard.swift       (保留)
│   └── (Layers/ 全删 P2 末尾)
├── RootView.swift                   (MODIFY: 改用 MapRender)
└── DataKit/
    └── LegacyShim.swift             (DELETE P2 末尾)

PropertyAtlas/PropertyAtlasTests/
└── MapRender/
    ├── PinStyleTests.swift
    ├── AreaStyleTests.swift
    ├── StyleDefaultsTests.swift
    ├── ConditionEvaluatorTests.swift
    ├── PaletteResolverTests.swift
    ├── StyleRuleMatcherTests.swift
    ├── StyleResolverTests.swift
    ├── ThemeContextTests.swift
    ├── PinShapePathTests.swift
    └── AreaOverlayFactoryTests.swift
```

---

## Task 0: PinStyle + PartialPinStyle + PinShape

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/PinStyle.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/PinStyleTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
// PropertyAtlas/PropertyAtlasTests/MapRender/PinStyleTests.swift
import Testing
import Foundation
@testable import PropertyAtlas

struct PinStyleTests {
    @Test func partialMergeKeepsNewerNonNilValue() {
        var p = PartialPinStyle()
        p.fillHex = "#FF0000"
        p.shape = .circle
        let later = PartialPinStyle(fillHex: "#00FF00")
        p.merge(later)
        #expect(p.fillHex == "#00FF00")
        #expect(p.shape == .circle)
    }

    @Test func partialFinalizeFallsBackToDefault() {
        var p = PartialPinStyle()
        p.fillHex = "#ABCDEF"
        let def = PinStyle(
            shape: .square,
            fillHex: "#000000",
            strokeHex: "#FFFFFF",
            glyph: nil,
            glyphHex: "#FFFFFF",
            size: 22,
            labelVisible: false
        )
        let final = p.finalize(default: def)
        #expect(final.fillHex == "#ABCDEF")
        #expect(final.shape == .square)
        #expect(final.size == 22)
    }

    @Test func pinShapeRawValuesMatchSpec() {
        #expect(PinShape.circle.rawValue == "circle")
        #expect(PinShape.square.rawValue == "square")
        #expect(PinShape.hexagon.rawValue == "hexagon")
        #expect(PinShape.diamond.rawValue == "diamond")
        #expect(PinShape.triangle.rawValue == "triangle")
        #expect(PinShape.star.rawValue == "star")
        #expect(PinShape(rawValue: "circle") == .circle)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/PinStyleTests 2>&1 | tail -10`
Expected: FAIL — `Cannot find 'PinStyle' / 'PartialPinStyle' / 'PinShape'`

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/PinStyle.swift
import Foundation
import CoreGraphics

enum PinShape: String, Codable, Equatable, CaseIterable {
    case circle, square, hexagon, diamond, triangle, star
}

struct PinStyle: Equatable {
    var shape: PinShape
    var fillHex: String
    var strokeHex: String
    var glyph: String?
    var glyphHex: String
    var size: CGFloat
    var labelVisible: Bool
}

struct PartialPinStyle: Equatable {
    var shape: PinShape?
    var fillHex: String?
    var strokeHex: String?
    var glyph: String?
    var glyphHex: String?
    var size: CGFloat?
    var labelVisible: Bool?

    init(
        shape: PinShape? = nil,
        fillHex: String? = nil,
        strokeHex: String? = nil,
        glyph: String? = nil,
        glyphHex: String? = nil,
        size: CGFloat? = nil,
        labelVisible: Bool? = nil
    ) {
        self.shape = shape
        self.fillHex = fillHex
        self.strokeHex = strokeHex
        self.glyph = glyph
        self.glyphHex = glyphHex
        self.size = size
        self.labelVisible = labelVisible
    }

    mutating func merge(_ other: PartialPinStyle) {
        if let v = other.shape { shape = v }
        if let v = other.fillHex { fillHex = v }
        if let v = other.strokeHex { strokeHex = v }
        if let v = other.glyph { glyph = v }
        if let v = other.glyphHex { glyphHex = v }
        if let v = other.size { size = v }
        if let v = other.labelVisible { labelVisible = v }
    }

    func finalize(default base: PinStyle) -> PinStyle {
        PinStyle(
            shape: shape ?? base.shape,
            fillHex: fillHex ?? base.fillHex,
            strokeHex: strokeHex ?? base.strokeHex,
            glyph: glyph ?? base.glyph,
            glyphHex: glyphHex ?? base.glyphHex,
            size: size ?? base.size,
            labelVisible: labelVisible ?? base.labelVisible
        )
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 3 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/PinStyle.swift PropertyAtlas/PropertyAtlasTests/MapRender/PinStyleTests.swift
git commit -m "feat(render): add PinStyle + PartialPinStyle + PinShape"
```

---

## Task 1: AreaStyle + PartialAreaStyle

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/AreaStyle.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/AreaStyleTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
import Testing
import Foundation
@testable import PropertyAtlas

struct AreaStyleTests {
    @Test func partialAreaMergeKeepsNewerNonNil() {
        var p = PartialAreaStyle()
        p.fillHex = "#FF0000"
        p.fillOpacity = 0.2
        let later = PartialAreaStyle(fillOpacity: 0.5)
        p.merge(later)
        #expect(p.fillHex == "#FF0000")
        #expect(p.fillOpacity == 0.5)
    }

    @Test func partialAreaFinalizeFallsBackToDefault() {
        var p = PartialAreaStyle()
        p.fillOpacity = 0.4
        let def = AreaStyle(
            fillHex: "#7C3AED",
            fillOpacity: 0.2,
            strokeHex: "#FFFFFF",
            strokeWidth: 1.0,
            labelVisible: true
        )
        let final = p.finalize(default: def)
        #expect(final.fillOpacity == 0.4)
        #expect(final.fillHex == "#7C3AED")
        #expect(final.strokeWidth == 1.0)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — `Cannot find 'AreaStyle' / 'PartialAreaStyle'`

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/AreaStyle.swift
import Foundation
import CoreGraphics

struct AreaStyle: Equatable {
    var fillHex: String
    var fillOpacity: Double
    var strokeHex: String
    var strokeWidth: Double
    var labelVisible: Bool
}

struct PartialAreaStyle: Equatable {
    var fillHex: String?
    var fillOpacity: Double?
    var strokeHex: String?
    var strokeWidth: Double?
    var labelVisible: Bool?

    init(
        fillHex: String? = nil,
        fillOpacity: Double? = nil,
        strokeHex: String? = nil,
        strokeWidth: Double? = nil,
        labelVisible: Bool? = nil
    ) {
        self.fillHex = fillHex
        self.fillOpacity = fillOpacity
        self.strokeHex = strokeHex
        self.strokeWidth = strokeWidth
        self.labelVisible = labelVisible
    }

    mutating func merge(_ other: PartialAreaStyle) {
        if let v = other.fillHex { fillHex = v }
        if let v = other.fillOpacity { fillOpacity = v }
        if let v = other.strokeHex { strokeHex = v }
        if let v = other.strokeWidth { strokeWidth = v }
        if let v = other.labelVisible { labelVisible = v }
    }

    func finalize(default base: AreaStyle) -> AreaStyle {
        AreaStyle(
            fillHex: fillHex ?? base.fillHex,
            fillOpacity: fillOpacity ?? base.fillOpacity,
            strokeHex: strokeHex ?? base.strokeHex,
            strokeWidth: strokeWidth ?? base.strokeWidth,
            labelVisible: labelVisible ?? base.labelVisible
        )
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 2 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/AreaStyle.swift PropertyAtlas/PropertyAtlasTests/MapRender/AreaStyleTests.swift
git commit -m "feat(render): add AreaStyle + PartialAreaStyle"
```

---

## Task 2: StyleDefaults — builtin + theme defaultStylesJSON 解析

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/StyleDefaults.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/StyleDefaultsTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
import Testing
import Foundation
@testable import PropertyAtlas

struct StyleDefaultsTests {
    @Test func builtinPinFallbacksAreSensible() {
        let d = StyleDefaults.builtinPin(for: "compound")
        #expect(d.shape == .circle)
        #expect(d.size == 22)
        #expect(d.labelVisible == false)
    }

    @Test func parseThemeDefaultsReturnsPerTypePartials() throws {
        let json = #"{"compound":{"fillHex":"#FF3B30","shape":"circle"},"school":{"fillHex":"#34C759"}}"#
        let parsed = try StyleDefaults.parseThemeDefaults(json)
        #expect(parsed.pin["compound"]?.fillHex == "#FF3B30")
        #expect(parsed.pin["compound"]?.shape == .circle)
        #expect(parsed.pin["school"]?.fillHex == "#34C759")
        #expect(parsed.pin["poi"] == nil)
    }

    @Test func parseThemeDefaultsEmptyJSONReturnsEmptyMaps() throws {
        let parsed = try StyleDefaults.parseThemeDefaults("{}")
        #expect(parsed.pin.isEmpty)
        #expect(parsed.area.isEmpty)
    }

    @Test func parseThemeDefaultsAreaSection() throws {
        let json = #"{"area":{"fillOpacity":0.35,"strokeHex":"#000000"}}"#
        let parsed = try StyleDefaults.parseThemeDefaults(json)
        #expect(parsed.area["area"]?.fillOpacity == 0.35)
        #expect(parsed.area["area"]?.strokeHex == "#000000")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — `Cannot find 'StyleDefaults'`

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/StyleDefaults.swift
import Foundation
import CoreGraphics

enum StyleDefaults {
    struct ParsedDefaults {
        let pin: [String: PartialPinStyle]
        let area: [String: PartialAreaStyle]
    }

    static func builtinPin(for entityType: String) -> PinStyle {
        PinStyle(
            shape: defaultShape(for: entityType),
            fillHex: "#A8A8A8",
            strokeHex: "#FFFFFF",
            glyph: nil,
            glyphHex: "#FFFFFF",
            size: 22,
            labelVisible: false
        )
    }

    static func builtinArea() -> AreaStyle {
        AreaStyle(
            fillHex: "#7C3AED",
            fillOpacity: 0.2,
            strokeHex: "#FFFFFF",
            strokeWidth: 1.0,
            labelVisible: false
        )
    }

    private static func defaultShape(for entityType: String) -> PinShape {
        switch entityType {
        case "compound": return .circle
        case "school": return .square
        case "poi": return .triangle
        default: return .circle
        }
    }

    static func parseThemeDefaults(_ json: String) throws -> ParsedDefaults {
        let decoded: [String: AnyJSON] = (try? JSONHelpers.decode(json)) ?? [:]
        var pin: [String: PartialPinStyle] = [:]
        var area: [String: PartialAreaStyle] = [:]
        for (key, value) in decoded {
            guard case let .object(dict) = value else { continue }
            switch key {
            case "compound", "school", "poi":
                pin[key] = makePinPartial(from: dict)
            case "area":
                area[key] = makeAreaPartial(from: dict)
            default:
                continue
            }
        }
        return ParsedDefaults(pin: pin, area: area)
    }

    private static func makePinPartial(from dict: [String: AnyJSON]) -> PartialPinStyle {
        var p = PartialPinStyle()
        if case let .string(v) = dict["shape"] { p.shape = PinShape(rawValue: v) }
        if case let .string(v) = dict["fillHex"] { p.fillHex = v }
        if case let .string(v) = dict["strokeHex"] { p.strokeHex = v }
        if case let .string(v) = dict["glyph"] { p.glyph = v }
        if case let .string(v) = dict["glyphHex"] { p.glyphHex = v }
        if case let .int(v) = dict["size"] { p.size = CGFloat(v) }
        if case let .double(v) = dict["size"] { p.size = CGFloat(v) }
        if case let .bool(v) = dict["labelVisible"] { p.labelVisible = v }
        return p
    }

    private static func makeAreaPartial(from dict: [String: AnyJSON]) -> PartialAreaStyle {
        var a = PartialAreaStyle()
        if case let .string(v) = dict["fillHex"] { a.fillHex = v }
        if case let .double(v) = dict["fillOpacity"] { a.fillOpacity = v }
        if case let .int(v) = dict["fillOpacity"] { a.fillOpacity = Double(v) }
        if case let .string(v) = dict["strokeHex"] { a.strokeHex = v }
        if case let .double(v) = dict["strokeWidth"] { a.strokeWidth = v }
        if case let .int(v) = dict["strokeWidth"] { a.strokeWidth = Double(v) }
        if case let .bool(v) = dict["labelVisible"] { a.labelVisible = v }
        return a
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 4 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/StyleDefaults.swift PropertyAtlas/PropertyAtlasTests/MapRender/StyleDefaultsTests.swift
git commit -m "feat(render): StyleDefaults builtin + theme JSON parser"
```

---

## Task 3: ConditionEvaluator + StyleEntity + entity adapters

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/ConditionEvaluator.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/ConditionEvaluatorTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
import Testing
import Foundation
@testable import PropertyAtlas

@MainActor
struct ConditionEvaluatorTests {
    @Test func equalsOnBaseFieldMatchesString() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        let c = StyleCondition(field: "grade", op: .equals, value: .string("重点"))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func equalsOnBaseFieldFailsWhenDifferent() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "普通"
        let c = StyleCondition(field: "grade", op: .equals, value: .string("重点"))
        #expect(!ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func notEqualsInverts() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "普通"
        let c = StyleCondition(field: "grade", op: .notEquals, value: .string("重点"))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func inOpAcceptsArrayValue() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        let c = StyleCondition(field: "grade", op: .inOp, value: .array([.string("重点"), .string("区重点")]))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func containsOpMatchesSubstring() {
        let s = School(datasetId: UUID(), name: "鞍山道小学", latitude: 0, longitude: 0)
        let c = StyleCondition(field: "name", op: .contains, value: .string("小学"))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func gteAndLteOpsOnNumeric() {
        let c = Compound(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        c.buildYear = 2022
        let gte = StyleCondition(field: "buildYear", op: .gte, value: .int(2020))
        let lte = StyleCondition(field: "buildYear", op: .lte, value: .int(2018))
        #expect(ConditionEvaluator.matches(entity: c.styleEntity, condition: gte))
        #expect(!ConditionEvaluator.matches(entity: c.styleEntity, condition: lte))
    }

    @Test func existsOpTrueWhenFieldNonNil() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.foundYear = 1954
        let c = StyleCondition(field: "foundYear", op: .exists, value: .null)
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func customFieldLookupReadsFromCustomFieldsJSON() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.customFieldsJSON = #"{"isMarketKey":true}"#
        let c = StyleCondition(field: "isMarketKey", op: .equals, value: .bool(true))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — `Cannot find 'StyleCondition' / 'ConditionEvaluator' / 'styleEntity'`

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/ConditionEvaluator.swift
import Foundation

enum StyleConditionOp: String, Codable {
    case equals
    case notEquals
    case inOp = "in"
    case contains
    case gte
    case lte
    case exists
}

struct StyleCondition: Codable {
    let field: String
    let op: StyleConditionOp
    let value: AnyJSON
}

struct StyleEntity {
    let entityType: String
    let id: UUID
    private let baseFields: [String: AnyJSON]
    private let customFields: [String: AnyJSON]

    init(
        entityType: String,
        id: UUID,
        baseFields: [String: AnyJSON],
        customFields: [String: AnyJSON]
    ) {
        self.entityType = entityType
        self.id = id
        self.baseFields = baseFields
        self.customFields = customFields
    }

    func field(_ name: String) -> AnyJSON? {
        if let v = baseFields[name] { return v }
        return customFields[name]
    }
}

enum ConditionEvaluator {
    static func matches(entity: StyleEntity, condition: StyleCondition) -> Bool {
        let actual = entity.field(condition.field)
        switch condition.op {
        case .equals:
            return actual == condition.value
        case .notEquals:
            return actual != condition.value
        case .inOp:
            if case let .array(items) = condition.value, let a = actual {
                return items.contains(a)
            }
            return false
        case .contains:
            if case let .string(needle) = condition.value,
               case let .string(haystack) = actual {
                return haystack.contains(needle)
            }
            return false
        case .gte:
            guard let l = numeric(actual), let r = numeric(condition.value) else { return false }
            return l >= r
        case .lte:
            guard let l = numeric(actual), let r = numeric(condition.value) else { return false }
            return l <= r
        case .exists:
            if actual == nil { return false }
            if case .null = actual { return false }
            return true
        }
    }

    static func numeric(_ v: AnyJSON?) -> Double? {
        switch v {
        case let .int(n): return Double(n)
        case let .double(d): return d
        default: return nil
        }
    }
}

// MARK: entity adapters

@MainActor
extension School {
    var styleEntity: StyleEntity {
        let custom: [String: AnyJSON] = customFieldsJSON.flatMap { try? JSONHelpers.decode($0) } ?? [:]
        var base: [String: AnyJSON] = [:]
        base["name"] = .string(name)
        if let v = address { base["address"] = .string(v) }
        if let v = category { base["category"] = .string(v) }
        if let v = grade { base["grade"] = .string(v) }
        if let v = form { base["form"] = .string(v) }
        if let v = foundYear { base["foundYear"] = .int(v) }
        if let v = capacity { base["capacity"] = .int(v) }
        if let v = communitiesText { base["communitiesText"] = .string(v) }
        if let v = overrideStyleJSON { base["__overrideStyleJSON"] = .string(v) }
        return StyleEntity(entityType: "school", id: id, baseFields: base, customFields: custom)
    }
}

@MainActor
extension Compound {
    var styleEntity: StyleEntity {
        let custom: [String: AnyJSON] = customFieldsJSON.flatMap { try? JSONHelpers.decode($0) } ?? [:]
        var base: [String: AnyJSON] = [:]
        base["name"] = .string(name)
        if let v = address { base["address"] = .string(v) }
        if let v = buildYear { base["buildYear"] = .int(v) }
        if let v = developer { base["developer"] = .string(v) }
        if let v = propertyMgmt { base["propertyMgmt"] = .string(v) }
        if let v = propertyFeeCents { base["propertyFeeCents"] = .int(v) }
        if let v = landYears { base["landYears"] = .int(v) }
        if let v = finishType { base["finishType"] = .string(v) }
        if let v = deliveryTime { base["deliveryTime"] = .string(v) }
        base["isNewHouse"] = .bool(isNewHouse)
        if let v = overrideStyleJSON { base["__overrideStyleJSON"] = .string(v) }
        return StyleEntity(entityType: "compound", id: id, baseFields: base, customFields: custom)
    }
}

@MainActor
extension POI {
    var styleEntity: StyleEntity {
        let custom: [String: AnyJSON] = customFieldsJSON.flatMap { try? JSONHelpers.decode($0) } ?? [:]
        var base: [String: AnyJSON] = [:]
        base["name"] = .string(name)
        if let v = address { base["address"] = .string(v) }
        if let v = category { base["category"] = .string(v) }
        if let v = overrideStyleJSON { base["__overrideStyleJSON"] = .string(v) }
        return StyleEntity(entityType: "poi", id: id, baseFields: base, customFields: custom)
    }
}

@MainActor
extension Area {
    var styleEntity: StyleEntity {
        let custom: [String: AnyJSON] = customFieldsJSON.flatMap { try? JSONHelpers.decode($0) } ?? [:]
        var base: [String: AnyJSON] = [:]
        base["name"] = .string(name)
        if let v = category { base["category"] = .string(v) }
        base["fillOpacity"] = .double(fillOpacity)
        if let v = textDescription { base["textDescription"] = .string(v) }
        if let v = overrideStyleJSON { base["__overrideStyleJSON"] = .string(v) }
        return StyleEntity(entityType: "area", id: id, baseFields: base, customFields: custom)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 8 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/ConditionEvaluator.swift PropertyAtlas/PropertyAtlasTests/MapRender/ConditionEvaluatorTests.swift
git commit -m "feat(render): StyleCondition + ConditionEvaluator + entity adapters"
```

---

## Task 4: PaletteResolver

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/PaletteResolver.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/PaletteResolverTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
import Testing
import Foundation
@testable import PropertyAtlas

@MainActor
struct PaletteResolverTests {
    @Test func paletteByIdYieldsColorFromList() {
        let palette = Palette(name: "rainbow", colorsHex: ["#FF0000", "#00FF00", "#0000FF"])
        let e1 = StyleEntity(entityType: "area", id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, baseFields: [:], customFields: [:])
        let c1 = PaletteResolver.resolve(palette: palette, entity: e1, keyField: nil)
        #expect(palette.colorsHex.contains(c1))
    }

    @Test func sameKeyAlwaysYieldsSameColor() {
        let palette = Palette(name: "rainbow", colorsHex: ["#FF0000", "#00FF00", "#0000FF"])
        let e = StyleEntity(entityType: "area", id: UUID(), baseFields: ["name": .string("第一学片")], customFields: [:])
        let a = PaletteResolver.resolve(palette: palette, entity: e, keyField: "name")
        let b = PaletteResolver.resolve(palette: palette, entity: e, keyField: "name")
        #expect(a == b)
    }

    @Test func missingKeyFallsBackToIdHash() {
        let palette = Palette(name: "rainbow", colorsHex: ["#FF0000"])
        let e = StyleEntity(entityType: "area", id: UUID(), baseFields: [:], customFields: [:])
        let c = PaletteResolver.resolve(palette: palette, entity: e, keyField: "nonexistent")
        #expect(c == "#FF0000")
    }

    @Test func emptyPaletteReturnsFallbackHex() {
        let palette = Palette(name: "empty", colorsHex: [])
        let e = StyleEntity(entityType: "area", id: UUID(), baseFields: [:], customFields: [:])
        let c = PaletteResolver.resolve(palette: palette, entity: e, keyField: nil)
        #expect(c == PaletteResolver.fallbackHex)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/PaletteResolver.swift
import Foundation

enum PaletteResolver {
    static let fallbackHex = "#7C7C7C"

    static func resolve(palette: Palette, entity: StyleEntity, keyField: String?) -> String {
        guard !palette.colorsHex.isEmpty else { return fallbackHex }
        let key = resolveKey(entity: entity, keyField: keyField)
        let h = StableHash.fnv1a32(key)
        let idx = Int(h % UInt32(palette.colorsHex.count))
        return palette.colorsHex[idx]
    }

    private static func resolveKey(entity: StyleEntity, keyField: String?) -> String {
        if let field = keyField, !field.isEmpty,
           let v = entity.field(field),
           let s = stringify(v) {
            return s
        }
        return entity.id.uuidString
    }

    private static func stringify(_ v: AnyJSON) -> String? {
        switch v {
        case let .string(s): return s.isEmpty ? nil : s
        case let .int(n): return String(n)
        case let .double(d): return String(d)
        case let .bool(b): return String(b)
        case .null, .array, .object: return nil
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 4 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/PaletteResolver.swift PropertyAtlas/PropertyAtlasTests/MapRender/PaletteResolverTests.swift
git commit -m "feat(render): PaletteResolver stableHash key"
```

---

## Task 5: StyleRuleMatcher

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/StyleRuleMatcher.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/StyleRuleMatcherTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
import Testing
import Foundation
@testable import PropertyAtlas

@MainActor
struct StyleRuleMatcherTests {
    @Test func ruleMatchesWhenEntityTypeAndConditionsPass() throws {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        s.category = "小学"
        let rule = StyleRule(datasetId: UUID(), name: "test", entityType: "school")
        rule.conditionsJSON = #"[{"field":"grade","op":"equals","value":"重点"},{"field":"category","op":"equals","value":"小学"}]"#
        #expect(StyleRuleMatcher.matches(rule: rule, entity: s.styleEntity))
    }

    @Test func ruleSkippedWhenEntityTypeDiffers() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let rule = StyleRule(datasetId: UUID(), name: "test", entityType: "compound")
        rule.conditionsJSON = "[]"
        #expect(!StyleRuleMatcher.matches(rule: rule, entity: s.styleEntity))
    }

    @Test func ruleSkippedWhenAnyConditionFails() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        s.category = "初中"
        let rule = StyleRule(datasetId: UUID(), name: "test", entityType: "school")
        rule.conditionsJSON = #"[{"field":"grade","op":"equals","value":"重点"},{"field":"category","op":"equals","value":"小学"}]"#
        #expect(!StyleRuleMatcher.matches(rule: rule, entity: s.styleEntity))
    }

    @Test func ruleSkippedWhenDisabled() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let rule = StyleRule(datasetId: UUID(), name: "test", entityType: "school")
        rule.conditionsJSON = "[]"
        rule.enabled = false
        #expect(!StyleRuleMatcher.matches(rule: rule, entity: s.styleEntity))
    }

    @Test func sortByPriorityDescending() {
        let r1 = StyleRule(datasetId: UUID(), name: "a", entityType: "school")
        r1.priority = 5
        let r2 = StyleRule(datasetId: UUID(), name: "b", entityType: "school")
        r2.priority = 10
        let r3 = StyleRule(datasetId: UUID(), name: "c", entityType: "school")
        r3.priority = 0
        let sorted = StyleRuleMatcher.sortByPriority([r1, r2, r3])
        #expect(sorted.map { $0.name } == ["b", "a", "c"])
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/StyleRuleMatcher.swift
import Foundation

@MainActor
enum StyleRuleMatcher {
    static func matches(rule: StyleRule, entity: StyleEntity) -> Bool {
        guard rule.enabled else { return false }
        guard rule.entityType == entity.entityType else { return false }
        let conditions = parseConditions(rule.conditionsJSON)
        for c in conditions {
            if !ConditionEvaluator.matches(entity: entity, condition: c) { return false }
        }
        return true
    }

    static func sortByPriority(_ rules: [StyleRule]) -> [StyleRule] {
        rules.sorted { $0.priority > $1.priority }
    }

    private static func parseConditions(_ json: String) -> [StyleCondition] {
        guard !json.isEmpty, json != "[]" else { return [] }
        do {
            return try JSONHelpers.decode(json)
        } catch {
            return []
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 5 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/StyleRuleMatcher.swift PropertyAtlas/PropertyAtlasTests/MapRender/StyleRuleMatcherTests.swift
git commit -m "feat(render): StyleRuleMatcher with priority sort"
```

---

## Task 6: StyleResolver (orchestrator)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/StyleResolverTests.swift`

求值链: default → matching rules (priority ASC apply, 高优先后写入) → entity override.

- [ ] **Step 1: 写 failing test**

```swift
import Testing
import Foundation
@testable import PropertyAtlas

@MainActor
struct StyleResolverTests {
    @Test func pinFallsBackToBuiltinWhenNoThemeNoRules() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [],
            palettes: [:]
        )
        let builtin = StyleDefaults.builtinPin(for: "school")
        #expect(resolved == builtin)
    }

    @Test func themeDefaultOverridesBuiltin() {
        let theme = Theme(datasetId: UUID(), name: "test")
        theme.defaultStylesJSON = #"{"school":{"fillHex":"#FF0000","shape":"hexagon"}}"#
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: theme,
            rules: [],
            palettes: [:]
        )
        #expect(resolved.fillHex == "#FF0000")
        #expect(resolved.shape == .hexagon)
    }

    @Test func matchingFixedRuleOverridesThemeDefault() {
        let theme = Theme(datasetId: UUID(), name: "test")
        theme.defaultStylesJSON = #"{"school":{"fillHex":"#FF0000"}}"#
        let rule = StyleRule(datasetId: UUID(), name: "重点", entityType: "school")
        rule.conditionsJSON = #"[{"field":"grade","op":"equals","value":"重点"}]"#
        rule.appliesFillHex = "#00FF00"
        rule.appliesShape = "square"
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: theme,
            rules: [rule],
            palettes: [:]
        )
        #expect(resolved.fillHex == "#00FF00")
        #expect(resolved.shape == .square)
    }

    @Test func higherPriorityRuleWinsWhenBothMatch() {
        let r1 = StyleRule(datasetId: UUID(), name: "low", entityType: "school")
        r1.conditionsJSON = "[]"
        r1.priority = 5
        r1.appliesFillHex = "#000000"
        let r2 = StyleRule(datasetId: UUID(), name: "high", entityType: "school")
        r2.conditionsJSON = "[]"
        r2.priority = 10
        r2.appliesFillHex = "#FFFFFF"
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [r1, r2],
            palettes: [:]
        )
        #expect(resolved.fillHex == "#FFFFFF")
    }

    @Test func paletteRuleResolvesFillFromPalette() {
        let palette = Palette(name: "rainbow", colorsHex: ["#FF0000", "#00FF00", "#0000FF"])
        let rule = StyleRule(datasetId: UUID(), name: "palette", entityType: "school")
        rule.conditionsJSON = "[]"
        rule.appliesFillMode = "palette"
        rule.appliesPaletteId = palette.id
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [rule],
            palettes: [palette.id: palette]
        )
        #expect(palette.colorsHex.contains(resolved.fillHex))
    }

    @Test func entityOverrideAppliesLast() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.overrideStyleJSON = #"{"fillHex":"#7C3AED","glyph":"★"}"#
        let rule = StyleRule(datasetId: UUID(), name: "x", entityType: "school")
        rule.conditionsJSON = "[]"
        rule.appliesFillHex = "#000000"
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [rule],
            palettes: [:]
        )
        #expect(resolved.fillHex == "#7C3AED")
        #expect(resolved.glyph == "★")
    }

    @Test func resolveAreaUsesAreaPartialAndPalette() {
        let palette = Palette(name: "areas", colorsHex: ["#FF0000", "#0000FF"])
        let rule = StyleRule(datasetId: UUID(), name: "area-palette", entityType: "area")
        rule.conditionsJSON = "[]"
        rule.appliesFillMode = "palette"
        rule.appliesPaletteId = palette.id
        rule.appliesFillOpacity = 0.35
        let a = Area(datasetId: UUID(), name: "片区1", geometryKind: "polygon", geometryJSON: "{}")
        let resolved = StyleResolver.resolveArea(
            entity: a.styleEntity,
            theme: nil,
            rules: [rule],
            palettes: [palette.id: palette]
        )
        #expect(palette.colorsHex.contains(resolved.fillHex))
        #expect(resolved.fillOpacity == 0.35)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift
import Foundation
import CoreGraphics

@MainActor
enum StyleResolver {
    static func resolvePin(
        entity: StyleEntity,
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette]
    ) -> PinStyle {
        let base = StyleDefaults.builtinPin(for: entity.entityType)
        var partial = PartialPinStyle()

        if let theme {
            let parsed = (try? StyleDefaults.parseThemeDefaults(theme.defaultStylesJSON)) ?? StyleDefaults.ParsedDefaults(pin: [:], area: [:])
            if let themeDefault = parsed.pin[entity.entityType] {
                partial.merge(themeDefault)
            }
        }

        let matching = rules.filter { StyleRuleMatcher.matches(rule: $0, entity: entity) }
        let ascending = matching.sorted { $0.priority < $1.priority }
        for rule in ascending {
            partial.merge(pinPartialFromRule(rule, entity: entity, palettes: palettes))
        }

        if let overrideJSON = entity.overrideJSON {
            partial.merge(pinOverridePartial(overrideJSON))
        }

        return partial.finalize(default: base)
    }

    static func resolveArea(
        entity: StyleEntity,
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette]
    ) -> AreaStyle {
        let base = StyleDefaults.builtinArea()
        var partial = PartialAreaStyle()

        if let theme {
            let parsed = (try? StyleDefaults.parseThemeDefaults(theme.defaultStylesJSON)) ?? StyleDefaults.ParsedDefaults(pin: [:], area: [:])
            if let themeDefault = parsed.area["area"] {
                partial.merge(themeDefault)
            }
        }

        let matching = rules.filter { StyleRuleMatcher.matches(rule: $0, entity: entity) }
        let ascending = matching.sorted { $0.priority < $1.priority }
        for rule in ascending {
            partial.merge(areaPartialFromRule(rule, entity: entity, palettes: palettes))
        }

        if let overrideJSON = entity.overrideJSON {
            partial.merge(areaOverridePartial(overrideJSON))
        }

        return partial.finalize(default: base)
    }

    private static func pinPartialFromRule(
        _ rule: StyleRule,
        entity: StyleEntity,
        palettes: [UUID: Palette]
    ) -> PartialPinStyle {
        var p = PartialPinStyle()
        if let s = rule.appliesShape { p.shape = PinShape(rawValue: s) }
        if rule.appliesFillMode == "palette" {
            if let pid = rule.appliesPaletteId, let palette = palettes[pid] {
                p.fillHex = PaletteResolver.resolve(palette: palette, entity: entity, keyField: rule.appliesPaletteKeyField)
            }
        } else if let hex = rule.appliesFillHex {
            p.fillHex = hex
        }
        if let v = rule.appliesStrokeHex { p.strokeHex = v }
        if let v = rule.appliesGlyph { p.glyph = v }
        if let v = rule.appliesGlyphHex { p.glyphHex = v }
        if let v = rule.appliesSize { p.size = CGFloat(v) }
        if let v = rule.appliesLabelVisible { p.labelVisible = v }
        return p
    }

    private static func areaPartialFromRule(
        _ rule: StyleRule,
        entity: StyleEntity,
        palettes: [UUID: Palette]
    ) -> PartialAreaStyle {
        var a = PartialAreaStyle()
        if rule.appliesFillMode == "palette" {
            if let pid = rule.appliesPaletteId, let palette = palettes[pid] {
                a.fillHex = PaletteResolver.resolve(palette: palette, entity: entity, keyField: rule.appliesPaletteKeyField)
            }
        } else if let hex = rule.appliesFillHex {
            a.fillHex = hex
        }
        if let v = rule.appliesFillOpacity { a.fillOpacity = v }
        if let v = rule.appliesStrokeHex { a.strokeHex = v }
        if let v = rule.appliesStrokeWidth { a.strokeWidth = v }
        if let v = rule.appliesLabelVisible { a.labelVisible = v }
        return a
    }

    private static func pinOverridePartial(_ json: String) -> PartialPinStyle {
        guard let decoded: [String: AnyJSON] = try? JSONHelpers.decode(json) else { return PartialPinStyle() }
        var p = PartialPinStyle()
        if case let .string(v) = decoded["shape"] { p.shape = PinShape(rawValue: v) }
        if case let .string(v) = decoded["fillHex"] { p.fillHex = v }
        if case let .string(v) = decoded["strokeHex"] { p.strokeHex = v }
        if case let .string(v) = decoded["glyph"] { p.glyph = v }
        if case let .string(v) = decoded["glyphHex"] { p.glyphHex = v }
        if case let .int(v) = decoded["size"] { p.size = CGFloat(v) }
        if case let .double(v) = decoded["size"] { p.size = CGFloat(v) }
        if case let .bool(v) = decoded["labelVisible"] { p.labelVisible = v }
        return p
    }

    private static func areaOverridePartial(_ json: String) -> PartialAreaStyle {
        guard let decoded: [String: AnyJSON] = try? JSONHelpers.decode(json) else { return PartialAreaStyle() }
        var a = PartialAreaStyle()
        if case let .string(v) = decoded["fillHex"] { a.fillHex = v }
        if case let .double(v) = decoded["fillOpacity"] { a.fillOpacity = v }
        if case let .int(v) = decoded["fillOpacity"] { a.fillOpacity = Double(v) }
        if case let .string(v) = decoded["strokeHex"] { a.strokeHex = v }
        if case let .double(v) = decoded["strokeWidth"] { a.strokeWidth = v }
        if case let .int(v) = decoded["strokeWidth"] { a.strokeWidth = Double(v) }
        if case let .bool(v) = decoded["labelVisible"] { a.labelVisible = v }
        return a
    }
}

extension StyleEntity {
    var overrideJSON: String? {
        if case let .string(s) = field("__overrideStyleJSON") { return s }
        return nil
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 7 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift PropertyAtlas/PropertyAtlasTests/MapRender/StyleResolverTests.swift
git commit -m "feat(render): StyleResolver default→rules→override"
```

---

## Task 7: ThemeContext @Observable

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/ThemeContext.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/ThemeContextTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct ThemeContextTests {
    @Test func initialActiveThemeReadsFromDataset() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Theme.self])
        let ctx = ModelContext(container)
        let ds = Dataset(name: "test")
        let theme = Theme(datasetId: ds.id, name: "学区视图")
        ds.activeThemeId = theme.id
        ctx.insert(ds); ctx.insert(theme)
        try ctx.save()

        let themeCtx = ThemeContext(dataset: ds, modelContext: ctx)
        #expect(themeCtx.activeTheme?.name == "学区视图")
    }

    @Test func switchThemeUpdatesActiveThemeId() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Theme.self])
        let ctx = ModelContext(container)
        let ds = Dataset(name: "test")
        let t1 = Theme(datasetId: ds.id, name: "字段总览")
        let t2 = Theme(datasetId: ds.id, name: "学区视图")
        ds.activeThemeId = t1.id
        ctx.insert(ds); ctx.insert(t1); ctx.insert(t2)
        try ctx.save()

        let themeCtx = ThemeContext(dataset: ds, modelContext: ctx)
        themeCtx.switchTheme(to: t2)
        try ctx.save()

        #expect(ds.activeThemeId == t2.id)
        #expect(themeCtx.activeTheme?.id == t2.id)
    }

    @Test func allThemesReturnsDatasetThemesSorted() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Theme.self])
        let ctx = ModelContext(container)
        let ds = Dataset(name: "test")
        let t1 = Theme(datasetId: ds.id, name: "b")
        t1.sortOrder = 1
        let t2 = Theme(datasetId: ds.id, name: "a")
        t2.sortOrder = 0
        ctx.insert(ds); ctx.insert(t1); ctx.insert(t2)
        try ctx.save()
        let themeCtx = ThemeContext(dataset: ds, modelContext: ctx)
        let names = themeCtx.allThemes.map { $0.name }
        #expect(names == ["a", "b"])
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/ThemeContext.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class ThemeContext {
    private let dataset: Dataset
    private let modelContext: ModelContext

    init(dataset: Dataset, modelContext: ModelContext) {
        self.dataset = dataset
        self.modelContext = modelContext
    }

    var activeTheme: Theme? {
        guard let id = dataset.activeThemeId else { return nil }
        let descriptor = FetchDescriptor<Theme>(
            predicate: #Predicate { $0.id == id && !$0.deleted }
        )
        return try? modelContext.fetch(descriptor).first
    }

    var allThemes: [Theme] {
        let dsId = dataset.id
        let descriptor = FetchDescriptor<Theme>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func switchTheme(to theme: Theme) {
        dataset.activeThemeId = theme.id
        dataset.updatedAt = Date()
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 3 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/ThemeContext.swift PropertyAtlas/PropertyAtlasTests/MapRender/ThemeContextTests.swift
git commit -m "feat(render): ThemeContext @Observable"
```

---

## Task 8: PinShapePath — UIBezierPath 6 shape

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/PinShapePath.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/PinShapePathTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
#if targetEnvironment(macCatalyst)
import Testing
import UIKit
import Foundation
@testable import PropertyAtlas

struct PinShapePathTests {
    @Test func eachShapeProducesNonEmptyPath() {
        let rect = CGRect(x: 0, y: 0, width: 22, height: 22)
        for shape in PinShape.allCases {
            let path = PinShapePath.path(for: shape, in: rect)
            #expect(!path.isEmpty)
            #expect(path.bounds.width > 0)
            #expect(path.bounds.height > 0)
        }
    }

    @Test func circlePathFitsInRect() {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
        let path = PinShapePath.path(for: .circle, in: rect)
        #expect(rect.contains(path.bounds))
    }
}
#endif
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — `Cannot find 'PinShapePath'`

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/PinShapePath.swift
#if targetEnvironment(macCatalyst)
import UIKit

enum PinShapePath {
    static func path(for shape: PinShape, in rect: CGRect) -> UIBezierPath {
        let r = rect.insetBy(dx: 0.75, dy: 0.75)
        switch shape {
        case .circle:
            return UIBezierPath(ovalIn: r)
        case .square:
            return UIBezierPath(roundedRect: r, cornerRadius: 3)
        case .hexagon:
            return polygonPath(in: r, sides: 6, rotation: -.pi / 2)
        case .diamond:
            return polygonPath(in: r, sides: 4, rotation: 0)
        case .triangle:
            return polygonPath(in: r, sides: 3, rotation: -.pi / 2)
        case .star:
            return starPath(in: r, points: 5)
        }
    }

    private static func polygonPath(in rect: CGRect, sides: Int, rotation: CGFloat) -> UIBezierPath {
        let cx = rect.midX
        let cy = rect.midY
        let radius = min(rect.width, rect.height) / 2
        let path = UIBezierPath()
        for i in 0..<sides {
            let angle = rotation + CGFloat(i) * (2 * .pi) / CGFloat(sides)
            let x = cx + radius * cos(angle)
            let y = cy + radius * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.close()
        return path
    }

    private static func starPath(in rect: CGRect, points: Int) -> UIBezierPath {
        let cx = rect.midX
        let cy = rect.midY
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        let path = UIBezierPath()
        let total = points * 2
        for i in 0..<total {
            let angle = -.pi / 2 + CGFloat(i) * (.pi / CGFloat(points))
            let r = (i % 2 == 0) ? outer : inner
            let x = cx + r * cos(angle)
            let y = cy + r * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.close()
        return path
    }
}
#endif
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 2 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/PinShapePath.swift PropertyAtlas/PropertyAtlasTests/MapRender/PinShapePathTests.swift
git commit -m "feat(render): PinShapePath UIBezierPath factory"
```

---

## Task 9: PinAnnotation

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/PinAnnotation.swift`

- [ ] **Step 1: 实现** (value type 无 unit test, 由 Task 14 集成验证)

```swift
// PropertyAtlas/PropertyAtlas/MapRender/PinAnnotation.swift
#if targetEnvironment(macCatalyst)
import MapKit
import Foundation

final class PinAnnotation: NSObject, MKAnnotation {
    let entityId: UUID
    let entityType: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let style: PinStyle

    init(
        entityId: UUID,
        entityType: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        style: PinStyle
    ) {
        self.entityId = entityId
        self.entityType = entityType
        self.name = name
        self.coordinate = coordinate
        self.style = style
    }

    var title: String? { name }
}
#endif
```

- [ ] **Step 2: 编译检查**

Run: `xcodebuild build -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -5`
Expected: ** BUILD SUCCEEDED **

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/PinAnnotation.swift
git commit -m "feat(render): PinAnnotation MKAnnotation wrapper"
```

---

## Task 10: PinAnnotationView

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/PinAnnotationView.swift`

- [ ] **Step 1: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/PinAnnotationView.swift
#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

final class PinAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "pinAnnotation"
    private static let gap: CGFloat = 4

    private let dot = UIView()
    private let shapeLayer = CAShapeLayer()
    private let glyphLabel = UILabel()
    private let nameLabel = UILabel()

    override var annotation: (any MKAnnotation)? {
        didSet { refresh() }
    }

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        canShowCallout = false

        shapeLayer.lineWidth = 1.5
        shapeLayer.shadowColor = UIColor.black.cgColor
        shapeLayer.shadowOpacity = 0.25
        shapeLayer.shadowRadius = 2
        shapeLayer.shadowOffset = CGSize(width: 0, height: 1)
        dot.layer.addSublayer(shapeLayer)

        glyphLabel.textAlignment = .center
        glyphLabel.font = .systemFont(ofSize: 11, weight: .bold)
        glyphLabel.textColor = .white
        dot.addSubview(glyphLabel)

        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.layer.cornerRadius = 4
        nameLabel.layer.masksToBounds = true
        nameLabel.textAlignment = .center

        addSubview(dot)
        addSubview(nameLabel)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func refresh() {
        guard let a = annotation as? PinAnnotation else { return }
        let style = a.style
        let dotSize = style.size

        let fill = HexColor.parse(style.fillHex) ?? .gray
        let stroke = HexColor.parse(style.strokeHex) ?? .white
        let glyphColor = HexColor.parse(style.glyphHex) ?? .white

        shapeLayer.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        shapeLayer.path = PinShapePath.path(for: style.shape, in: shapeLayer.bounds).cgPath
        shapeLayer.fillColor = fill.cgColor
        shapeLayer.strokeColor = stroke.cgColor

        glyphLabel.text = style.glyph
        glyphLabel.textColor = glyphColor
        glyphLabel.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
        glyphLabel.isHidden = (style.glyph == nil) || (style.glyph?.isEmpty == true)

        if style.labelVisible, !a.name.isEmpty {
            nameLabel.isHidden = false
            nameLabel.text = "  \(a.name)  "
            nameLabel.backgroundColor = fill.withAlphaComponent(0.92)
            let nameSize = nameLabel.intrinsicContentSize
            let h: CGFloat = max(dotSize, nameSize.height + 2)
            dot.frame = CGRect(x: 0, y: (h - dotSize) / 2, width: dotSize, height: dotSize)
            nameLabel.frame = CGRect(x: dotSize + Self.gap, y: 0, width: nameSize.width, height: h)
            frame = CGRect(x: 0, y: 0, width: dotSize + Self.gap + nameSize.width, height: h)
        } else {
            nameLabel.isHidden = true
            dot.frame = CGRect(x: 0, y: 0, width: dotSize, height: dotSize)
            frame = dot.frame
        }
        centerOffset = CGPoint(x: (frame.width - dotSize) / 2, y: 0)
    }
}

enum HexColor {
    static func parse(_ hex: String) -> UIColor? {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let n = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((n >> 16) & 0xFF) / 255
        let g = CGFloat((n >> 8) & 0xFF) / 255
        let b = CGFloat(n & 0xFF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif
```

- [ ] **Step 2: 编译检查**

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/PinAnnotationView.swift
git commit -m "feat(render): PinAnnotationView generic MKAnnotationView"
```

---

## Task 11: AreaOverlayFactory

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/AreaOverlayFactory.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/MapRender/AreaOverlayFactoryTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
#if targetEnvironment(macCatalyst)
import Testing
import MapKit
import Foundation
@testable import PropertyAtlas

@MainActor
struct AreaOverlayFactoryTests {
    @Test func polygonAreaProducesMKPolygonWithStyle() {
        let a = Area(
            datasetId: UUID(),
            name: "片区1",
            geometryKind: "polygon",
            geometryJSON: #"{"type":"Polygon","coordinates":[[[117.1,39.1],[117.2,39.1],[117.2,39.2],[117.1,39.2],[117.1,39.1]]]}"#
        )
        let style = AreaStyle(fillHex: "#FF0000", fillOpacity: 0.3, strokeHex: "#000000", strokeWidth: 1, labelVisible: false)
        let result = AreaOverlayFactory.makeOverlay(for: a, style: style)
        let polygon = result?.overlay as? MKPolygon
        #expect(polygon != nil)
        #expect(polygon?.pointCount == 5)
        #expect(result?.style.fillHex == "#FF0000")
    }

    @Test func invalidGeometryReturnsNil() {
        let a = Area(
            datasetId: UUID(),
            name: "broken",
            geometryKind: "polygon",
            geometryJSON: "{broken json"
        )
        let style = AreaStyle(fillHex: "#FFF", fillOpacity: 0.2, strokeHex: "#000", strokeWidth: 1, labelVisible: false)
        #expect(AreaOverlayFactory.makeOverlay(for: a, style: style) == nil)
    }
}
#endif
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/AreaOverlayFactory.swift
#if targetEnvironment(macCatalyst)
import MapKit
import Foundation

enum AreaOverlayFactory {
    struct Result {
        let overlay: MKOverlay
        let style: AreaStyle
        let areaId: UUID
    }

    static func makeOverlay(for area: Area, style: AreaStyle) -> Result? {
        switch area.geometryKind {
        case "polygon":
            guard let coords = decodePolygon(area.geometryJSON) else { return nil }
            let polygon = MKPolygon(coordinates: coords, count: coords.count)
            polygon.title = area.name
            return Result(overlay: polygon, style: style, areaId: area.id)
        case "raster":
            return nil
        default:
            return nil
        }
    }

    private static func decodePolygon(_ json: String) -> [CLLocationCoordinate2D]? {
        guard let data = json.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any],
              let coords = dict["coordinates"] as? [[[Double]]],
              let ring = coords.first
        else { return nil }
        return ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }
}
#endif
```

- [ ] **Step 4: 跑测试确认通过**

Expected: 2 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/AreaOverlayFactory.swift PropertyAtlas/PropertyAtlasTests/MapRender/AreaOverlayFactoryTests.swift
git commit -m "feat(render): AreaOverlayFactory polygon"
```

---

## Task 12: AreaOverlayRenderer

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/AreaOverlayRenderer.swift`

- [ ] **Step 1: 实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/AreaOverlayRenderer.swift
#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

final class AreaOverlayRenderer: MKPolygonRenderer {
    init(polygon: MKPolygon, style: AreaStyle) {
        super.init(polygon: polygon)
        let fill = HexColor.parse(style.fillHex) ?? .purple
        let stroke = HexColor.parse(style.strokeHex) ?? .white
        fillColor = fill.withAlphaComponent(CGFloat(style.fillOpacity))
        strokeColor = stroke
        lineWidth = CGFloat(style.strokeWidth)
    }
}
#endif
```

- [ ] **Step 2: 编译检查**

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/AreaOverlayRenderer.swift
git commit -m "feat(render): AreaOverlayRenderer styled MKPolygonRenderer"
```

---

## Task 13: MapContainerView 改造 — rendererFor hook + 通用 annotation renderer

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Map/MapContainerView.swift`

让 MapContainerView 接受外部传入的 `rendererFor:(MKOverlay) -> MKOverlayRenderer?` 闭包, StudioRootView 用此 hook 把 Area style → AreaOverlayRenderer.

- [ ] **Step 1: 读 MapContainerView.swift, 定位 delegate impl**

```bash
grep -n "viewFor\|rendererFor\|MKMapViewDelegate" PropertyAtlas/PropertyAtlas/Map/MapContainerView.swift
```

- [ ] **Step 2: 把 annotation viewFor 改用 PinAnnotationView**

替换 delegate 内的 viewFor 实现:

```swift
func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
    guard !(annotation is MKUserLocation) else { return nil }
    let reuseId = PinAnnotationView.reuseIdentifier
    let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? PinAnnotationView
        ?? PinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
    view.annotation = annotation
    return view
}
```

- [ ] **Step 3: 加 rendererFor 注入闭包**

`MapContainerView` 顶部新加 init 参数:

```swift
var rendererFor: ((MKOverlay) -> MKOverlayRenderer?)? = nil
```

delegate 实现:

```swift
func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
    if let renderer = rendererFor?(overlay) {
        return renderer
    }
    if let polygon = overlay as? MKPolygon {
        let r = MKPolygonRenderer(polygon: polygon)
        r.fillColor = UIColor.purple.withAlphaComponent(0.2)
        r.strokeColor = .white
        r.lineWidth = 1
        return r
    }
    return MKOverlayRenderer(overlay: overlay)
}
```

- [ ] **Step 4: 跑全测**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Map/MapContainerView.swift
git commit -m "refactor(map): MapContainerView annotation view + rendererFor hook"
```

---

## Task 14: StudioRootView 改用 MapRender

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`

- [ ] **Step 1: 替换 #if targetEnvironment(macCatalyst) struct StudioRootView**

旧版用 LegacyShim + SchoolAnnotation + ZoneGeometryImporter. 新版:

```swift
#if targetEnvironment(macCatalyst)
struct StudioRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var datasets: [Dataset]
    @Query private var compounds: [Compound]
    @Query private var schools: [School]
    @Query private var pois: [POI]
    @Query private var areas: [Area]
    @Query private var styleRules: [StyleRule]
    @Query private var palettes: [Palette]

    @State private var themeContext: ThemeContext?
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var watermark: String = "@公众号名 · PropertyAtlas"
    @State private var aspect: CanvasAspect = .ratio16x9
    @State private var camera: MKMapCamera = MKMapCamera(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 39.125, longitude: 117.205),
        fromDistance: 12000, pitch: 0, heading: 0
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedEntityId: UUID?

    var body: some View {
        let activeTheme = themeContext?.activeTheme
        let palettesById: [UUID: Palette] = Dictionary(uniqueKeysWithValues: palettes.map { ($0.id, $0) })
        let activeRuleIds = Set(activeTheme?.styleRuleIds ?? [])
        let rulesForTheme = styleRules.filter { activeRuleIds.contains($0.id) }
        let visibility = visibilityFromTheme(activeTheme)

        let pins: [MKAnnotation] = buildPins(
            compounds: visibility["compound"] == true ? compounds : [],
            schools: visibility["school"] == true ? schools : [],
            pois: visibility["poi"] == true ? pois : [],
            theme: activeTheme,
            rules: rulesForTheme,
            palettes: palettesById
        )
        let (overlays, styleMap) = visibility["area"] == true
            ? buildAreaOverlays(areas: areas, theme: activeTheme, rules: rulesForTheme, palettes: palettesById)
            : ([], [:])

        ZStack {
            MapContainerView(
                camera: $camera,
                overlays: overlays,
                annotations: pins,
                onRegionChange: { visibleRegion = $0 },
                onSchoolSelect: { id in selectedEntityId = id },
                rendererFor: { overlay in
                    guard let polygon = overlay as? MKPolygon,
                          let style = styleMap[ObjectIdentifier(overlay)]
                    else { return nil }
                    return AreaOverlayRenderer(polygon: polygon, style: style)
                }
            )
            .ignoresSafeArea()
            if let ctx = themeContext {
                StudioOverlay(
                    title: $title,
                    subtitle: $subtitle,
                    watermark: $watermark,
                    aspect: $aspect,
                    themeContext: ctx
                )
            }
        }
        .onAppear { ensureThemeContext() }
        .onChange(of: datasets.first?.id) { _, _ in ensureThemeContext() }
    }

    private func ensureThemeContext() {
        guard themeContext == nil, let ds = datasets.first(where: { !$0.deleted }) else { return }
        themeContext = ThemeContext(dataset: ds, modelContext: modelContext)
        title = themeContext?.activeTheme?.copyTitle ?? ""
        subtitle = themeContext?.activeTheme?.copySubtitle ?? ""
    }

    private func visibilityFromTheme(_ theme: Theme?) -> [String: Bool] {
        guard let theme,
              let data = theme.visibilityJSON.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Bool]
        else {
            return ["compound": true, "school": true, "poi": true, "area": true]
        }
        return obj
    }

    private func buildPins(
        compounds: [Compound],
        schools: [School],
        pois: [POI],
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette]
    ) -> [MKAnnotation] {
        var result: [MKAnnotation] = []
        for c in compounds where !c.deleted && (c.latitude != 0 || c.longitude != 0) {
            let style = StyleResolver.resolvePin(entity: c.styleEntity, theme: theme, rules: rules, palettes: palettes)
            result.append(PinAnnotation(
                entityId: c.id, entityType: "compound", name: c.name,
                coordinate: c.coordinate, style: style
            ))
        }
        for s in schools where !s.deleted && (s.latitude != 0 || s.longitude != 0) {
            let style = StyleResolver.resolvePin(entity: s.styleEntity, theme: theme, rules: rules, palettes: palettes)
            result.append(PinAnnotation(
                entityId: s.id, entityType: "school", name: s.name,
                coordinate: s.coordinate, style: style
            ))
        }
        for p in pois where !p.deleted && (p.latitude != 0 || p.longitude != 0) {
            let style = StyleResolver.resolvePin(entity: p.styleEntity, theme: theme, rules: rules, palettes: palettes)
            result.append(PinAnnotation(
                entityId: p.id, entityType: "poi", name: p.name,
                coordinate: p.coordinate, style: style
            ))
        }
        return result
    }

    private func buildAreaOverlays(
        areas: [Area],
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette]
    ) -> ([MKOverlay], [ObjectIdentifier: AreaStyle]) {
        var overlays: [MKOverlay] = []
        var map: [ObjectIdentifier: AreaStyle] = [:]
        for a in areas where !a.deleted {
            let style = StyleResolver.resolveArea(entity: a.styleEntity, theme: theme, rules: rules, palettes: palettes)
            if let r = AreaOverlayFactory.makeOverlay(for: a, style: style) {
                overlays.append(r.overlay)
                map[ObjectIdentifier(r.overlay)] = r.style
            }
        }
        return (overlays, map)
    }
}
#endif
```

(ExploreRootView + ToolbarView + Notification.Name 不动.)

- [ ] **Step 2: 跑全测**

Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/RootView.swift
git commit -m "refactor(studio): StudioRootView drives MapRender via StyleResolver"
```

---

## Task 15: StudioToolbar + StudioOverlay 接 ThemeContext

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/StudioToolbar.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/StudioOverlay.swift`

- [ ] **Step 1: 重写 StudioToolbar**

```swift
#if targetEnvironment(macCatalyst)
import MapKit
import SwiftUI

struct StudioToolbar: View {
    @Bindable var themeContext: ThemeContext
    @Binding var aspect: CanvasAspect
    let onSnapshot: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu(themeContext.activeTheme?.name ?? "无主题") {
                ForEach(themeContext.allThemes) { theme in
                    Button(theme.name) { themeContext.switchTheme(to: theme) }
                }
            }
            Menu("📐 \(aspect.rawValue)") {
                ForEach(CanvasAspect.allCases) { a in
                    Button(a.rawValue) { aspect = a }
                }
            }
            Divider().frame(height: 20)
            Button(action: onSnapshot) { Text("📸 截屏") }
                .keyboardShortcut("e", modifiers: .command)
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}
#endif
```

- [ ] **Step 2: 重写 StudioOverlay**

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioOverlay: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var watermark: String
    @Binding var aspect: CanvasAspect
    @Bindable var themeContext: ThemeContext

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                StudioToolbar(themeContext: themeContext, aspect: $aspect, onSnapshot: {})
                    .padding(.bottom, 24)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    StudioWatermark(text: watermark)
                }
                .padding(16)
            }
        }
    }
}
#endif
```

- [ ] **Step 3: 跑全测**

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/StudioToolbar.swift PropertyAtlas/PropertyAtlas/Studio/StudioOverlay.swift
git commit -m "feat(studio): Theme picker driven by ThemeContext"
```

---

## Task 16: 删 LegacyShim + 旧 Studio/Layers/

**Files:**
- Delete: `PropertyAtlas/PropertyAtlas/DataKit/LegacyShim.swift`
- Delete: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyShimTests.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/Layers/SchoolAnnotation.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/Layers/SchoolPinView.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneCentroidAnnotation.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneColorPalette.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneGeometryImporter.swift`
- Delete: `PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneShortLabel.swift`

(保留 `Studio/PinFilter.swift`, `Studio/StudioLegend.swift`, `Studio/SchoolDetailCard.swift` — P4 处理.)

- [ ] **Step 1: 检查无外部引用**

```bash
grep -rn "LegacyShim\|SchoolAnnotation\|SchoolPinView\|ZoneCentroidAnnotation\|ZoneColorPalette\|ZoneGeometryImporter\|ZoneShortLabel" PropertyAtlas/PropertyAtlas --include="*.swift" | grep -v "Studio/Layers"
```
Expected: empty.

如有残余 ref, 先修 caller 再删.

- [ ] **Step 2: 删除**

```bash
git rm PropertyAtlas/PropertyAtlas/DataKit/LegacyShim.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyShimTests.swift PropertyAtlas/PropertyAtlas/Studio/Layers/SchoolAnnotation.swift PropertyAtlas/PropertyAtlas/Studio/Layers/SchoolPinView.swift PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneCentroidAnnotation.swift PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneColorPalette.swift PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneGeometryImporter.swift PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneShortLabel.swift
```

- [ ] **Step 3: 跑全测**

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(studio): remove LegacyShim + legacy Layers/* replaced by MapRender"
```

---

## Task 17: 真机 smoke + CLAUDE.md 更新

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Mac Catalyst smoke**

Xcode → Mac Catalyst → Run. 确认:
- Studio 启动不崩
- Map 上有 Area polygon 色块 + School/Compound pins
- Theme picker 显 4 themes ("字段总览", "学区视图", "商圈视图", "新房地图")
- 切 theme → 可见样式变化 (e.g. "新房地图" 只显 Compound)

- [ ] **Step 2: 更新 CLAUDE.md**

在 Key Documents 部分加:

```markdown
- 实施计划 P2 (已完成): `docs/superpowers/plans/2026-05-29-p2-style-engine-map-render.md`
- P3-P5 计划: 待写
```

在 "## Critical Architecture" 加 NOTE:

```markdown
> **P2 (2026-05-29) 完成后**: Studio 渲染走 `MapRender/StyleResolver`
> (default → matching rules → entity override 三段求值). 旧
> `SchoolPinView` / `ZoneGeometryImporter` / `ZoneColorPalette` /
> `LegacyShim` 删除. Theme 切换由 `ThemeContext` 驱动. §5.7 Filter
> 视图内计数 + §5.8 Layer 留待 P4.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): note P2 style engine + MapRender completion"
```

---

## Self-Review 总结

P2 plan 共 18 tasks (Task 0..17). 每 task TDD + commit.

**Spec 覆盖** vs § 5.1–5.6 of design doc:
- § 5.1 求值链: Task 6
- § 5.2 StyleRule + apply: Task 5/6
- § 5.3 Palette + stableHash: Task 4
- § 5.4 Theme + activeTheme + 切换: Task 7 / 15
- § 5.5 Entity override: Task 6 (`overrideJSON` path)
- § 5.6 Legend 自动生成: **P4 延 (一起做 §5.7/§5.8)**

**Placeholder 扫描**: 全部 step 有具体 code/cmd, 无 TBD.

**Type 一致性**:
- `PinStyle` 字段 `shape/fillHex/strokeHex/glyph/glyphHex/size/labelVisible` Task 0/6/10 一致
- `AreaStyle` 字段 `fillHex/fillOpacity/strokeHex/strokeWidth/labelVisible` Task 1/6/11/12 一致
- `StyleEntity.field(_)` Task 3/4/5/6 一致
- `StyleResolver.resolvePin/resolveArea` 签名 Task 6/14 一致
- `MapContainerView` 新 `rendererFor` 参数 Task 13/14 一致

**P2 末尾状态**:
- Studio 渲染全走 MapRender
- Theme 切换实时, Picker UI 在 toolbar
- 旧 SchoolPinView / ZoneGeometryImporter / LegacyShim 删除
- 单测 + smoke 全绿
- StudioLegend / PinFilter / SchoolDetailCard 暂保留 — P4 重做

**已知 P3 follow-up**:
- Raster Area overlay (CalibratedImageOverlay)
- Pin spotlight + dim others (Theme.spotlightOnSelect)
- Draw edge lines (Theme.drawEdgeLines)

---

**End of P2 plan**
