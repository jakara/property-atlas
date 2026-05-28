# P1: 新 @Model 基础层 + 迁移 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `PropertyAtlas` 中落地 spec `2026-05-28-generic-map-tool-design.md` 的 17 个新 @Model 与 `LegacyMigrator`，把现有 `Models/Public/*` 旧数据迁到新结构。旧 Studio UI 通过 `LegacyShim` 适配新 entity 继续运行（regression 保证）。

**Architecture:** 新 @Model 文件按 spec § 11 目录结构落到 `Models/{Core,Entities,Style,Display,Schema,Media}`。`LegacyMigrator` 一次性迁移：打开旧 store → 读旧 model 实例 → 写新 model 实例（同 SwiftData container，schema 联合两套），完成后标记 `migrated=true` 跳过下次。`LegacyShim` 提供 `school.type` / `school.tier` / `school.zoneId` 等旧字段名的 computed-property 适配，使 `SchoolPinView` / `StudioRootView` 无需改动即可读新 entity。

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData (iOS 17+), Swift Testing, MapKit, Mac Catalyst（CloudKit 暂保持 `.none` 与现状一致；P5 再切到 `.private`）。

**关键决定**:
- Mac Catalyst CloudKit 本 plan 仍设 `.none`（避开 schema 变更与 CloudKit 镜像冲突），spec 说的"开启 Mac CloudKit"延后到 P5；
- 旧 `Models/User/Photo.swift`（依赖 `Visit` 的私人 visit 照片）改名 `VisitPhoto`，让出 `Photo` 给新 spec 的通用媒体模型；
- 其他 `Models/User/*`（PropertyMark/Visit/UserArea/...）本 plan 不动，留待后续 plan 处理；
- 旧 store 文件 rename 为 `${storeURL}.legacy.store`，不删除，万一迁移逻辑漏字段方便回查；
- 新 store 由新 schema 打开（不复用旧 store path），由 `LegacyMigrator` 一次性灌入。

**预期最终交付**:
- 17 个新 @Model 文件 + 工具类（`StableHash`, `JSONHelpers`）
- `LegacyMigrator.swift` + 单测覆盖每个迁移阶段
- `LegacyShim.swift` 给旧 Studio 用的 adapter computed-property
- `PropertyAtlasApp.swift` 改用新 schema
- 旧 `SeedImporter.swift` 改造为「检测旧 store → 触发 LegacyMigrator → 否则空 dataset」
- 旧 `Models/Public/*` 暂不删除（让 LegacyMigrator 用），但加 `@available(*, deprecated, message: "Use new Models/Entities/* instead")` 标记
- 单测全绿；旧 Studio 启动加载新 store + adapter 显示与旧版视觉等价的 pins

---

## 测试与开发约定

- 框架：Swift Testing（已用，见 `PropertyAtlasTests/PropertyAtlasTests.swift`），不用 XCTest
- 命名：每个 @Model 一个测试 struct，如 `DatasetTests`，存放于 `PropertyAtlasTests/Models/DatasetTests.swift`
- 持久化测试：用 in-memory `ModelContainer`（见 Task 0 的 `TestContainer.makeInMemory`）
- 每 Task 一次 commit，message 用 `feat(data): ...` 或 `test(data): ...` 等 conventional commits 前缀
- SwiftLint：每次 commit 前跑 `swiftlint lint --quiet`，零警告

---

## File Structure

```
PropertyAtlas/PropertyAtlas/
├── Models/
│   ├── Core/
│   │   ├── Dataset.swift           (NEW)
│   │   ├── Edge.swift              (NEW)
│   │   ├── Tag.swift               (NEW)
│   │   └── CameraPreset.swift      (NEW)
│   ├── Entities/
│   │   ├── Compound.swift          (NEW, 替代 Models/Public/Compound.swift)
│   │   ├── School.swift            (NEW, 替代 Models/Public/School.swift)
│   │   ├── POI.swift               (NEW)
│   │   └── Area.swift              (NEW, 替代 Models/Public/SchoolZone.swift)
│   ├── Style/
│   │   ├── StyleRule.swift         (NEW)
│   │   ├── Palette.swift           (NEW)
│   │   └── Theme.swift             (NEW)
│   ├── Display/
│   │   ├── Layer.swift             (NEW)
│   │   └── FilterFieldConfig.swift (NEW)
│   ├── Schema/
│   │   ├── CustomFieldDef.swift    (NEW)
│   │   └── EnumOption.swift        (NEW)
│   ├── Media/
│   │   ├── Photo.swift             (NEW, 新通用媒体)
│   │   └── Document.swift          (NEW, 替代 AdmissionDoc)
│   ├── Public/                     (旧 @Model，加 @available deprecated，迁移完毕后由 P5 删)
│   │   └── (Compound/School/SchoolZone/... 保持不变)
│   ├── User/
│   │   ├── VisitPhoto.swift        (NEW, 由旧 Photo.swift 改名)
│   │   └── (PropertyMark/Visit/... 不动)
│   ├── Local/                      (AppSettings.swift 不动)
│   └── Settings/                   (保留 AppSettings 现位置, 不移动)
├── DataKit/                        (NEW 顶级目录)
│   ├── StableHash.swift            (NEW, FNV-1a 32-bit)
│   ├── JSONHelpers.swift           (NEW, 通用 encode/decode for *JSON 字段)
│   ├── LegacyShim.swift            (NEW, 给旧 Studio 用)
│   ├── LegacyMigrator.swift        (NEW)
│   └── ModelSchema.swift           (NEW, 新 schema array 和 ModelContainer factory)
├── States/
│   └── SeedImporter.swift          (MODIFY)
└── PropertyAtlasApp.swift          (MODIFY, 改用新 schema)

PropertyAtlas/PropertyAtlasTests/
├── Models/                         (NEW 子目录)
│   ├── DatasetTests.swift
│   ├── EdgeTests.swift
│   ├── TagTests.swift
│   ├── CameraPresetTests.swift
│   ├── CompoundTests.swift
│   ├── SchoolTests.swift
│   ├── POITests.swift
│   ├── AreaTests.swift
│   ├── StyleRuleTests.swift
│   ├── PaletteTests.swift
│   ├── ThemeTests.swift
│   ├── LayerTests.swift
│   ├── FilterFieldConfigTests.swift
│   ├── CustomFieldDefTests.swift
│   ├── EnumOptionTests.swift
│   ├── PhotoTests.swift
│   └── DocumentTests.swift
├── DataKit/
│   ├── StableHashTests.swift
│   ├── JSONHelpersTests.swift
│   ├── LegacyShimTests.swift
│   └── LegacyMigratorTests.swift
└── Helpers/
    └── TestContainer.swift         (NEW, in-memory ModelContainer helper)
```

---

## Task 0: 测试基础设施（in-memory ModelContainer helper）

**Files:**
- Create: `PropertyAtlas/PropertyAtlasTests/Helpers/TestContainer.swift`

- [ ] **Step 1: 写 helper（这是工具类，不写 failing test，直接写实现）**

```swift
// PropertyAtlas/PropertyAtlasTests/Helpers/TestContainer.swift
import Foundation
import SwiftData
@testable import PropertyAtlas

enum TestContainer {
    /// In-memory ModelContainer for unit tests. Pass the @Model types under test.
    static func makeInMemory(for types: [any PersistentModel.Type]) throws -> ModelContainer {
        let schema = Schema(types)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 2: 确认编译通过**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/PropertyAtlasTests/example 2>&1 | tail -30`
Expected: 编译通过；`example` 测试 PASS（空测试）

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlasTests/Helpers/TestContainer.swift
git commit -m "test(data): add TestContainer in-memory helper"
```

---

## Task 1: StableHash (FNV-1a 32-bit)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/StableHash.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/DataKit/StableHashTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
// PropertyAtlas/PropertyAtlasTests/DataKit/StableHashTests.swift
import Testing
@testable import PropertyAtlas

struct StableHashTests {
    @Test func fnv1aProducesKnownValuesForReferenceStrings() {
        // FNV-1a 32-bit reference vectors (http://www.isthe.com/chongo/tech/comp/fnv/)
        #expect(StableHash.fnv1a32("") == 0x811c9dc5)
        #expect(StableHash.fnv1a32("a") == 0xe40c292c)
        #expect(StableHash.fnv1a32("foobar") == 0xbf9cf968)
    }

    @Test func fnv1aIsStableAcrossCalls() {
        let a = StableHash.fnv1a32("天津 demo")
        let b = StableHash.fnv1a32("天津 demo")
        #expect(a == b)
    }

    @Test func fnv1aDistinctInputsProduceDistinctHashes() {
        #expect(StableHash.fnv1a32("第一学片") != StableHash.fnv1a32("第二学片"))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/StableHashTests 2>&1 | tail -20`
Expected: FAIL —  `Cannot find 'StableHash' in scope`

- [ ] **Step 3: 实现 StableHash**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/StableHash.swift
import Foundation

enum StableHash {
    /// FNV-1a 32-bit hash. Stable across processes / platforms (unlike Swift's Hasher).
    /// Spec: http://www.isthe.com/chongo/tech/comp/fnv/
    static func fnv1a32(_ s: String) -> UInt32 {
        var hash: UInt32 = 0x811c9dc5
        for byte in s.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return hash
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/StableHashTests 2>&1 | tail -20`
Expected: 3 个测试 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/StableHash.swift PropertyAtlas/PropertyAtlasTests/DataKit/StableHashTests.swift
git commit -m "feat(data): add StableHash FNV-1a 32-bit utility"
```

---

## Task 2: JSONHelpers (encode/decode for *JSON 字段)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/JSONHelpers.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/DataKit/JSONHelpersTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
// PropertyAtlas/PropertyAtlasTests/DataKit/JSONHelpersTests.swift
import Testing
import Foundation
@testable import PropertyAtlas

struct JSONHelpersTests {
    @Test func encodeDecodeRoundTripDict() throws {
        let dict: [String: AnyJSON] = ["k1": .string("v1"), "k2": .int(42)]
        let json = try JSONHelpers.encode(dict)
        let back: [String: AnyJSON] = try JSONHelpers.decode(json)
        #expect(back["k1"] == .string("v1"))
        #expect(back["k2"] == .int(42))
    }

    @Test func encodeDecodeRoundTripArray() throws {
        let arr: [AnyJSON] = [.string("a"), .int(1), .bool(true), .null]
        let json = try JSONHelpers.encode(arr)
        let back: [AnyJSON] = try JSONHelpers.decode(json)
        #expect(back == arr)
    }

    @Test func decodeInvalidStringThrows() {
        #expect(throws: (any Error).self) {
            let _: [String: AnyJSON] = try JSONHelpers.decode("not-json{")
        }
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/JSONHelpersTests 2>&1 | tail -20`
Expected: FAIL — `Cannot find 'JSONHelpers' / 'AnyJSON'`

- [ ] **Step 3: 实现 JSONHelpers + AnyJSON**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/JSONHelpers.swift
import Foundation

/// Discriminated JSON value used in *JSON String columns where Codable models
/// stored heterogeneous payloads (e.g. CustomFieldDef.defaultValueJSON,
/// StyleRule.conditionsJSON).
enum AnyJSON: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([AnyJSON])
    case object([String: AnyJSON])
    case null

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case let .string(v): try c.encode(v)
        case let .int(v): try c.encode(v)
        case let .double(v): try c.encode(v)
        case let .bool(v): try c.encode(v)
        case let .array(v): try c.encode(v)
        case let .object(v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([AnyJSON].self) { self = .array(v); return }
        if let v = try? c.decode([String: AnyJSON].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(
            in: c,
            debugDescription: "AnyJSON: unknown payload"
        )
    }
}

enum JSONHelpers {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder = JSONDecoder()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    static func decode<T: Decodable>(_ string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw NSError(domain: "JSONHelpers", code: 1, userInfo: [NSLocalizedDescriptionKey: "utf8 fail"])
        }
        return try decoder.decode(T.self, from: data)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/JSONHelpersTests 2>&1 | tail -20`
Expected: 3 个测试 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/JSONHelpers.swift PropertyAtlas/PropertyAtlasTests/DataKit/JSONHelpersTests.swift
git commit -m "feat(data): add AnyJSON + JSONHelpers utility"
```

---

## Task 3: 旧 Photo 改名 VisitPhoto（释放名字给新 Photo）

**Files:**
- Rename: `PropertyAtlas/PropertyAtlas/Models/User/Photo.swift` → `Models/User/VisitPhoto.swift`
- Modify: 全 codebase 引用 `Photo`（旧类）的地方改 `VisitPhoto`

- [ ] **Step 1: 检索旧 Photo 引用**

Run: `grep -rn "\\bPhoto\\b" PropertyAtlas/PropertyAtlas --include="*.swift" | grep -v "PropertyAtlas/Models/Media"`
预期：列出所有引用文件（PropertyAtlasApp.swift Schema、其他 model 引用等）

- [ ] **Step 2: 重命名文件**

```bash
git mv PropertyAtlas/PropertyAtlas/Models/User/Photo.swift PropertyAtlas/PropertyAtlas/Models/User/VisitPhoto.swift
```

- [ ] **Step 3: 修改类名**

把 `Models/User/VisitPhoto.swift` 里 `final class Photo` → `final class VisitPhoto`，init 名也调整。

```swift
// PropertyAtlas/PropertyAtlas/Models/User/VisitPhoto.swift
import Foundation
import SwiftData

@Model final class VisitPhoto {
    var id: UUID = UUID()
    var visitId: UUID?
    var compoundId: UUID?
    var kind: String = "visit"
    var imageData: Data?
    var caption: String?
    var takenAt: Date?
    var width: Int?
    var height: Int?
    var createdAt: Date = Date()

    init(visitId: UUID? = nil, compoundId: UUID? = nil, kind: String = "visit") {
        self.visitId = visitId
        self.compoundId = compoundId
        self.kind = kind
    }
}
```

- [ ] **Step 4: 全局替换引用**

```bash
# Schema in PropertyAtlasApp.swift
```

用 Edit 工具在 `PropertyAtlas/PropertyAtlas/PropertyAtlasApp.swift` 把 `Photo.self` 改 `VisitPhoto.self`。
然后 `grep -rn "\\bPhoto\\b" PropertyAtlas/PropertyAtlas --include="*.swift"` 检查是否还有 stale 引用，逐个改成 `VisitPhoto`。

- [ ] **Step 5: 跑全测确认通过 + commit**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -30`
Expected: all PASS

```bash
git add -A PropertyAtlas/PropertyAtlas
git commit -m "refactor(data): rename legacy Photo → VisitPhoto"
```

---

## Task 4: Dataset @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/DatasetTests.swift`

- [ ] **Step 1: 写 failing test**

```swift
// PropertyAtlas/PropertyAtlasTests/Models/DatasetTests.swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct DatasetTests {
    @Test func datasetPersistsAndFetches() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self])
        let ctx = ModelContext(container)
        let ds = Dataset(name: "天津 demo")
        ctx.insert(ds)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(all.count == 1)
        #expect(all.first?.name == "天津 demo")
        #expect(all.first?.deleted == false)
        #expect(all.first?.version == 1)
    }

    @Test func datasetActiveThemeIdOptionalDefaultsNil() throws {
        let ds = Dataset(name: "x")
        #expect(ds.activeThemeId == nil)
        #expect(ds.activeCameraPresetId == nil)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/DatasetTests 2>&1 | tail -20`
Expected: FAIL — `Cannot find 'Dataset' in scope`

- [ ] **Step 3: 实现 Dataset**

```swift
// PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift
import Foundation
import SwiftData

@Model
final class Dataset {
    var id: UUID = UUID()
    var name: String = ""
    var activeThemeId: UUID?
    var activeCameraPresetId: UUID?
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/DatasetTests 2>&1 | tail -20`
Expected: 2 PASS

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift PropertyAtlas/PropertyAtlasTests/Models/DatasetTests.swift
git commit -m "feat(data): add Dataset @Model"
```

---

## Task 5: Tag @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Core/Tag.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/TagTests.swift`

- [ ] **Step 1: Failing test**

```swift
// PropertyAtlas/PropertyAtlasTests/Models/TagTests.swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct TagTests {
    @Test func tagPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Tag.self])
        let ctx = ModelContext(container)
        let dsId = UUID()
        let t = Tag(datasetId: dsId, category: "感受", label: "通风良好", polarity: "positive")
        ctx.insert(t)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Tag>())
        #expect(all.count == 1)
        #expect(all.first?.category == "感受")
        #expect(all.first?.polarity == "positive")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/TagTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: 实现 Tag**

```swift
// PropertyAtlas/PropertyAtlas/Models/Core/Tag.swift
import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var category: String = ""
    var label: String = ""
    var polarity: String = "neutral" // positive / neutral / negative
    var colorHex: String?
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        category: String,
        label: String,
        polarity: String = "neutral"
    ) {
        self.id = id
        self.datasetId = datasetId
        self.category = category
        self.label = label
        self.polarity = polarity
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/TagTests 2>&1 | tail -20`
Expected: PASS

```bash
git add PropertyAtlas/PropertyAtlas/Models/Core/Tag.swift PropertyAtlas/PropertyAtlasTests/Models/TagTests.swift
git commit -m "feat(data): add Tag @Model"
```

---

## Task 6: CameraPreset @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Core/CameraPreset.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/CameraPresetTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct CameraPresetTests {
    @Test func cameraPresetPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, CameraPreset.self])
        let ctx = ModelContext(container)
        let p = CameraPreset(
            datasetId: UUID(),
            name: "和平区",
            centerLat: 39.125,
            centerLon: 117.205,
            distance: 12000,
            pitch: 0,
            heading: 0
        )
        ctx.insert(p)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CameraPreset>())
        #expect(all.count == 1)
        #expect(all.first?.name == "和平区")
        #expect(all.first?.distance == 12000)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/CameraPresetTests 2>&1 | tail -20`
Expected: FAIL

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/Models/Core/CameraPreset.swift
import Foundation
import SwiftData

@Model
final class CameraPreset {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var centerLat: Double = 0
    var centerLon: Double = 0
    var distance: Double = 10000
    var pitch: Double = 0
    var heading: Double = 0
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        centerLat: Double,
        centerLon: Double,
        distance: Double,
        pitch: Double = 0,
        heading: Double = 0
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.distance = distance
        self.pitch = pitch
        self.heading = heading
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Core/CameraPreset.swift PropertyAtlas/PropertyAtlasTests/Models/CameraPresetTests.swift
git commit -m "feat(data): add CameraPreset @Model"
```

---

## Task 7: Edge @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Core/Edge.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/EdgeTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct EdgeTests {
    @Test func edgePersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Edge.self])
        let ctx = ModelContext(container)
        let dsId = UUID()
        let e = Edge(
            datasetId: dsId,
            fromId: UUID(), fromType: "compound",
            toId: UUID(), toType: "school",
            label: "对口小学",
            directed: true,
            note: "跨马路"
        )
        ctx.insert(e)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Edge>())
        #expect(all.count == 1)
        #expect(all.first?.label == "对口小学")
        #expect(all.first?.directed == true)
        #expect(all.first?.note == "跨马路")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — `Cannot find 'Edge' in scope`

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/Models/Core/Edge.swift
import Foundation
import SwiftData

@Model
final class Edge {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var fromId: UUID = UUID()
    var fromType: String = "" // "compound"/"school"/"poi"/"area"
    var toId: UUID = UUID()
    var toType: String = ""
    var label: String = ""
    var directed: Bool = false
    var note: String?
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        fromId: UUID, fromType: String,
        toId: UUID, toType: String,
        label: String,
        directed: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.datasetId = datasetId
        self.fromId = fromId
        self.fromType = fromType
        self.toId = toId
        self.toType = toType
        self.label = label
        self.directed = directed
        self.note = note
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Core/Edge.swift PropertyAtlas/PropertyAtlasTests/Models/EdgeTests.swift
git commit -m "feat(data): add Edge @Model"
```

---

## Task 8: CustomFieldDef @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Schema/CustomFieldDef.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/CustomFieldDefTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct CustomFieldDefTests {
    @Test func customFieldDefPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, CustomFieldDef.self])
        let ctx = ModelContext(container)
        let def = CustomFieldDef(
            datasetId: UUID(),
            entityType: "compound",
            key: "sourceCode",
            label: "信源",
            type: "string",
            source: "migrated"
        )
        ctx.insert(def)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
        #expect(all.count == 1)
        #expect(all.first?.key == "sourceCode")
        #expect(all.first?.source == "migrated")
        #expect(all.first?.pinnedToCard == false)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/Models/Schema/CustomFieldDef.swift
import Foundation
import SwiftData

@Model
final class CustomFieldDef {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var entityType: String = "" // "compound"/"school"/"poi"/"area"
    var key: String = ""
    var label: String = ""
    var type: String = "string" // string/multiline/int/double/bool/date/enum/tag/url/money
    var enumOptionsJSON: String?
    var unit: String?
    var defaultValueJSON: String?
    var pinnedToCard: Bool = false
    var showInLegendChip: Bool = false
    var sortOrder: Int = 0
    var source: String = "user" // "migrated"/"user"/"seed"
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        entityType: String,
        key: String,
        label: String,
        type: String = "string",
        source: String = "user"
    ) {
        self.id = id
        self.datasetId = datasetId
        self.entityType = entityType
        self.key = key
        self.label = label
        self.type = type
        self.source = source
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Schema/CustomFieldDef.swift PropertyAtlas/PropertyAtlasTests/Models/CustomFieldDefTests.swift
git commit -m "feat(data): add CustomFieldDef @Model"
```

---

## Task 9: EnumOption @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Schema/EnumOption.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/EnumOptionTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct EnumOptionTests {
    @Test func enumOptionPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, EnumOption.self])
        let ctx = ModelContext(container)
        let opt = EnumOption(
            datasetId: UUID(),
            scope: "school.category",
            label: "小学",
            sortOrder: 0,
            colorHex: "#FF3B30"
        )
        ctx.insert(opt)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<EnumOption>())
        #expect(all.first?.label == "小学")
        #expect(all.first?.colorHex == "#FF3B30")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现**

```swift
// PropertyAtlas/PropertyAtlas/Models/Schema/EnumOption.swift
import Foundation
import SwiftData

@Model
final class EnumOption {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var scope: String = "" // e.g. "school.category", "edge.label"
    var label: String = ""
    var sortOrder: Int = 0
    var colorHex: String?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        scope: String,
        label: String,
        sortOrder: Int = 0,
        colorHex: String? = nil
    ) {
        self.id = id
        self.datasetId = datasetId
        self.scope = scope
        self.label = label
        self.sortOrder = sortOrder
        self.colorHex = colorHex
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Schema/EnumOption.swift PropertyAtlas/PropertyAtlasTests/Models/EnumOptionTests.swift
git commit -m "feat(data): add EnumOption @Model"
```

---

## Task 10: Compound @Model（新版）

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Entities/Compound.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/CompoundTests.swift`

注：旧 `Models/Public/Compound.swift` 暂时保留（被 LegacyMigrator 用），稍后 Task 添加 `@available deprecated` 标记。新类名同为 `Compound`，但旧文件路径不同，靠 import 顺序解析时优先新 file（spec 路径里位置更前）。由于 Swift 同模块不允许同名 class，**Task 10 必须先把旧 `Models/Public/Compound.swift` 类名改为 `LegacyCompound`**。

- [ ] **Step 1: 把旧 Compound 改名 LegacyCompound**

Run: `grep -rn "\\bCompound\\b" PropertyAtlas/PropertyAtlas --include="*.swift" | grep -v "Models/Entities"`
浏览所有引用文件，确定影响面（PropertyAtlasApp.swift Schema，SeedImporter，StudioRootView，CompoundSchoolMatch，ZoneGeometryImporter 等）。

```bash
git mv PropertyAtlas/PropertyAtlas/Models/Public/Compound.swift PropertyAtlas/PropertyAtlas/Models/Public/LegacyCompound.swift
```

在 `LegacyCompound.swift` 内把 `final class Compound` → `final class LegacyCompound`。
然后全模块 `grep -rn "\\bCompound\\b"` 列出所有需改的引用（除 Test 文件），逐个 Edit 把对旧字段访问的代码改成 `LegacyCompound`：
- `PropertyAtlasApp.swift` Schema 数组里 `Compound.self` → `LegacyCompound.self`
- `SeedImporter.swift` 内 `Compound(...)` 构造 → `LegacyCompound(...)`
- `Studio/Layers/...` 不引用 Compound，跳过
- `States/SeedProgressView.swift` 检查
- `Models/Public/CompoundSchoolMatch.swift` 内 `compoundId: UUID` 引 UUID 不改

Run all tests, expect all pass:
`xcodebuild test ... 2>&1 | tail -30`

- [ ] **Step 2: Failing test for new Compound**

```swift
// PropertyAtlas/PropertyAtlasTests/Models/CompoundTests.swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct CompoundTests {
    @Test func compoundPersistsWithBaseFields() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Compound.self])
        let ctx = ModelContext(container)
        let c = Compound(
            datasetId: UUID(),
            name: "中海西派国印",
            latitude: 39.155,
            longitude: 117.180
        )
        c.buildYear = 2022
        c.developer = "中海"
        c.propertyFeeCents = 580
        c.customFieldsJSON = #"{"sourceCode":"YH-XLSX"}"#
        ctx.insert(c)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Compound>())
        #expect(all.first?.name == "中海西派国印")
        #expect(all.first?.buildYear == 2022)
        #expect(all.first?.propertyFeeCents == 580)
        #expect(all.first?.customFieldsJSON == #"{"sourceCode":"YH-XLSX"}"#)
        #expect(all.first?.deleted == false)
    }
}
```

- [ ] **Step 3: 跑测试确认失败**

Expected: FAIL — `Cannot find 'Compound' in scope`（旧已改名）

- [ ] **Step 4: 实现新 Compound**

```swift
// PropertyAtlas/PropertyAtlas/Models/Entities/Compound.swift
import Foundation
import CoreLocation
import SwiftData

@Model
final class Compound {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()

    // 通用 baseFields
    var name: String = ""
    var aliases: [String] = []
    var address: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var primaryAreaId: UUID?
    var notes: String?
    var privateNotes: String?
    var customFieldsJSON: String?    // {key: value}
    var overrideStyleJSON: String?   // entity 级样式覆盖
    var photoIds: [UUID] = []
    var contactPhone: String?
    var contactWechat: String?
    var contactName: String?
    var sourceUrl: String?

    // Compound-specific baseFields
    var buildYear: Int?
    var developer: String?
    var propertyMgmt: String?
    var propertyFeeCents: Int?
    var landYears: Int?
    var finishType: String?
    var deliveryTime: String?
    var isNewHouse: Bool = true
    var availableUnits: String?
    var areaSegments: String?
    var priceSegments: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

- [ ] **Step 5: 跑测试确认通过 + commit**

```bash
git add -A PropertyAtlas/PropertyAtlas PropertyAtlas/PropertyAtlasTests
git commit -m "feat(data): add new Compound @Model + rename old → LegacyCompound"
```

---

## Task 11: School @Model（新版）

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Entities/School.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/SchoolTests.swift`
- Rename: `Models/Public/School.swift` → `Models/Public/LegacySchool.swift`，类名 `School` → `LegacySchool`

类似 Task 10 模式：先把旧 `School` 改名 `LegacySchool`，再创建新 `School`。

- [ ] **Step 1: 把旧 School 改名 LegacySchool**

```bash
git mv PropertyAtlas/PropertyAtlas/Models/Public/School.swift PropertyAtlas/PropertyAtlas/Models/Public/LegacySchool.swift
```

修改类名：`final class School` → `final class LegacySchool`。

全模块 grep 引用并改：
- `PropertyAtlasApp.swift` Schema: `School.self` → `LegacySchool.self`
- `SeedImporter.swift` 构造和查询
- `Studio/Layers/SchoolAnnotation.swift` & `SchoolPinView.swift` 引用 `school: School` → 改 `school: LegacySchool`（暂时；后续 Task 25 LegacyShim 替换）
- `Studio/SchoolDetailCard.swift` 同
- `RootView.swift` 内 `@Query private var schools: [School]` → `[LegacySchool]`
- `PropertyAtlasTests/SchoolZoneQueryTests.swift` 同步改

Run all tests; expect PASS.

- [ ] **Step 2: Failing test for new School**

```swift
// PropertyAtlas/PropertyAtlasTests/Models/SchoolTests.swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct SchoolTests {
    @Test func schoolPersistsWithBaseFields() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, School.self])
        let ctx = ModelContext(container)
        let s = School(
            datasetId: UUID(),
            name: "鞍山道小学",
            latitude: 39.122413,
            longitude: 117.192636
        )
        s.category = "小学"
        s.grade = "重点"
        s.form = "普通"
        s.foundYear = 1954
        s.communitiesText = "静安社区, 庆有西里…"
        ctx.insert(s)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<School>())
        #expect(all.first?.name == "鞍山道小学")
        #expect(all.first?.category == "小学")
        #expect(all.first?.grade == "重点")
        #expect(all.first?.form == "普通")
        #expect(all.first?.foundYear == 1954)
    }
}
```

- [ ] **Step 3: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 4: 实现新 School**

```swift
// PropertyAtlas/PropertyAtlas/Models/Entities/School.swift
import Foundation
import CoreLocation
import SwiftData

@Model
final class School {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()

    var name: String = ""
    var aliases: [String] = []
    var address: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var primaryAreaId: UUID?
    var notes: String?
    var privateNotes: String?
    var customFieldsJSON: String?
    var overrideStyleJSON: String?
    var photoIds: [UUID] = []
    var contactPhone: String?
    var contactWechat: String?
    var contactName: String?
    var sourceUrl: String?

    // School-specific baseFields
    var category: String?      // enum, e.g. 小学/初中/幼儿园 (EnumOption "school.category")
    var grade: String?         // enum, e.g. 重点/区重点/普通 (EnumOption "school.grade")
    var form: String?          // enum, e.g. 普通/九年一贯/十二年制 (EnumOption "school.form")
    var foundYear: Int?
    var capacity: Int?
    var communitiesText: String?
    var phone: String?
    var websiteUrl: String?
    var motto: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

- [ ] **Step 5: 跑测试确认通过 + commit**

```bash
git add -A PropertyAtlas/PropertyAtlas PropertyAtlas/PropertyAtlasTests
git commit -m "feat(data): add new School @Model + rename old → LegacySchool"
```

---

## Task 12: POI @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Entities/POI.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/POITests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct POITests {
    @Test func poiPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, POI.self])
        let ctx = ModelContext(container)
        let p = POI(
            datasetId: UUID(),
            name: "营口道地铁站",
            latitude: 39.1234,
            longitude: 117.2010
        )
        p.category = "地铁站"
        ctx.insert(p)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<POI>())
        #expect(all.first?.name == "营口道地铁站")
        #expect(all.first?.category == "地铁站")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 POI**

```swift
// PropertyAtlas/PropertyAtlas/Models/Entities/POI.swift
import Foundation
import CoreLocation
import SwiftData

@Model
final class POI {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()

    var name: String = ""
    var aliases: [String] = []
    var address: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var primaryAreaId: UUID?
    var notes: String?
    var privateNotes: String?
    var customFieldsJSON: String?
    var overrideStyleJSON: String?
    var photoIds: [UUID] = []
    var contactPhone: String?
    var contactWechat: String?
    var contactName: String?
    var sourceUrl: String?

    // POI-specific
    var category: String?     // 中介自定义 enum (EnumOption "poi.category")

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

- [ ] **Step 4: 跑测试通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Entities/POI.swift PropertyAtlas/PropertyAtlasTests/Models/POITests.swift
git commit -m "feat(data): add POI @Model"
```

---

## Task 13: Area @Model（替代 SchoolZone）

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Entities/Area.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/AreaTests.swift`
- Rename: `Models/Public/SchoolZone.swift` → `Models/Public/LegacySchoolZone.swift`，类名 → `LegacySchoolZone`

- [ ] **Step 1: 改旧 SchoolZone → LegacySchoolZone**

```bash
git mv PropertyAtlas/PropertyAtlas/Models/Public/SchoolZone.swift PropertyAtlas/PropertyAtlas/Models/Public/LegacySchoolZone.swift
```

修改 `final class SchoolZone` → `final class LegacySchoolZone`。`extension GeoJSONHelper` 不改名。

全模块 grep `SchoolZone` 改名：
- `PropertyAtlasApp.swift` Schema
- `SeedImporter.swift`
- `Studio/Layers/ZoneGeometryImporter.swift`
- `RootView.swift` `@Query private var zones: [SchoolZone]` → `[LegacySchoolZone]`
- `PropertyAtlasTests/SchoolZoneQueryTests.swift`
- `PropertyAtlasTests/GeoJSONTests.swift` 不改（用 GeoJSONHelper）

Run all tests, expect PASS.

- [ ] **Step 2: Failing test for new Area**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct AreaTests {
    @Test func areaPersistsWithGeometry() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Area.self])
        let ctx = ModelContext(container)
        let a = Area(
            datasetId: UUID(),
            name: "第一学片",
            geometryKind: "polygon",
            geometryJSON: #"{"type":"Polygon","coordinates":[[[117.1,39.1],[117.2,39.1],[117.2,39.2],[117.1,39.2],[117.1,39.1]]]}"#
        )
        a.category = "片区"
        a.strokeHex = "#FF3B30"
        a.fillOpacity = 0.2
        ctx.insert(a)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Area>())
        #expect(all.first?.name == "第一学片")
        #expect(all.first?.geometryKind == "polygon")
        #expect(all.first?.fillOpacity == 0.2)
    }
}
```

- [ ] **Step 3: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 4: 实现 Area**

```swift
// PropertyAtlas/PropertyAtlas/Models/Entities/Area.swift
import Foundation
import SwiftData

@Model
final class Area {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()

    var name: String = ""
    var aliases: [String] = []
    var notes: String?
    var privateNotes: String?
    var customFieldsJSON: String?
    var overrideStyleJSON: String?
    var photoIds: [UUID] = []
    var sourceUrl: String?

    // Area geometry
    var geometryKind: String = "polygon" // "polygon" / "raster"
    var geometryJSON: String = ""        // GeoJSON polygon OR raster {image,corners}
    var rasterImageRef: String?          // bundled resource name 或 file URL

    // Area-specific
    var category: String?                // EnumOption "area.category"
    var strokeHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        geometryKind: String = "polygon",
        geometryJSON: String = ""
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.geometryKind = geometryKind
        self.geometryJSON = geometryJSON
    }
}
```

- [ ] **Step 5: 跑测试确认通过 + commit**

```bash
git add -A PropertyAtlas/PropertyAtlas PropertyAtlas/PropertyAtlasTests
git commit -m "feat(data): add Area @Model + rename old SchoolZone → LegacySchoolZone"
```

---

## Task 14: StyleRule @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Style/StyleRule.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/StyleRuleTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct StyleRuleTests {
    @Test func styleRulePersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, StyleRule.self])
        let ctx = ModelContext(container)
        let r = StyleRule(
            datasetId: UUID(),
            name: "重点小学 红方",
            entityType: "school"
        )
        r.conditionsJSON = #"[{"field":"grade","op":"equals","value":"重点"}]"#
        r.appliesShape = "square"
        r.appliesFillMode = "fixed"
        r.appliesFillHex = "#FF3B30"
        r.appliesGlyph = "重"
        r.priority = 10
        ctx.insert(r)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<StyleRule>())
        #expect(all.first?.appliesShape == "square")
        #expect(all.first?.priority == 10)
        #expect(all.first?.enabled == true)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 StyleRule**

```swift
// PropertyAtlas/PropertyAtlas/Models/Style/StyleRule.swift
import Foundation
import SwiftData

@Model
final class StyleRule {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var entityType: String = ""
    var conditionsJSON: String = "[]"
    var priority: Int = 0
    var appliesShape: String?
    var appliesFillMode: String = "fixed" // "fixed" / "palette"
    var appliesFillHex: String?
    var appliesPaletteId: UUID?
    var appliesPaletteKeyField: String?
    var appliesStrokeHex: String?
    var appliesGlyph: String?
    var appliesGlyphHex: String?
    var appliesSize: Int?
    var appliesLabelVisible: Bool?
    var appliesFillOpacity: Double?
    var appliesStrokeWidth: Double?
    var enabled: Bool = true
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        entityType: String
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.entityType = entityType
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Style/StyleRule.swift PropertyAtlas/PropertyAtlasTests/Models/StyleRuleTests.swift
git commit -m "feat(data): add StyleRule @Model"
```

---

## Task 15: Palette @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Style/Palette.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/PaletteTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct PaletteTests {
    @Test func palettePersists() throws {
        let container = try TestContainer.makeInMemory(for: [Palette.self])
        let ctx = ModelContext(container)
        let p = Palette(
            name: "default-rainbow",
            colorsHex: ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#5AC8FA", "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E"],
            builtIn: true
        )
        ctx.insert(p)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Palette>())
        #expect(all.first?.colorsHex.count == 10)
        #expect(all.first?.builtIn == true)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 Palette**

```swift
// PropertyAtlas/PropertyAtlas/Models/Style/Palette.swift
import Foundation
import SwiftData

@Model
final class Palette {
    var id: UUID = UUID()
    var name: String = ""
    var colorsHex: [String] = []
    var builtIn: Bool = false
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        colorsHex: [String],
        builtIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorsHex = colorsHex
        self.builtIn = builtIn
    }
}
```

注：Palette 不带 `datasetId` — 跨 dataset 共享（spec § 5.3 描述）。

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Style/Palette.swift PropertyAtlas/PropertyAtlasTests/Models/PaletteTests.swift
git commit -m "feat(data): add Palette @Model"
```

---

## Task 16: Theme @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Style/Theme.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/ThemeTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct ThemeTests {
    @Test func themePersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Theme.self])
        let ctx = ModelContext(container)
        let t = Theme(
            datasetId: UUID(),
            name: "学区视图"
        )
        t.visibilityJSON = #"{"compound":true,"school":true,"poi":false,"area":true}"#
        t.styleRuleIds = [UUID(), UUID()]
        t.defaultEnabledLayerIds = [UUID()]
        t.copyTitle = "和平区学区分布图"
        t.bgMapStyle = "satellite"
        ctx.insert(t)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Theme>())
        #expect(all.first?.name == "学区视图")
        #expect(all.first?.styleRuleIds.count == 2)
        #expect(all.first?.defaultEnabledLayerIds.count == 1)
        #expect(all.first?.spotlightOnSelect == true)
        #expect(all.first?.bgMapStyle == "satellite")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 Theme**

```swift
// PropertyAtlas/PropertyAtlas/Models/Style/Theme.swift
import Foundation
import SwiftData

@Model
final class Theme {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var isActive: Bool = false
    var cameraPresetId: UUID?
    var styleRuleIds: [UUID] = []
    var defaultStylesJSON: String = "{}"
    var visibilityJSON: String = #"{"compound":true,"school":true,"poi":true,"area":true}"#
    var defaultEnabledLayerIds: [UUID] = []
    var spotlightOnSelect: Bool = true
    var drawEdgeLines: [String] = []
    var showLegend: Bool = true
    var bgMapStyle: String = "standard"
    var copyTitle: String?
    var copySubtitle: String?
    var copyWatermark: String?
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Style/Theme.swift PropertyAtlas/PropertyAtlasTests/Models/ThemeTests.swift
git commit -m "feat(data): add Theme @Model"
```

---

## Task 17: Layer @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Display/Layer.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/LayerTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct LayerTests {
    @Test func layerPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Layer.self])
        let ctx = ModelContext(container)
        let l = Layer(
            datasetId: UUID(),
            name: "重点学校"
        )
        l.iconSF = "star.fill"
        l.colorHex = "#FF3B30"
        l.minZoom = 0
        l.maxZoom = 21
        l.dynamicQueryJSON = #"{"entityType":"school","conditions":[{"field":"grade","op":"equals","value":"重点"}]}"#
        ctx.insert(l)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Layer>())
        #expect(all.first?.name == "重点学校")
        #expect(all.first?.maxZoom == 21)
        #expect(all.first?.isDefault == false)
        #expect(all.first?.enabled == true)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 Layer**

```swift
// PropertyAtlas/PropertyAtlas/Models/Display/Layer.swift
import Foundation
import SwiftData

@Model
final class Layer {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var iconSF: String?
    var colorHex: String?
    var staticRefsJSON: String?      // [{entityId, entityType}]
    var dynamicQueryJSON: String?    // {entityType, conditions:[...]}
    var minZoom: Double?
    var maxZoom: Double?
    var isDefault: Bool = false
    var enabled: Bool = true
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Display/Layer.swift PropertyAtlas/PropertyAtlasTests/Models/LayerTests.swift
git commit -m "feat(data): add Layer @Model"
```

---

## Task 18: FilterFieldConfig @Model

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Display/FilterFieldConfig.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/FilterFieldConfigTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct FilterFieldConfigTests {
    @Test func filterFieldConfigPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, FilterFieldConfig.self])
        let ctx = ModelContext(container)
        let f = FilterFieldConfig(
            datasetId: UUID(),
            entityType: "school",
            fieldKey: "grade",
            fieldSource: "base",
            label: "等级",
            slot: 2
        )
        ctx.insert(f)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<FilterFieldConfig>())
        #expect(all.first?.fieldKey == "grade")
        #expect(all.first?.slot == 2)
        #expect(all.first?.showInLegend == true)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 FilterFieldConfig**

```swift
// PropertyAtlas/PropertyAtlas/Models/Display/FilterFieldConfig.swift
import Foundation
import SwiftData

@Model
final class FilterFieldConfig {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var entityType: String = ""
    var fieldKey: String = ""
    var fieldSource: String = "base" // "base" / "custom"
    var label: String = ""
    var slot: Int = 1                // 1/2/3
    var showInLegend: Bool = true
    var showSwatch: Bool = true
    var expandedByDefault: Bool = true
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        entityType: String,
        fieldKey: String,
        fieldSource: String = "base",
        label: String,
        slot: Int
    ) {
        self.id = id
        self.datasetId = datasetId
        self.entityType = entityType
        self.fieldKey = fieldKey
        self.fieldSource = fieldSource
        self.label = label
        self.slot = slot
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Display/FilterFieldConfig.swift PropertyAtlas/PropertyAtlasTests/Models/FilterFieldConfigTests.swift
git commit -m "feat(data): add FilterFieldConfig @Model"
```

---

## Task 19: Photo @Model（新通用媒体）

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Media/Photo.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/PhotoTests.swift`

- [ ] **Step 1: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct PhotoTests {
    @Test func photoPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Photo.self])
        let ctx = ModelContext(container)
        let p = Photo(
            ownerEntityId: UUID(),
            ownerEntityType: "compound",
            url: "file:///tmp/test.heic"
        )
        p.caption = "正门"
        p.order = 1
        ctx.insert(p)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Photo>())
        #expect(all.first?.ownerEntityType == "compound")
        #expect(all.first?.caption == "正门")
        #expect(all.first?.order == 1)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — `Cannot find 'Photo' in scope`（旧 Photo 已改名 VisitPhoto，新 Photo 未建）

- [ ] **Step 3: 实现 Photo**

```swift
// PropertyAtlas/PropertyAtlas/Models/Media/Photo.swift
import Foundation
import SwiftData

@Model
final class Photo {
    var id: UUID = UUID()
    var ownerEntityId: UUID = UUID()
    var ownerEntityType: String = "" // "compound"/"school"/"poi"/"area"
    var url: String = ""             // file:// or asset ref
    @Attribute(.externalStorage) var heicData: Data?
    var caption: String?
    var takenAt: Date?
    var width: Int?
    var height: Int?
    var order: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        ownerEntityId: UUID,
        ownerEntityType: String,
        url: String
    ) {
        self.id = id
        self.ownerEntityId = ownerEntityId
        self.ownerEntityType = ownerEntityType
        self.url = url
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Media/Photo.swift PropertyAtlas/PropertyAtlasTests/Models/PhotoTests.swift
git commit -m "feat(data): add Photo (generic media) @Model"
```

---

## Task 20: Document @Model（替代 AdmissionDoc）

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Media/Document.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/Models/DocumentTests.swift`
- Rename: `Models/Public/AdmissionDoc.swift` → `Models/Public/LegacyAdmissionDoc.swift`，类名 `AdmissionDoc` → `LegacyAdmissionDoc`

- [ ] **Step 1: 改旧 AdmissionDoc → LegacyAdmissionDoc**

```bash
git mv PropertyAtlas/PropertyAtlas/Models/Public/AdmissionDoc.swift PropertyAtlas/PropertyAtlas/Models/Public/LegacyAdmissionDoc.swift
```

修改类名。全模块 grep `AdmissionDoc`：
- `PropertyAtlasApp.swift` Schema: `AdmissionDoc.self` → `LegacyAdmissionDoc.self`

Run all tests, expect PASS.

- [ ] **Step 2: Failing test**

```swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct DocumentTests {
    @Test func documentPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Document.self])
        let ctx = ModelContext(container)
        let d = Document(
            ownerEntityId: UUID(),
            ownerEntityType: "area",
            kind: "pdf",
            title: "2024 招生简章",
            url: "file:///tmp/test.pdf"
        )
        d.ocrText = "和平区..."
        ctx.insert(d)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Document>())
        #expect(all.first?.title == "2024 招生简章")
        #expect(all.first?.kind == "pdf")
    }
}
```

- [ ] **Step 3: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 4: 实现 Document**

```swift
// PropertyAtlas/PropertyAtlas/Models/Media/Document.swift
import Foundation
import SwiftData

@Model
final class Document {
    var id: UUID = UUID()
    var ownerEntityId: UUID = UUID()
    var ownerEntityType: String = "" // "compound"/"school"/"poi"/"area"
    var kind: String = "pdf"         // "pdf" / "richtext" / "image" / "other"
    var title: String = ""
    var url: String = ""
    @Attribute(.externalStorage) var data: Data?
    var ocrText: String?
    var mimeType: String?
    var pageCount: Int?
    var order: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        ownerEntityId: UUID,
        ownerEntityType: String,
        kind: String,
        title: String,
        url: String = ""
    ) {
        self.id = id
        self.ownerEntityId = ownerEntityId
        self.ownerEntityType = ownerEntityType
        self.kind = kind
        self.title = title
        self.url = url
    }
}
```

- [ ] **Step 5: 跑测试确认通过 + commit**

```bash
git add -A PropertyAtlas/PropertyAtlas PropertyAtlas/PropertyAtlasTests
git commit -m "feat(data): add Document + rename old AdmissionDoc → LegacyAdmissionDoc"
```

---

## Task 21: ModelSchema.swift — 新 ModelContainer factory

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift`

- [ ] **Step 1: 实现**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift
import Foundation
import SwiftData

enum ModelSchema {
    /// 新 schema: 新 @Model + Legacy* (供 LegacyMigrator 读) + 现存 User/* (orthogonal)
    static let allTypes: [any PersistentModel.Type] = [
        // New core
        Dataset.self, Edge.self, Tag.self, CameraPreset.self,
        // New entities
        Compound.self, School.self, POI.self, Area.self,
        // New style
        StyleRule.self, Palette.self, Theme.self,
        // New display
        Layer.self, FilterFieldConfig.self,
        // New schema
        CustomFieldDef.self, EnumOption.self,
        // New media
        Photo.self, Document.self,
        // Legacy (read-only during migration; removed in P5)
        LegacyCompound.self, LegacySchool.self, LegacySchoolZone.self,
        LegacyAdmissionDoc.self,
        AdmissionRate.self, BuiltinTag.self, CompoundSchoolMatch.self,
        Policy.self, SchoolGroup.self, SchoolScore.self,
        // User/* (orthogonal; untouched in P1)
        VisitPhoto.self, PropertyMark.self, Visit.self, TagExtension.self,
        VisitTag.self, UserArea.self, ShareSubmission.self,
    ]

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(allTypes)
        #if targetEnvironment(macCatalyst)
        // P1: 保持 .none, P5 切换 .private(...)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        #else
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.fujie.propertyatlas")
        )
        #endif
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 2: 改 PropertyAtlasApp.swift 用 ModelSchema**

```swift
// 在 PropertyAtlasApp.swift init() 里
init() {
    do {
        container = try ModelSchema.makeContainer()
        // 调试: 写 store 路径 (不变)
        var debugInfo = "Home: \(NSHomeDirectory())\n"
        debugInfo += "AppSupport: \(URL.applicationSupportDirectory.path)\n"
        for cfg in container.configurations {
            debugInfo += "StoreURL: \(cfg.url.path)\n"
        }
        try? debugInfo.write(
            toFile: "/tmp/propertyatlas_paths.txt",
            atomically: true,
            encoding: .utf8
        )
    } catch {
        fatalError("ModelContainer init failed: \(error)")
    }
}
```

把 `let schema = Schema([...])` 那段删除（已迁到 ModelSchema）。

- [ ] **Step 3: 跑全测确认通过**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -30`
Expected: all green

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift PropertyAtlas/PropertyAtlas/PropertyAtlasApp.swift
git commit -m "feat(data): centralize ModelContainer schema via ModelSchema"
```

---

## Task 22: LegacyShim — 给旧 Studio 用的新 entity adapter

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/LegacyShim.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyShimTests.swift`

旧 `SchoolPinView` / `StudioRootView` / `SchoolDetailCard` 等读 `school.type/tier/zoneId/isJiunian`。LegacyShim 通过 extension 给新 `School` 加这些 computed 字段，使旧 UI 不改动即可运行。

- [ ] **Step 1: Failing test**

```swift
// PropertyAtlas/PropertyAtlasTests/DataKit/LegacyShimTests.swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct LegacyShimTests {
    @Test func schoolLegacyTypeReadsFromCategory() throws {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.category = "小学"
        #expect(s.legacyType == "小学")
    }

    @Test func schoolLegacyTierReadsFromGrade() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        #expect(s.legacyTier == "重点")
    }

    @Test func schoolLegacyTierDefaultsToPutongWhenGradeNil() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        #expect(s.legacyTier == "普通")
    }

    @Test func schoolLegacyIsJiunianReadsFromForm() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.form = "九年一贯"
        #expect(s.legacyIsJiunian == true)
        s.form = "普通"
        #expect(s.legacyIsJiunian == false)
    }

    @Test func schoolLegacyZoneIdReadsFromPrimaryAreaId() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let id = UUID()
        s.primaryAreaId = id
        #expect(s.legacyZoneId == id)
    }

    @Test func compoundLegacyZoneIdReadsFromPrimaryAreaId() {
        let c = Compound(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let id = UUID()
        c.primaryAreaId = id
        #expect(c.legacyZoneId == id)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — `Value of type 'School' has no member 'legacyType'`

- [ ] **Step 3: 实现 LegacyShim**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/LegacyShim.swift
import Foundation

/// 把新 entity 字段映射成旧字段名, 让 P1 之前的 Studio UI (SchoolPinView,
/// StudioRootView, SchoolDetailCard, ZoneGeometryImporter 等) 不改动地读
/// 新数据. P2 替换为 StyleResolver 后, 整个 LegacyShim 可删.
extension School {
    /// 旧 `School.type` = 新 `category`
    var legacyType: String { category ?? "" }

    /// 旧 `School.tier` ∈ {重点, 区重点, 普通}; 缺省 = 普通
    var legacyTier: String { grade ?? "普通" }

    /// 旧 `School.isJiunian` = 新 `form == "九年一贯"`
    var legacyIsJiunian: Bool { form == "九年一贯" }

    /// 旧 `School.is12Year` = 新 `form == "十二年制"`
    var legacyIs12Year: Bool { form == "十二年制" }

    /// 旧 `School.zoneId` = 新 `primaryAreaId`
    var legacyZoneId: UUID? { primaryAreaId }

    /// 旧 `School.zoneName` — 由 Area name lookup 不在 entity 上;
    /// 调用方需查 Area dataset. 这里返回 nil 占位.
    var legacyZoneName: String? { nil }

    /// 旧 `School.district` — 不再 baseField; 调用方查 primaryArea 行政区.
    var legacyDistrict: String { "" }

    /// 旧 `School.lat` / `lon` — 直接映射
    var lat: Double? { latitude == 0 ? nil : latitude }
    var lon: Double? { longitude == 0 ? nil : longitude }
}

extension Compound {
    var legacyZoneId: UUID? { primaryAreaId }
    var legacyDistrict: String { "" }
    var legacyPrimarySchoolId: UUID? { nil } // P4 才有 Edge 查询
}

extension Area {
    /// 旧 `SchoolZone.primaryDistrict` — 不再 baseField; 沿用 ""
    var legacyPrimaryDistrict: String { "" }

    /// 旧 `SchoolZone.geometryStage` — 不再有, 用 geometryKind 暴露
    var legacyGeometryStage: String { geometryKind == "raster" ? "raster" : "hull" }

    /// 旧 `SchoolZone.tier` — 不再 baseField; 默认 "普通"
    var legacyTier: String { "普通" }

    /// 旧 `SchoolZone.geometry` — 同 geometryJSON
    var legacyGeometry: String { geometryJSON }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyShim.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyShimTests.swift
git commit -m "feat(data): add LegacyShim adapters for legacy Studio UI"
```

---

## Task 23: 旧 Studio UI 切到新 entity + LegacyShim

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Layers/SchoolAnnotation.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Layers/SchoolPinView.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Layers/ZoneGeometryImporter.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/SchoolDetailCard.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/StudioLegend.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/PinFilter.swift`
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`

这些文件目前用 `LegacySchool`（Task 11 重命名后）。本 Task 把它们改用新 `School`，字段访问换为 `legacyXxx` shim。

- [ ] **Step 1: 检查所有 LegacySchool/LegacySchoolZone/LegacyCompound 引用**

Run: `grep -rn "Legacy\\(School\\|SchoolZone\\|Compound\\|AdmissionDoc\\)" PropertyAtlas/PropertyAtlas --include="*.swift" | grep -v Models/Public`

- [ ] **Step 2: 在所有 Studio + RootView 文件里把 LegacySchool 改成 School，字段访问加 legacy 前缀**

具体改法（每文件用 Edit 工具逐处替换）：

`SchoolPinView.swift` 中 `s.type` → `s.legacyType`，`s.tier` → `s.legacyTier`，`s.isJiunian` → `s.legacyIsJiunian`。

`SchoolAnnotation.swift` 中 `class SchoolAnnotation { let school: LegacySchool ...}` → `let school: School`。所有 `school.xxx` 读取按 shim 改。

`ZoneGeometryImporter.swift` 接受 `LegacySchoolZone` → `Area`，字段 `geometry/geometryStage/geometrySimplified` 用 `area.legacyGeometry`/`area.legacyGeometryStage`/`area.geometryJSON`。

`StudioLegend.swift` filter 类型 `[LegacySchool]` → `[School]`，访问 `.type/.tier/.isJiunian` 改 shim。

`PinFilter.swift` `func includes(school: LegacySchool)` → `includes(school: School)`，`school.tier` → `school.legacyTier`, `school.type` → `school.legacyType`, `school.isJiunian` → `school.legacyIsJiunian`。

`SchoolDetailCard.swift` `@Query private var schools: [LegacySchool]` → `[School]`。

`RootView.swift` `@Query private var schools: [LegacySchool]` → `[School]`，`@Query private var zones: [LegacySchoolZone]` → `[Area]`。`computeVisibleZones` 内 `school.type/tier/zoneId` 换 shim。

- [ ] **Step 3: 跑全测 + run Studio (Mac Catalyst) 确认 UI 没回归**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -30`
Expected: 编译通过 + 现有测试都 PASS。

如可在 Mac Catalyst 启动 app：观察 Studio 取景界面应仍可显示空 dataset（因为没新数据），但 chrome 不崩。

- [ ] **Step 4: Commit**

```bash
git add -A PropertyAtlas/PropertyAtlas
git commit -m "refactor(studio): switch legacy Studio UI to new entities via LegacyShim"
```

---

## Task 24: LegacyMigrator — Stage 1: detect & create Dataset

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Create: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: Failing test**

```swift
// PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
import Testing
import SwiftData
import Foundation
@testable import PropertyAtlas

@MainActor
struct LegacyMigratorTests {
    @Test func migrateCreatesTianjinDemoDatasetWhenLegacyDataExists() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        // Seed minimal legacy data
        let lc = LegacyCompound(name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.count == 1)
        #expect(datasets.first?.name == "天津 demo")
    }

    @Test func migrateIsIdempotent() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let lc = LegacyCompound(name: "测试小区", district: "和平区", latitude: 39.1, longitude: 117.2)
        ctx.insert(lc)
        try ctx.save()
        try LegacyMigrator.run(in: ctx)
        try LegacyMigrator.run(in: ctx)
        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.count == 1)
    }

    @Test func migrateNoOpWhenNoLegacyDataAndNoExistingDataset() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        try LegacyMigrator.run(in: ctx)
        let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
        #expect(datasets.isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — `Cannot find 'LegacyMigrator'`

- [ ] **Step 3: 实现 LegacyMigrator stage 1**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift
import Foundation
import SwiftData

/// One-shot migration from legacy @Model (Models/Public/Legacy*) to new
/// @Model (Models/Entities/*, Core/*, ...). Idempotent. Run on launch
/// before SeedImporter.
@MainActor
enum LegacyMigrator {
    static let datasetName = "天津 demo"

    static func run(in ctx: ModelContext) throws {
        // Idempotent: skip if Dataset already exists
        if try !ctx.fetch(FetchDescriptor<Dataset>()).isEmpty {
            return
        }
        // No-op when no legacy data
        let hasLegacy = try !ctx.fetch(FetchDescriptor<LegacyCompound>()).isEmpty
            || !ctx.fetch(FetchDescriptor<LegacySchool>()).isEmpty
            || !ctx.fetch(FetchDescriptor<LegacySchoolZone>()).isEmpty
        if !hasLegacy { return }

        let dataset = Dataset(name: datasetName)
        ctx.insert(dataset)
        // Future stages populate entities under this dataset.id
        try ctx.save()
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 1 — dataset detection + creation"
```

---

## Task 25: LegacyMigrator — Stage 2: SchoolZone → Area

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
// Append to LegacyMigratorTests.swift
@Test func migrateConvertsSchoolZonesToAreas() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let lz = LegacySchoolZone(
        name: "第一学片",
        tier: "重点",
        primaryDistrict: "和平区",
        geometry: #"{"type":"Polygon","coordinates":[[[117.1,39.1],[117.2,39.1],[117.2,39.2],[117.1,39.2],[117.1,39.1]]]}"#,
        geometryStage: "hull"
    )
    lz.residencyYears = 3
    lz.fillOpacity = 0.3
    lz.textDescription = "包含...居委会"
    ctx.insert(lz)
    // Seed a LegacyCompound to trigger migration
    let lc = LegacyCompound(name: "dummy", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let areas = try ctx.fetch(FetchDescriptor<Area>())
    #expect(areas.contains { $0.name == "第一学片" })
    let area = areas.first { $0.name == "第一学片" }!
    #expect(area.geometryKind == "polygon")
    #expect(area.fillOpacity == 0.3)
    #expect(area.textDescription == "包含...居委会")
    // residencyYears + tier 被迁到 customField
    let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
    #expect(defs.contains { $0.key == "residencyYears" })
    #expect(defs.contains { $0.key == "tier" })
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — area count 0

- [ ] **Step 3: 实现 stage 2**

修改 `LegacyMigrator.swift`：

```swift
@MainActor
enum LegacyMigrator {
    static let datasetName = "天津 demo"

    static func run(in ctx: ModelContext) throws {
        if try !ctx.fetch(FetchDescriptor<Dataset>()).isEmpty { return }
        let hasLegacy = try !ctx.fetch(FetchDescriptor<LegacyCompound>()).isEmpty
            || !ctx.fetch(FetchDescriptor<LegacySchool>()).isEmpty
            || !ctx.fetch(FetchDescriptor<LegacySchoolZone>()).isEmpty
        if !hasLegacy { return }

        let dataset = Dataset(name: datasetName)
        ctx.insert(dataset)
        try migrateAreas(dataset: dataset, in: ctx)
        try ctx.save()
    }

    // MARK: stage 2 — SchoolZone → Area
    private static func migrateAreas(dataset: Dataset, in ctx: ModelContext) throws {
        let zones = try ctx.fetch(FetchDescriptor<LegacySchoolZone>())
        for z in zones {
            let area = Area(
                datasetId: dataset.id,
                name: z.name,
                geometryKind: z.geometryStage == "raster" ? "raster" : "polygon",
                geometryJSON: z.geometry
            )
            area.id = z.id // preserve id for edges later
            area.fillOpacity = z.fillOpacity
            area.textDescription = z.textDescription
            area.strokeHex = z.strokeColorHex
            area.privateNotes = [z.sensitiveHighlight, z.sensitiveSource, z.sensitiveNote]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
                .ifEmpty(nil)
            // 迁移 residencyYears + tier → customField
            var customFields: [String: AnyJSON] = [:]
            if let y = z.residencyYears {
                customFields["residencyYears"] = .int(y)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "area",
                    key: "residencyYears",
                    label: "居住年限",
                    type: "int",
                    unit: "年",
                    in: ctx
                )
            }
            if !z.tier.isEmpty, z.tier != "普通" {
                customFields["tier"] = .string(z.tier)
                registerCustomFieldDef(
                    datasetId: dataset.id,
                    entityType: "area",
                    key: "tier",
                    label: "学片级别",
                    type: "string",
                    unit: nil,
                    in: ctx
                )
            }
            if !customFields.isEmpty {
                area.customFieldsJSON = try? JSONHelpers.encode(customFields)
            }
            ctx.insert(area)
        }
    }

    private static func registerCustomFieldDef(
        datasetId: UUID,
        entityType: String,
        key: String,
        label: String,
        type: String,
        unit: String?,
        in ctx: ModelContext
    ) {
        let existing = try? ctx.fetch(FetchDescriptor<CustomFieldDef>(
            predicate: #Predicate { $0.datasetId == datasetId && $0.entityType == entityType && $0.key == key }
        ))
        if existing?.isEmpty == false { return }
        let def = CustomFieldDef(
            datasetId: datasetId,
            entityType: entityType,
            key: key,
            label: label,
            type: type,
            source: "migrated"
        )
        def.unit = unit
        ctx.insert(def)
    }
}

private extension String {
    func ifEmpty(_ fallback: String?) -> String? {
        isEmpty ? fallback : self
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 2 — SchoolZone → Area + customField"
```

---

## Task 26: LegacyMigrator — Stage 3: School → School (new) + customField

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateConvertsLegacySchoolsToNewSchools() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    // 用 LegacySchool 构造 — 注意 LegacySchool 是旧 School 改名得来
    let ls = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
    ls.lat = 39.122
    ls.lon = 117.193
    ls.isJiunian = false
    ls.is12Year = false
    ls.isMarketKey = true
    ls.communitiesText = "静安社区..."
    ls.foundedYear = 1954
    ctx.insert(ls)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let schools = try ctx.fetch(FetchDescriptor<School>())
    #expect(schools.count == 1)
    let s = schools.first!
    #expect(s.name == "鞍山道小学")
    #expect(s.category == "小学")
    #expect(s.grade == "重点")
    #expect(s.form == "普通")
    #expect(s.latitude == 39.122)
    #expect(s.longitude == 117.193)
    #expect(s.foundYear == 1954)
    // isMarketKey → customField
    let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
        .filter { $0.entityType == "school" }
    #expect(defs.contains { $0.key == "isMarketKey" })
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — schools count 0

- [ ] **Step 3: 实现 stage 3**

在 `LegacyMigrator.run` 里追加：

```swift
try migrateSchools(dataset: dataset, in: ctx)
```

新方法：

```swift
private static func migrateSchools(dataset: Dataset, in ctx: ModelContext) throws {
    let legacySchools = try ctx.fetch(FetchDescriptor<LegacySchool>())
    for ls in legacySchools {
        let s = School(
            datasetId: dataset.id,
            name: ls.name,
            latitude: ls.lat ?? 0,
            longitude: ls.lon ?? 0
        )
        s.id = ls.id
        s.category = ls.type.isEmpty ? nil : ls.type
        s.grade = ls.tier.isEmpty ? nil : ls.tier
        s.form = ls.is12Year ? "十二年制" : (ls.isJiunian ? "九年一贯" : "普通")
        s.primaryAreaId = ls.zoneId
        s.address = ls.address
        s.phone = ls.phone
        s.communitiesText = ls.communitiesText
        s.foundYear = ls.foundedYear
        s.motto = ls.motto
        s.websiteUrl = ls.websiteUrl
        s.sourceUrl = ls.sourceUrl

        // privateNotes 合并 sensitive
        s.privateNotes = [
            ls.sensitiveTierLabel.map { "tierLabel: \($0)" },
            ls.sensitiveComment,
            ls.sensitiveNote,
            ls.sensitiveSource.map { "source: \($0)" }
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n").ifEmpty(nil)

        // customField 迁移
        var custom: [String: AnyJSON] = [:]
        if ls.isMarketKey {
            custom["isMarketKey"] = .bool(true)
            registerCustomFieldDef(datasetId: dataset.id, entityType: "school", key: "isMarketKey", label: "市重点", type: "bool", unit: nil, in: ctx)
        }
        if ls.isMarketFive {
            custom["isMarketFive"] = .bool(true)
            registerCustomFieldDef(datasetId: dataset.id, entityType: "school", key: "isMarketFive", label: "市五所", type: "bool", unit: nil, in: ctx)
        }
        if let c = ls.campuses, !c.isEmpty {
            custom["campuses"] = .string(c)
            registerCustomFieldDef(datasetId: dataset.id, entityType: "school", key: "campuses", label: "分校", type: "multiline", unit: nil, in: ctx)
        }
        if let t = ls.tuition, !t.isEmpty {
            custom["tuition"] = .string(t)
            registerCustomFieldDef(datasetId: dataset.id, entityType: "school", key: "tuition", label: "学费", type: "string", unit: nil, in: ctx)
        }
        if let src = ls.sourceCode, !src.isEmpty {
            custom["sourceCode"] = .string(src)
            registerCustomFieldDef(datasetId: dataset.id, entityType: "school", key: "sourceCode", label: "信源", type: "string", unit: nil, in: ctx)
        }
        if !custom.isEmpty {
            s.customFieldsJSON = try? JSONHelpers.encode(custom)
        }

        ctx.insert(s)
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 3 — School migration + customField"
```

---

## Task 27: LegacyMigrator — Stage 4: Compound → Compound (new) + customField

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateConvertsLegacyCompoundsToNewCompounds() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let lc = LegacyCompound(name: "中海西派国印", district: "河北区", latitude: 39.155, longitude: 117.190)
    lc.buildYear = 2022
    lc.developer = "中海"
    lc.propertyMgmt = "中海物业"
    lc.propertyFeeCents = 580
    lc.finishType = "毛坯/精装"
    lc.deliveryTime = "现房"
    lc.isNewHouse = true
    lc.availableUnits = "10-50"
    lc.areaSegments = "105,125,洋房133停售"
    lc.priceSegments = "一期现房105精装400万左右"
    lc.sourceCode = "YH-XLSX"
    lc.amapPoiId = "B0FFK1H7MQ"
    lc.greeningRatio = 35.0
    lc.sensitivePros = "现房, 即买即住"
    lc.sensitiveCons = "价格高"
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let compounds = try ctx.fetch(FetchDescriptor<Compound>())
    #expect(compounds.count == 1)
    let c = compounds.first!
    #expect(c.name == "中海西派国印")
    #expect(c.latitude == 39.155)
    #expect(c.longitude == 117.190)
    #expect(c.buildYear == 2022)
    #expect(c.propertyFeeCents == 580)
    #expect(c.finishType == "毛坯/精装")
    #expect(c.isNewHouse == true)
    #expect(c.privateNotes?.contains("现房") == true)
    // sourceCode + amapPoiId + greeningRatio → customField
    let defs = try ctx.fetch(FetchDescriptor<CustomFieldDef>())
        .filter { $0.entityType == "compound" }
    #expect(defs.contains { $0.key == "sourceCode" })
    #expect(defs.contains { $0.key == "amapPoiId" })
    #expect(defs.contains { $0.key == "greeningRatio" })
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 stage 4**

在 `LegacyMigrator.run` 中追加 `try migrateCompounds(dataset: dataset, in: ctx)`。

```swift
private static func migrateCompounds(dataset: Dataset, in ctx: ModelContext) throws {
    let legacy = try ctx.fetch(FetchDescriptor<LegacyCompound>())
    for lc in legacy {
        let c = Compound(
            datasetId: dataset.id,
            name: lc.name,
            latitude: lc.latitude,
            longitude: lc.longitude
        )
        c.id = lc.id
        c.aliases = lc.aliases
        c.address = lc.address
        c.primaryAreaId = lc.zoneId
        c.buildYear = lc.buildYear
        c.developer = lc.developer
        c.propertyMgmt = lc.propertyMgmt
        c.propertyFeeCents = lc.propertyFeeCents
        c.landYears = lc.landYears
        c.finishType = lc.finishType
        c.deliveryTime = lc.deliveryTime
        c.isNewHouse = lc.isNewHouse
        c.availableUnits = lc.availableUnits
        c.areaSegments = lc.areaSegments
        c.priceSegments = lc.priceSegments
        c.sourceUrl = lc.sourceUrl

        // sensitive → privateNotes
        c.privateNotes = [
            lc.sensitivePros.map { "Pros: \($0)" },
            lc.sensitiveCons.map { "Cons: \($0)" },
            lc.sensitiveSource.map { "Source: \($0)" },
            lc.sensitiveNote
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n").ifEmpty(nil)

        // customField 迁移 (非保留字段)
        var custom: [String: AnyJSON] = [:]
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "sourceCode", label: "信源", type: "string", value: lc.sourceCode, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "sourceRow", label: "信源行", type: "int", value: lc.sourceRow, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "amapPoiId", label: "高德 POI ID", type: "string", value: lc.amapPoiId, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "contributedBy", label: "贡献者", type: "string", value: lc.contributedBy, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "verifiedAt", label: "核实时间", type: "date", value: lc.verifiedAt, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "totalBuildings", label: "栋数", type: "int", value: lc.totalBuildings, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "greeningRatio", label: "绿化率", type: "double", value: lc.greeningRatio, ctx: ctx, unit: "%")
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "parkingRatio", label: "车位比", type: "double", value: lc.parkingRatio, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "districtGroup", label: "区组", type: "string", value: lc.districtGroup, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "streetBlock", label: "街区", type: "string", value: lc.streetBlock, ctx: ctx)
        addCustom(&custom, dataset: dataset.id, entity: "compound", key: "district", label: "行政区", type: "string", value: lc.district.isEmpty ? nil : lc.district, ctx: ctx)
        if !custom.isEmpty {
            c.customFieldsJSON = try? JSONHelpers.encode(custom)
        }
        ctx.insert(c)
    }
}

private static func addCustom<V>(
    _ dict: inout [String: AnyJSON],
    dataset: UUID,
    entity: String,
    key: String,
    label: String,
    type: String,
    value: V?,
    ctx: ModelContext,
    unit: String? = nil
) {
    guard let v = value else { return }
    let json: AnyJSON
    switch v {
    case let s as String:
        if s.isEmpty { return }
        json = .string(s)
    case let i as Int:
        json = .int(i)
    case let d as Double:
        json = .double(d)
    case let b as Bool:
        json = .bool(b)
    case let date as Date:
        json = .string(ISO8601DateFormatter().string(from: date))
    default:
        return
    }
    dict[key] = json
    registerCustomFieldDef(datasetId: dataset, entityType: entity, key: key, label: label, type: type, unit: unit, in: ctx)
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 4 — Compound migration + customField"
```

---

## Task 28: LegacyMigrator — Stage 5: Edges (CompoundSchoolMatch + SchoolGroup + Zone pool + primarySchoolId)

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateConvertsCompoundSchoolMatchToEdges() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    // 准备: 1 Compound + 1 School + 1 Match
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    let ls = LegacySchool(name: "鞍山道小学", type: "小学", district: "和平区", tier: "重点")
    ls.lat = 39.12
    ls.lon = 117.19
    let m = CompoundSchoolMatch(compoundId: lc.id, compoundName: "x", district: "和平区")
    m.primaryMatchesJSON = #"[{"school_id":"\#(ls.id.uuidString)","school_name":"鞍山道小学","match_kind":"name"}]"#
    m.middleMatchesJSON = "[]"
    ctx.insert(lc); ctx.insert(ls); ctx.insert(m)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let edges = try ctx.fetch(FetchDescriptor<Edge>())
    let primary = edges.filter { $0.label == "对口小学" }
    #expect(primary.count == 1)
    #expect(primary.first?.fromId == lc.id)
    #expect(primary.first?.fromType == "compound")
    #expect(primary.first?.toId == ls.id)
    #expect(primary.first?.toType == "school")
    #expect(primary.first?.directed == true)
}

@Test func migrateConvertsSchoolGroupToEdges() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let leader = LegacySchool(name: "实验中学", type: "初中", district: "和平区", tier: "重点")
    leader.lat = 39.1; leader.lon = 117.2
    let member = LegacySchool(name: "实验中学分校", type: "初中", district: "和平区", tier: "区重点")
    member.lat = 39.11; member.lon = 117.21
    let g = SchoolGroup(name: "实验集团", district: "和平区")
    g.leadsJSON = #"[{"name":"实验中学","school_id":"\#(leader.id.uuidString)"}]"#
    g.membersJSON = #"[{"name":"实验中学分校","school_id":"\#(member.id.uuidString)"}]"#
    ctx.insert(leader); ctx.insert(member); ctx.insert(g)
    // 触发迁移条件
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let edges = try ctx.fetch(FetchDescriptor<Edge>())
    let groupEdges = edges.filter { $0.label.starts(with: "集团") }
    #expect(groupEdges.contains { $0.label == "集团领办" && $0.fromId == leader.id && $0.toId == leader.id == false })
    #expect(groupEdges.contains { $0.label == "集团成员" })
}

@Test func migrateConvertsZoneMiddleSchoolPoolToEdges() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let middle = LegacySchool(name: "耀华中学", type: "初中", district: "和平区", tier: "重点")
    middle.lat = 39.12; middle.lon = 117.19
    ctx.insert(middle)
    let z = LegacySchoolZone(
        name: "第一学片",
        tier: "重点",
        primaryDistrict: "和平区",
        geometry: #"{"type":"Polygon","coordinates":[[[117,39],[118,39],[118,40],[117,40],[117,39]]]}"#,
        geometryStage: "hull"
    )
    z.middleSchoolPoolJSON = #"["耀华中学"]"#
    ctx.insert(z)
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let edges = try ctx.fetch(FetchDescriptor<Edge>())
    let pool = edges.filter { $0.label == "片内中学" }
    #expect(pool.count == 1)
    #expect(pool.first?.fromType == "area")
    #expect(pool.first?.toType == "school")
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL — edges count 0

- [ ] **Step 3: 实现 stage 5**

在 `LegacyMigrator.run` 中追加 `try migrateEdges(dataset: dataset, in: ctx)`。

```swift
private static func migrateEdges(dataset: Dataset, in ctx: ModelContext) throws {
    try migrateCompoundSchoolMatches(dataset: dataset, in: ctx)
    try migratePrimarySchoolId(dataset: dataset, in: ctx)
    try migrateZoneMiddleSchoolPool(dataset: dataset, in: ctx)
    try migrateSchoolGroups(dataset: dataset, in: ctx)
}

private struct MatchEntry: Decodable {
    let school_id: String
    let school_name: String?
}

private static func migrateCompoundSchoolMatches(dataset: Dataset, in ctx: ModelContext) throws {
    let matches = try ctx.fetch(FetchDescriptor<CompoundSchoolMatch>())
    for m in matches {
        let primary: [MatchEntry] = (try? JSONHelpers.decode(m.primaryMatchesJSON)) ?? []
        for entry in primary {
            guard let toId = UUID(uuidString: entry.school_id) else { continue }
            let e = Edge(
                datasetId: dataset.id,
                fromId: m.compoundId, fromType: "compound",
                toId: toId, toType: "school",
                label: "对口小学",
                directed: true
            )
            ctx.insert(e)
        }
        let middle: [MatchEntry] = (try? JSONHelpers.decode(m.middleMatchesJSON)) ?? []
        for entry in middle {
            guard let toId = UUID(uuidString: entry.school_id) else { continue }
            let e = Edge(
                datasetId: dataset.id,
                fromId: m.compoundId, fromType: "compound",
                toId: toId, toType: "school",
                label: "片内中学",
                directed: true
            )
            ctx.insert(e)
        }
    }
}

private static func migratePrimarySchoolId(dataset: Dataset, in ctx: ModelContext) throws {
    let compounds = try ctx.fetch(FetchDescriptor<LegacyCompound>())
    for lc in compounds {
        guard let to = lc.primarySchoolId else { continue }
        // Skip if already emitted by CompoundSchoolMatch
        let existing = try? ctx.fetch(FetchDescriptor<Edge>(
            predicate: #Predicate { $0.fromId == lc.id && $0.toId == to && $0.label == "对口小学" }
        ))
        if existing?.isEmpty == false { continue }
        let e = Edge(
            datasetId: dataset.id,
            fromId: lc.id, fromType: "compound",
            toId: to, toType: "school",
            label: "对口小学",
            directed: true
        )
        ctx.insert(e)
    }
}

private static func migrateZoneMiddleSchoolPool(dataset: Dataset, in ctx: ModelContext) throws {
    let zones = try ctx.fetch(FetchDescriptor<LegacySchoolZone>())
    let allSchools = try ctx.fetch(FetchDescriptor<LegacySchool>())
    let schoolByName: [String: LegacySchool] = Dictionary(
        uniqueKeysWithValues: allSchools.map { ($0.name, $0) }
    )
    for z in zones {
        guard let poolJSON = z.middleSchoolPoolJSON else { continue }
        let names: [String] = (try? JSONHelpers.decode(poolJSON)) ?? []
        for name in names {
            guard let school = schoolByName[name] else { continue }
            let e = Edge(
                datasetId: dataset.id,
                fromId: z.id, fromType: "area",
                toId: school.id, toType: "school",
                label: "片内中学",
                directed: true
            )
            ctx.insert(e)
        }
    }
}

private struct GroupEntry: Decodable {
    let name: String
    let school_id: String?
}

private static func migrateSchoolGroups(dataset: Dataset, in ctx: ModelContext) throws {
    let groups = try ctx.fetch(FetchDescriptor<SchoolGroup>())
    for g in groups {
        let leads: [GroupEntry] = (try? JSONHelpers.decode(g.leadsJSON)) ?? []
        let members: [GroupEntry] = (try? JSONHelpers.decode(g.membersJSON)) ?? []
        guard let leaderEntry = leads.first,
              let leaderIdStr = leaderEntry.school_id,
              let leaderId = UUID(uuidString: leaderIdStr)
        else { continue }
        for memberEntry in members {
            guard let memberIdStr = memberEntry.school_id,
                  let memberId = UUID(uuidString: memberIdStr),
                  memberId != leaderId
            else { continue }
            let e = Edge(
                datasetId: dataset.id,
                fromId: leaderId, fromType: "school",
                toId: memberId, toType: "school",
                label: "集团成员",
                directed: true
            )
            e.note = g.name
            ctx.insert(e)
        }
        // 额外: leader 自身可标 "集团领办" — 不画 self-edge, 写到 leader 的 customField
        // 这里仅产 edges; leader 标记由后续 plan 处理.
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 5 — Edges from matches/groups/zone pools/primary"
```

---

## Task 29: LegacyMigrator — Stage 6: EnumOption seeds

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateSeedsDefaultEnumOptions() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let enums = try ctx.fetch(FetchDescriptor<EnumOption>())
    let scopes = Set(enums.map { $0.scope })
    #expect(scopes.contains("school.category"))
    #expect(scopes.contains("school.grade"))
    #expect(scopes.contains("school.form"))
    #expect(scopes.contains("edge.label"))
    #expect(scopes.contains("area.category"))
    // 验证 school.category 含 小学/初中
    let cat = enums.filter { $0.scope == "school.category" }.map { $0.label }
    #expect(cat.contains("小学"))
    #expect(cat.contains("初中"))
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 stage 6**

在 `run()` 末尾追加 `try seedEnumOptions(dataset: dataset, in: ctx)`。

```swift
private static func seedEnumOptions(dataset: Dataset, in ctx: ModelContext) throws {
    let seeds: [(scope: String, labels: [String])] = [
        ("school.category", ["小学", "初中", "九年一贯", "十二年制", "幼儿园", "职业"]),
        ("school.grade", ["重点", "区重点", "普通"]),
        ("school.form", ["普通", "九年一贯", "十二年制"]),
        ("compound.finishType", ["毛坯", "精装", "毛坯/精装"]),
        ("compound.deliveryTime", ["现房", "期房"]),
        ("poi.category", ["地铁站", "商场", "医院", "办事处", "学区办", "公交站", "景点"]),
        ("area.category", ["行政区", "片区", "商圈", "管辖区"]),
        ("edge.label", ["对口小学", "片内中学", "周边", "集团成员", "集团领办", "管辖", "属于"])
    ]
    for (scope, labels) in seeds {
        for (idx, label) in labels.enumerated() {
            let opt = EnumOption(
                datasetId: dataset.id,
                scope: scope,
                label: label,
                sortOrder: idx
            )
            ctx.insert(opt)
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 6 — seed default EnumOptions"
```

---

## Task 30: LegacyMigrator — Stage 7: FilterFieldConfig seeds

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateSeedsDefaultFilterFieldConfigs() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let configs = try ctx.fetch(FetchDescriptor<FilterFieldConfig>())
    let schoolSlots = configs.filter { $0.entityType == "school" }
        .sorted { $0.slot < $1.slot }
        .map { $0.fieldKey }
    #expect(schoolSlots == ["category", "grade", "form"])
    let compoundSlots = configs.filter { $0.entityType == "compound" }
        .sorted { $0.slot < $1.slot }
        .map { $0.fieldKey }
    #expect(compoundSlots == ["finishType", "isNewHouse"])
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 stage 7**

在 `run()` 末尾追加 `try seedFilterFields(dataset: dataset, in: ctx)`。

```swift
private static func seedFilterFields(dataset: Dataset, in ctx: ModelContext) throws {
    let seeds: [(entity: String, fields: [(key: String, label: String, source: String)])] = [
        ("compound", [
            ("finishType", "精装类型", "base"),
            ("isNewHouse", "新房/二手", "base")
        ]),
        ("school", [
            ("category", "阶段", "base"),
            ("grade", "等级", "base"),
            ("form", "学制", "base")
        ]),
        ("poi", [
            ("category", "POI 类型", "base")
        ]),
        ("area", [
            ("category", "区域类型", "base")
        ])
    ]
    for (entity, fields) in seeds {
        for (idx, f) in fields.enumerated() {
            let c = FilterFieldConfig(
                datasetId: dataset.id,
                entityType: entity,
                fieldKey: f.key,
                fieldSource: f.source,
                label: f.label,
                slot: idx + 1
            )
            ctx.insert(c)
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 7 — seed default FilterFieldConfigs"
```

---

## Task 31: LegacyMigrator — Stage 8: Palette + Theme + Layer seeds

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateSeedsPalettesThemesAndDefaultLayer() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)

    let palettes = try ctx.fetch(FetchDescriptor<Palette>())
    let names = Set(palettes.map { $0.name })
    #expect(names.contains("default-rainbow"))
    #expect(names.contains("category-cool"))
    #expect(names.contains("category-warm"))
    #expect(names.contains("mono-blue"))

    let themes = try ctx.fetch(FetchDescriptor<Theme>())
    #expect(themes.contains { $0.name == "字段总览" })
    #expect(themes.contains { $0.name == "学区视图" })
    #expect(themes.contains { $0.name == "商圈视图" })
    #expect(themes.contains { $0.name == "新房地图" })

    let layers = try ctx.fetch(FetchDescriptor<Layer>())
    #expect(layers.contains { $0.isDefault && $0.name == "全部" })

    let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
    #expect(datasets.first?.activeThemeId != nil) // 默认激活字段总览
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 stage 8**

在 `run()` 末尾追加 `try seedPalettesThemesLayers(dataset: dataset, in: ctx)`。

```swift
private static func seedPalettesThemesLayers(dataset: Dataset, in ctx: ModelContext) throws {
    let palettes: [(name: String, colors: [String])] = [
        ("default-rainbow", ["#FF3B30","#FF9500","#FFCC00","#34C759","#5AC8FA","#007AFF","#5856D6","#AF52DE","#FF2D55","#A2845E"]),
        ("category-cool",   ["#5AC8FA","#34C759","#007AFF","#5856D6","#00C7BE","#30B0C7"]),
        ("category-warm",   ["#FF3B30","#FF9500","#FFCC00","#FF2D55","#FF6482","#D02D7E"]),
        ("mono-blue",       ["#E1F0FF","#9CCBFB","#4DA3F0","#1B69D6"])
    ]
    for (idx, p) in palettes.enumerated() {
        let palette = Palette(name: p.name, colorsHex: p.colors, builtIn: true)
        palette.sortOrder = idx
        ctx.insert(palette)
    }

    // Default Layer: 全部
    let defaultLayer = Layer(datasetId: dataset.id, name: "全部")
    defaultLayer.isDefault = true
    defaultLayer.enabled = true
    defaultLayer.dynamicQueryJSON = nil // empty == match all
    defaultLayer.sortOrder = 0
    ctx.insert(defaultLayer)

    // Themes
    let baseVisibility = #"{"compound":true,"school":true,"poi":true,"area":true}"#
    let onlyPOIAndArea = #"{"compound":false,"school":false,"poi":true,"area":true}"#
    let onlyCompound = #"{"compound":true,"school":false,"poi":false,"area":false}"#

    let t1 = Theme(datasetId: dataset.id, name: "字段总览")
    t1.visibilityJSON = baseVisibility
    t1.defaultEnabledLayerIds = [defaultLayer.id]
    t1.sortOrder = 0
    t1.isActive = true
    ctx.insert(t1)

    let t2 = Theme(datasetId: dataset.id, name: "学区视图")
    t2.visibilityJSON = baseVisibility
    t2.defaultEnabledLayerIds = [defaultLayer.id]
    t2.sortOrder = 1
    t2.copyTitle = "学区分布图"
    t2.copySubtitle = "2026 招生季"
    ctx.insert(t2)

    let t3 = Theme(datasetId: dataset.id, name: "商圈视图")
    t3.visibilityJSON = onlyPOIAndArea
    t3.defaultEnabledLayerIds = [defaultLayer.id]
    t3.sortOrder = 2
    ctx.insert(t3)

    let t4 = Theme(datasetId: dataset.id, name: "新房地图")
    t4.visibilityJSON = onlyCompound
    t4.defaultEnabledLayerIds = [defaultLayer.id]
    t4.sortOrder = 3
    ctx.insert(t4)

    dataset.activeThemeId = t1.id
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 8 — seed Palettes/Themes/default Layer"
```

---

## Task 32: LegacyMigrator — Stage 9: CameraPreset migration

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateMigratesHardcodedCameraPresets() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let presets = try ctx.fetch(FetchDescriptor<CameraPreset>())
    let names = Set(presets.map { $0.name })
    #expect(names == ["和平区", "河西区", "南开区", "河东区", "河北区", "红桥区"])
    let heping = presets.first { $0.name == "和平区" }!
    #expect(heping.centerLat == 39.125)
    #expect(heping.centerLon == 117.205)
    #expect(heping.distance == 12000)
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 stage 9**

在 `run()` 末尾追加 `try seedCameraPresets(dataset: dataset, in: ctx)`。

```swift
private static func seedCameraPresets(dataset: Dataset, in ctx: ModelContext) throws {
    let seeds: [(name: String, lat: Double, lon: Double, distance: Double)] = [
        ("和平区", 39.125, 117.205, 12000),
        ("河西区", 39.110, 117.225, 18000),
        ("南开区", 39.130, 117.150, 18000),
        ("河东区", 39.125, 117.235, 18000),
        ("河北区", 39.155, 117.205, 18000),
        ("红桥区", 39.165, 117.155, 18000)
    ]
    for (idx, s) in seeds.enumerated() {
        let p = CameraPreset(
            datasetId: dataset.id,
            name: s.name,
            centerLat: s.lat,
            centerLon: s.lon,
            distance: s.distance
        )
        p.sortOrder = idx
        ctx.insert(p)
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 9 — seed CameraPresets"
```

---

## Task 33: LegacyMigrator — Stage 10: AdmissionDoc → Document

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateConvertsAdmissionDocsToDocuments() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let doc = LegacyAdmissionDoc(title: "2024 和平区招生简章", district: "和平区", year: 2024)
    doc.ocrText = "..."
    doc.sourceUrl = "https://example.com"
    ctx.insert(doc)
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let documents = try ctx.fetch(FetchDescriptor<Document>())
    #expect(documents.count == 1)
    let d = documents.first!
    #expect(d.title == "2024 和平区招生简章")
    #expect(d.kind == "pdf")
    #expect(d.ocrText == "...")
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 stage 10**

在 `run()` 末尾追加 `try migrateAdmissionDocs(dataset: dataset, in: ctx)`。

```swift
private static func migrateAdmissionDocs(dataset: Dataset, in ctx: ModelContext) throws {
    let docs = try ctx.fetch(FetchDescriptor<LegacyAdmissionDoc>())
    // 这些 doc 不一定挂某个 entity, 默认挂第一个匹配 district 的 Area; 找不到 用 zero UUID
    let areas = try ctx.fetch(FetchDescriptor<Area>())
    for ld in docs {
        let owner = areas.first { $0.name.contains(ld.district) }?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let d = Document(
            ownerEntityId: owner,
            ownerEntityType: "area",
            kind: "pdf",
            title: ld.title,
            url: ld.sourceUrl ?? ""
        )
        d.id = ld.id
        d.ocrText = ld.ocrText
        ctx.insert(d)
    }
}
```

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 10 — AdmissionDoc → Document"
```

---

## Task 34: LegacyMigrator — Stage 11: BuiltinTag → Tag

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`
- Modify: `PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift`

- [ ] **Step 1: 加 failing test**

```swift
@Test func migrateConvertsBuiltinTagsToTags() throws {
    let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
    let ctx = ModelContext(container)
    let bt = BuiltinTag(category: "感受", label: "通风良好", polarity: "正")
    ctx.insert(bt)
    let lc = LegacyCompound(name: "x", district: "和平区", latitude: 39.1, longitude: 117.2)
    ctx.insert(lc)
    try ctx.save()
    try LegacyMigrator.run(in: ctx)
    let tags = try ctx.fetch(FetchDescriptor<Tag>())
    #expect(tags.count == 1)
    #expect(tags.first?.label == "通风良好")
    #expect(tags.first?.polarity == "positive") // 正 → positive
}
```

- [ ] **Step 2: 跑测试确认失败**

Expected: FAIL

- [ ] **Step 3: 实现 stage 11**

```swift
private static func migrateTags(dataset: Dataset, in ctx: ModelContext) throws {
    let builtin = try ctx.fetch(FetchDescriptor<BuiltinTag>())
    for bt in builtin {
        let polarity: String = {
            switch bt.polarity {
            case "正": return "positive"
            case "负": return "negative"
            default: return "neutral"
            }
        }()
        let t = Tag(
            datasetId: dataset.id,
            category: bt.category,
            label: bt.label,
            polarity: polarity
        )
        t.id = bt.id
        t.sortOrder = bt.sortOrder
        ctx.insert(t)
    }
}
```

把 `try migrateTags(dataset: dataset, in: ctx)` 加到 `run()` 末尾。

- [ ] **Step 4: 跑测试确认通过 + commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlasTests/DataKit/LegacyMigratorTests.swift
git commit -m "feat(data): LegacyMigrator stage 11 — BuiltinTag → Tag"
```

---

## Task 35: 在 App 启动时挂 LegacyMigrator

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/States/SeedImporter.swift`

- [ ] **Step 1: 读现状**

Run: `cat PropertyAtlas/PropertyAtlas/States/SeedImporter.swift`
（确认改造点 — `runIfNeeded(into:)` 当前职责）

- [ ] **Step 2: 改造为先迁移后 seed**

修改 `SeedImporter.runIfNeeded(into:)`，开头加：

```swift
static func runIfNeeded(into ctx: ModelContext) throws {
    // 0. 首先尝试 legacy migration (idempotent)
    try LegacyMigrator.run(in: ctx)
    // 1. 如果迁移后还是 0 dataset, 则跳过 seed (空状态由 Onboarding 处理, P5 加)
    let datasets = try ctx.fetch(FetchDescriptor<Dataset>())
    if datasets.isEmpty {
        // 旧 SeedImporter 逻辑 — 暂时保留作 fallback 给开发数据
        // 调用现有 import logic（如果有的话），否则 no-op
        return
    }
    // 已有 dataset, 不重做
}
```

注意: 原 `SeedImporter` 是把 `reports/extracted/*.json` 灌入旧 Legacy* @Model. P1 之后, 旧 SeedImporter 路径只在"新 store 干净 + 无 Legacy 数据" 时跑（这种 case 不存在于现存开发机, 因为旧 store 里已经有 Legacy 数据). 但保留代码以防万一. P5 才彻底删.

具体改法：用 Edit 工具在 `SeedImporter.swift` 的入口函数 body 顶部插入上面 Step 2 的逻辑.

- [ ] **Step 3: 跑全测**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -30`
Expected: all green

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/States/SeedImporter.swift
git commit -m "feat(data): wire LegacyMigrator into SeedImporter on launch"
```

---

## Task 36: End-to-end migration smoke test（真实 dev store）

**Files:**
- Manual test step（人工跑 Mac Catalyst app, 观察）

这一步是「mac 真跑一下 app 确认旧 dev store 平滑迁移」, 不写自动化测试 (依赖具体磁盘文件状态).

- [ ] **Step 1: 备份旧 store**

```bash
# 找到 store 路径 (上次 app 启动写过 /tmp/propertyatlas_paths.txt)
cat /tmp/propertyatlas_paths.txt
# 备份当前 store
cp -a "$(grep StoreURL /tmp/propertyatlas_paths.txt | awk '{print $2}')" "/tmp/store-backup-$(date +%Y%m%d).sqlite" 2>/dev/null || echo "store 文件不存在, skip backup"
```

- [ ] **Step 2: 在 Xcode 启动 Mac Catalyst (My Mac)**

```bash
open PropertyAtlas/PropertyAtlas.xcodeproj
# Xcode → Scheme PropertyAtlas, Destination Mac (Catalyst), Run
```

观察:
- 启动不崩
- 数据库不报 schema mismatch
- Studio 取景界面显示 (旧 SchoolPinView 通过 LegacyShim 渲染新 School 数据)
- pin 数量大致与原 823 接近
- 学片色块大致与原 101 接近

- [ ] **Step 3: 写观察记录到 plan，标记 PASS / FAIL**

如果观察 PASS，commit 一个空 doc 记录:

```bash
echo "P1 smoke test PASS at $(date)" >> docs/superpowers/plans/2026-05-28-p1-data-model-migration.md
git add docs/superpowers/plans/2026-05-28-p1-data-model-migration.md
git commit -m "docs(plan): P1 smoke test verified"
```

如 FAIL，新建 follow-up task 修复，回到 fail 项前的 stage 排查。

---

## Task 37: 标记旧 Legacy* @Model 为 deprecated

**Files:**
- Modify: 所有 `Models/Public/Legacy*.swift` + `AdmissionRate.swift`, `BuiltinTag.swift`, `CompoundSchoolMatch.swift`, `Policy.swift`, `SchoolGroup.swift`, `SchoolScore.swift`

每个 `@Model` 上加 `@available(*, deprecated, message: "P1 migrated to new Models/. Will be removed in P5.")`。

- [ ] **Step 1: 逐个文件加 deprecated 标注**

示例:

```swift
@available(*, deprecated, message: "P1 migrated to Models/Entities/Compound.swift. Will be removed in P5.")
@Model final class LegacyCompound { ... }
```

8 个文件: LegacyCompound, LegacySchool, LegacySchoolZone, LegacyAdmissionDoc, AdmissionRate, BuiltinTag, CompoundSchoolMatch, Policy, SchoolGroup, SchoolScore（共 10 个 @Model）。

- [ ] **Step 2: 跑测试**

Run: `xcodebuild test ... 2>&1 | tail -30`
Expected: PASS（deprecated 只产 warning, 不报 error）

- [ ] **Step 3: SwiftLint 接受 deprecation warnings**

如果项目里有 `swiftlint disable_rules` 或 warning treated as error, 临时加 `// swiftlint:disable:next deprecated_object_literal` 或 `@available(*, deprecated)` 注释。检查 `swiftlint lint --quiet | grep -i error` 应为空。

- [ ] **Step 4: Commit**

```bash
git add -A PropertyAtlas/PropertyAtlas/Models/Public
git commit -m "refactor(data): mark legacy @Model as deprecated (P5 removal target)"
```

---

## Task 38: 更新 CLAUDE.md（P1 完成的部分）

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 改 CLAUDE.md "Key Documents" 部分**

把:
```
- Design spec: `docs/superpowers/specs/2026-05-19-tianjin-house-design.md`
- Implementation plan: `docs/superpowers/plans/2026-05-20-tianjin-house-app.md`
```

加上:
```
- 新设计 spec (本次重定位): `docs/superpowers/specs/2026-05-28-generic-map-tool-design.md`
- 实施计划 P1 (已完成): `docs/superpowers/plans/2026-05-28-p1-data-model-migration.md`
- 实施计划 P2-P5 (待写)
```

- [ ] **Step 2: 在 "Data model naming — three layers" 一节加迁移备注**

```markdown
### Data model naming — pub/usr/loc 分层 (P1 之后已废弃)

P1 迁移完成后, 全部数据走 new Models/* + CloudKit private (Mac Catalyst
仍 .none, P5 切). usr_* 模型 (PropertyMark/Visit/...) P1 不动, 后续 plan
决定去留. 旧 pub_* 模型加 deprecated 标记, 不要在新代码引用, 由
LegacyMigrator 一次性消化, P5 删除文件.
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): note P1 data model migration completion"
```

---

## Self-Review 总结

P1 plan 共 39 tasks (Task 0..38). 每 task 含 failing test → impl → pass → commit 的 TDD 节奏. 关键节点:

- **Task 0-2**: 测试基础设施 + 工具类
- **Task 3**: 旧 Photo 改名释放命名
- **Task 4-9**: 6 个 core/schema @Model (Dataset/Tag/CameraPreset/Edge/CustomFieldDef/EnumOption)
- **Task 10-13**: 4 个 entity @Model (Compound/School/POI/Area)，其中 Compound/School/Area 涉及旧文件 rename
- **Task 14-18**: 5 个 style/display @Model
- **Task 19-20**: 2 个 media @Model + AdmissionDoc rename
- **Task 21**: ModelSchema + PropertyAtlasApp wiring
- **Task 22-23**: LegacyShim + 旧 Studio UI 切到新 entity
- **Task 24-34**: LegacyMigrator 11 个 stage
- **Task 35**: App 启动挂 migrator
- **Task 36**: 真机 smoke test
- **Task 37**: 标 legacy deprecated
- **Task 38**: 更新 CLAUDE.md

**Spec 覆盖检查**:
- 17 @Model 全部建好 ✓
- 旧→新 字段映射全部走 LegacyMigrator stage ✓
- StableHash 算法落地 ✓
- CloudKit Mac Catalyst 保留 .none + 注释到 P5（spec 说改但延后是合理选择） ✓
- 测试 §9.1 单元覆盖 model CRUD + StableHash + migration ✓
- §9.2/9.3 UI snapshot + 集成测试: 由 P2-P5 实现, P1 仅覆盖 data layer

**Placeholder 扫描**: 全部 step 有具体 code/cmd, 无 TBD/TODO/...

**Type 一致性**: `Compound.primaryAreaId: UUID?` 与 `LegacyCompound.zoneId: UUID?` 在 migrator 里直接 assign — match. `School.category/grade/form` 与 EnumOption scope 对齐. Edge from/toType 字面量 "compound"/"school"/"poi"/"area" 全 plan 一致.

---

**注释 — P1 之后的状态**:
- 17 个新 @Model 全部入 store
- 旧 dev 数据迁完, app 启动可见新 entity 经 LegacyShim 在旧 Studio UI 渲染
- 旧 @Model 文件还在但 deprecated
- CloudKit Mac Catalyst 仍 .none
- 单测全绿
- 没有任何 UI 改动（仅 LegacyShim 字段名映射）

P2 (StyleResolver + MapRender) 将替换 LegacyShim, P3 (EntityEditor) 加编辑能力, P4 (Layer + Filter), P5 (Import/Export + 清理).
