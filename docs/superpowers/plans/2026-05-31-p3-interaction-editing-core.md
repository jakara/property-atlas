# P3: 交互 + 编辑核心 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 落地 spec `2026-05-28-generic-map-tool-design.md` §4（Edge 关系 + 详情卡 + 高亮）+ §6（EntityEditor + Pin 创建流程 + AppState）的核心交互闭环：点选实体→详情卡→编辑→Edge 增删→地图建 Pin，含 P2 遗留的 spotlight 与 drawEdgeLines 渲染。

**Architecture:** 新建 `@Observable AppState`（§6.7）作为 selection/mode 单一源。`DataKit/` 加 4 个无 UI 服务（`EntityRef`、`EntityReader`/`EntityWriter`、`EdgeStore`、`OverrideStyleCodec`、`EntityFieldSchema`）承载全部可测逻辑。Studio UI 在其上拼装通用 `EntityCard`（读）与 `EntityEditor`（写，5 tab），由 `RightDrawer` 按 `editingMode` 切换。地图侧：tap→select、long-press/右键→建 Pin；`SpotlightResolver` + `EdgeLineFactory` 喂给 MapRender 做淡出高亮与连线。

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData (iOS 17+), Swift Testing, MapKit, Mac Catalyst。

**前置（P1/P2 已落地）:** 17 @Model（Compound/School/POI/Area/Edge/EnumOption/CustomFieldDef/Photo/Document/Theme…）；`AnyJSON` + `JSONHelpers.encode/decode`；`StyleEntity.field(_)` + 4 个 `styleEntity` adapter；`MapRender/StyleResolver`；`ThemeContext`；`MapContainerView(rendererFor:)` hook；`TestContainer.makeInMemory(for:)`。

**范围边界（明确不做，留后续 plan）:**
- POI 外部搜索创建（MKLocalSearch/高德）—— spec §6.4 第 2 条 → P3.5
- Area polygon 绘制 + raster 对齐 —— spec §6.4 第 3/4 条 → P3.5
- 完整 Settings 页（Datasets/Themes/Rules/Palettes/Enum/字段定义/Cameras/备份）—— spec §6.5 → P4
- §5.7 Filter 视图内计数 + §5.8 Layer + legend 重做 —— 已定 P4
- CloudKit `.private` 切换 + 删 Legacy* 文件 —— 已定 P5

**约定:**
- `entityType` 字符串全程用 `"compound"/"school"/"poi"/"area"`（与 styleEntity / Edge.fromType 一致）。
- Mac Catalyst 优先（Studio 主模态）；iPad 触屏交互在标 `// iPad:` 处补，本 plan 的创建入口同时实现右键(Mac)与长按(iPad)。
- 编辑器可编辑 baseField 集合由 `EntityFieldSchema` 单一声明，view 通用渲染，新增字段只改 schema。

---

## 文件结构

**新建（无 UI 服务，`DataKit/` 与 `States/`）:**
- `States/AppState.swift` — `@Observable`，selection + mode + editTab（§6.7）
- `DataKit/EntityRef.swift` — `EntityKind` enum + `EntityRef` 值类型
- `DataKit/EntityFieldSchema.swift` — per-type 可编辑 baseField 描述符
- `DataKit/EntityReader.swift` — 按 ref 取 name/coord/notes + 任意 key→AnyJSON（读）
- `DataKit/EntityWriter.swift` — 按 ref 写 name/coord/notes + key→AnyJSON + 新建/软删
- `DataKit/EdgeStore.swift` — 双向查询 + groupBy label + 增（校验）+ 级联软删
- `DataKit/OverrideStyleCodec.swift` — overrideStyleJSON ↔ struct
- `MapRender/SpotlightResolver.swift` — selection→dim/highlight 集合
- `MapRender/EdgeLineFactory.swift` — drawEdgeLines→MKPolyline
- `MapRender/EdgeLineRenderer.swift` — dashed MKPolylineRenderer

**新建（Studio UI）:**
- `Studio/Detail/EntityCard.swift` — 读详情卡（§4.3）
- `Studio/Editor/EntityEditor.swift` — 编辑器 shell + 5 tab（§6.3）
- `Studio/Editor/EditorBasicTab.swift` — 基本 tab（coord + baseFields + 样式 disclosure）
- `Studio/Editor/StyleOverrideSection.swift` — §5.5 override 折叠区
- `Studio/Editor/EditorRelationsTab.swift` — 关联 tab + RelationPicker
- `Studio/Editor/EditorCustomTab.swift` — 自定义 + 私密 tab
- `Studio/Editor/EditorMediaTab.swift` — 媒体 tab（最小：照片列表+加）
- `Studio/RightDrawer.swift` — 按 mode 宿主 card/editor

**修改:**
- `MapRender/PinAnnotation.swift` — 加 `dimmed`/`highlighted` 标记
- `MapRender/PinAnnotationView.swift` — dim alpha + highlight 描边
- `Map/MapKitView.swift` — tap select 回调泛化 + long-press/右键建 Pin + edge-line renderer 分支
- `RootView.swift` — StudioRootView 注入 AppState + RightDrawer + spotlight/edgeline 接线
- `PropertyAtlasApp.swift` — 注入 `AppState` environment（若需）
- `CLAUDE.md` — P3 节点

---

## Task 0: EntityKind + EntityRef 值类型

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/EntityRef.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EntityRefTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/DataKit/EntityRefTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

struct EntityRefTests {
    @Test func kindRoundTripsRawValue() {
        #expect(EntityKind(rawValue: "compound") == .compound)
        #expect(EntityKind.school.rawValue == "school")
        #expect(EntityKind(rawValue: "nope") == nil)
    }

    @Test func refEqualityByIdAndKind() {
        let id = UUID()
        #expect(EntityRef(id: id, kind: .poi) == EntityRef(id: id, kind: .poi))
        #expect(EntityRef(id: id, kind: .poi) != EntityRef(id: id, kind: .area))
    }

    @Test func typeStringMatchesRawValue() {
        #expect(EntityRef(id: UUID(), kind: .area).typeString == "area")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/EntityRefTests 2>&1 | tail -5`
Expected: FAIL（`Cannot find 'EntityKind'`）

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/EntityRef.swift
import Foundation

enum EntityKind: String, CaseIterable, Codable, Hashable {
    case compound, school, poi, area
}

struct EntityRef: Hashable, Identifiable {
    let id: UUID
    let kind: EntityKind

    var typeString: String { kind.rawValue }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EntityRef.swift PropertyAtlas/PropertyAtlasTests/DataKit/EntityRefTests.swift
git commit -m "feat(data): EntityKind + EntityRef value type"
```

---

## Task 1: EntityFieldSchema — per-type 可编辑 baseField 描述符

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/EntityFieldSchema.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EntityFieldSchemaTests.swift`

声明每类型在编辑器/详情卡中展示的 baseField（key/label/类型）。view 据此通用渲染，避免硬编码字段名。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/DataKit/EntityFieldSchemaTests.swift
import Testing
@testable import PropertyAtlas

struct EntityFieldSchemaTests {
    @Test func schoolHasCategoryGradeForm() {
        let keys = EntityFieldSchema.fields(for: .school).map(\.key)
        #expect(keys.contains("category"))
        #expect(keys.contains("grade"))
        #expect(keys.contains("form"))
    }

    @Test func compoundHasFinishTypeAndNewHouseBool() {
        let fields = EntityFieldSchema.fields(for: .compound)
        #expect(fields.contains { $0.key == "finishType" && $0.kind == .string })
        #expect(fields.contains { $0.key == "isNewHouse" && $0.kind == .bool })
    }

    @Test func everyFieldHasNonEmptyLabel() {
        for kind in EntityKind.allCases {
            for f in EntityFieldSchema.fields(for: kind) {
                #expect(!f.label.isEmpty)
            }
        }
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/EntityFieldSchemaTests 2>&1 | tail -5`
Expected: FAIL（`Cannot find 'EntityFieldSchema'`）

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/EntityFieldSchema.swift
import Foundation

enum FieldKind { case string, int, bool, enumRef }

struct FieldDescriptor {
    let key: String
    let label: String
    let kind: FieldKind
    /// 仅 kind == .enumRef 时用：EnumOption.scope（如 "school.category"）
    let enumScope: String?

    init(_ key: String, _ label: String, _ kind: FieldKind, enumScope: String? = nil) {
        self.key = key
        self.label = label
        self.kind = kind
        self.enumScope = enumScope
    }
}

enum EntityFieldSchema {
    static func fields(for kind: EntityKind) -> [FieldDescriptor] {
        switch kind {
        case .compound:
            return [
                FieldDescriptor("buildYear", "建成年份", .int),
                FieldDescriptor("developer", "开发商", .string),
                FieldDescriptor("propertyMgmt", "物业", .string),
                FieldDescriptor("finishType", "精装类型", .string, enumScope: "compound.finishType"),
                FieldDescriptor("deliveryTime", "交付时间", .string),
                FieldDescriptor("isNewHouse", "新房", .bool),
                FieldDescriptor("areaSegments", "面积段", .string),
                FieldDescriptor("priceSegments", "价格段", .string),
            ]
        case .school:
            return [
                FieldDescriptor("category", "阶段", .enumRef, enumScope: "school.category"),
                FieldDescriptor("grade", "等级", .enumRef, enumScope: "school.grade"),
                FieldDescriptor("form", "学制", .enumRef, enumScope: "school.form"),
                FieldDescriptor("foundYear", "建校年份", .int),
                FieldDescriptor("capacity", "容量", .int),
                FieldDescriptor("communitiesText", "覆盖说明", .string),
                FieldDescriptor("phone", "电话", .string),
            ]
        case .poi:
            return [
                FieldDescriptor("category", "POI 类型", .enumRef, enumScope: "poi.category"),
            ]
        case .area:
            return [
                FieldDescriptor("category", "区域类型", .enumRef, enumScope: "area.category"),
                FieldDescriptor("textDescription", "描述", .string),
            ]
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EntityFieldSchema.swift PropertyAtlas/PropertyAtlasTests/DataKit/EntityFieldSchemaTests.swift
git commit -m "feat(data): EntityFieldSchema per-type editable baseFields"
```

---

## Task 2: EntityReader — 按 ref 读取通用字段 + key→AnyJSON

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/EntityReader.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EntityReaderTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/DataKit/EntityReaderTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EntityReaderTests {
    private func ctx() throws -> ModelContext {
        let c = try TestContainer.makeInMemory(for: [Compound.self, School.self, POI.self, Area.self])
        return ModelContext(c)
    }

    @Test func readsNameAndCoordinate() throws {
        let context = try ctx()
        let s = School(datasetId: UUID(), name: "鞍山道小学", latitude: 39.12, longitude: 117.19)
        context.insert(s)
        let ref = EntityRef(id: s.id, kind: .school)
        #expect(EntityReader.name(ref, in: context) == "鞍山道小学")
        let coord = EntityReader.coordinate(ref, in: context)
        #expect(coord?.latitude == 39.12)
    }

    @Test func readsBaseFieldValue() throws {
        let context = try ctx()
        let c = Compound(datasetId: UUID(), name: "X", latitude: 1, longitude: 2)
        c.finishType = "精装"
        c.isNewHouse = false
        context.insert(c)
        let ref = EntityRef(id: c.id, kind: .compound)
        #expect(EntityReader.value(ref, key: "finishType", in: context) == .string("精装"))
        #expect(EntityReader.value(ref, key: "isNewHouse", in: context) == .bool(false))
    }

    @Test func missingEntityReturnsNil() throws {
        let context = try ctx()
        let ref = EntityRef(id: UUID(), kind: .poi)
        #expect(EntityReader.name(ref, in: context) == nil)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/EntityReaderTests 2>&1 | tail -5`
Expected: FAIL（`Cannot find 'EntityReader'`）

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/EntityReader.swift
import CoreLocation
import Foundation
import SwiftData

@MainActor
enum EntityReader {
    static func name(_ ref: EntityRef, in context: ModelContext) -> String? {
        styleEntity(ref, in: context).flatMap {
            if case let .string(v) = $0.field("name") { return v }
            return nil
        }
    }

    static func coordinate(_ ref: EntityRef, in context: ModelContext) -> CLLocationCoordinate2D? {
        switch ref.kind {
        case .compound: return fetch(Compound.self, ref.id, context)?.coordinate
        case .school: return fetch(School.self, ref.id, context)?.coordinate
        case .poi: return fetch(POI.self, ref.id, context)?.coordinate
        case .area: return nil // Area 无单点坐标
        }
    }

    /// 通用字段读取（baseField 或 customField），经 styleEntity 统一映射。
    static func value(_ ref: EntityRef, key: String, in context: ModelContext) -> AnyJSON? {
        styleEntity(ref, in: context)?.field(key)
    }

    static func notes(_ ref: EntityRef, in context: ModelContext) -> (notes: String?, privateNotes: String?) {
        switch ref.kind {
        case .compound: let e = fetch(Compound.self, ref.id, context); return (e?.notes, e?.privateNotes)
        case .school: let e = fetch(School.self, ref.id, context); return (e?.notes, e?.privateNotes)
        case .poi: let e = fetch(POI.self, ref.id, context); return (e?.notes, e?.privateNotes)
        case .area: let e = fetch(Area.self, ref.id, context); return (e?.notes, e?.privateNotes)
        }
    }

    static func customFieldsJSON(_ ref: EntityRef, in context: ModelContext) -> String? {
        switch ref.kind {
        case .compound: return fetch(Compound.self, ref.id, context)?.customFieldsJSON
        case .school: return fetch(School.self, ref.id, context)?.customFieldsJSON
        case .poi: return fetch(POI.self, ref.id, context)?.customFieldsJSON
        case .area: return fetch(Area.self, ref.id, context)?.customFieldsJSON
        }
    }

    static func overrideStyleJSON(_ ref: EntityRef, in context: ModelContext) -> String? {
        switch ref.kind {
        case .compound: return fetch(Compound.self, ref.id, context)?.overrideStyleJSON
        case .school: return fetch(School.self, ref.id, context)?.overrideStyleJSON
        case .poi: return fetch(POI.self, ref.id, context)?.overrideStyleJSON
        case .area: return fetch(Area.self, ref.id, context)?.overrideStyleJSON
        }
    }

    private static func styleEntity(_ ref: EntityRef, in context: ModelContext) -> StyleEntity? {
        switch ref.kind {
        case .compound: return fetch(Compound.self, ref.id, context)?.styleEntity
        case .school: return fetch(School.self, ref.id, context)?.styleEntity
        case .poi: return fetch(POI.self, ref.id, context)?.styleEntity
        case .area: return fetch(Area.self, ref.id, context)?.styleEntity
        }
    }

    static func fetch<T: PersistentModel>(_ type: T.Type, _ id: UUID, _ context: ModelContext) -> T? {
        var fd = FetchDescriptor<T>(predicate: #Predicate { ($0 as! T).persistentModelID == ($0 as! T).persistentModelID })
        fd.fetchLimit = 1
        // SwiftData 无法对任意 T 用 id predicate（id 非 keypath 协议），改用类型化 helper 下沉到具体类型。
        _ = fd
        return nil
    }
}
```

> **实现注记（重要）:** SwiftData 的 `#Predicate` 需要具体类型的 keypath，无法对泛型 `T` 写 `$0.id == id`。因此 `fetch` 不能泛型化。Step 3 用下面的**具体类型重载**替换上面占位的泛型 `fetch`：

```swift
    static func fetch(_ type: Compound.Type, _ id: UUID, _ context: ModelContext) -> Compound? {
        var fd = FetchDescriptor<Compound>(predicate: #Predicate { $0.id == id }); fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }
    static func fetch(_ type: School.Type, _ id: UUID, _ context: ModelContext) -> School? {
        var fd = FetchDescriptor<School>(predicate: #Predicate { $0.id == id }); fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }
    static func fetch(_ type: POI.Type, _ id: UUID, _ context: ModelContext) -> POI? {
        var fd = FetchDescriptor<POI>(predicate: #Predicate { $0.id == id }); fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }
    static func fetch(_ type: Area.Type, _ id: UUID, _ context: ModelContext) -> Area? {
        var fd = FetchDescriptor<Area>(predicate: #Predicate { $0.id == id }); fd.fetchLimit = 1
        return try? context.fetch(fd).first
    }
```

删除占位泛型 `fetch`，仅保留 4 个具体重载。

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EntityReader.swift PropertyAtlas/PropertyAtlasTests/DataKit/EntityReaderTests.swift
git commit -m "feat(data): EntityReader uniform read by EntityRef"
```

---

## Task 3: EntityWriter — 创建 / 写字段 / 软删

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/EntityWriter.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EntityWriterTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/DataKit/EntityWriterTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EntityWriterTests {
    private func ctx() throws -> ModelContext {
        let c = try TestContainer.makeInMemory(for: [Compound.self, School.self, POI.self, Area.self])
        return ModelContext(c)
    }

    @Test func createsPinReturnsRef() throws {
        let context = try ctx()
        let ds = UUID()
        let ref = EntityWriter.createPin(kind: .compound, datasetId: ds, name: "新盘",
                                         latitude: 39.1, longitude: 117.2, in: context)
        #expect(ref.kind == .compound)
        #expect(EntityReader.name(ref, in: context) == "新盘")
    }

    @Test func setsBaseFieldValue() throws {
        let context = try ctx()
        let ref = EntityWriter.createPin(kind: .school, datasetId: UUID(), name: "S",
                                         latitude: 1, longitude: 2, in: context)
        EntityWriter.setValue(ref, key: "category", value: .string("小学"), in: context)
        #expect(EntityReader.value(ref, key: "category", in: context) == .string("小学"))
    }

    @Test func setsNameAndNotes() throws {
        let context = try ctx()
        let ref = EntityWriter.createPin(kind: .poi, datasetId: UUID(), name: "A",
                                         latitude: 1, longitude: 2, in: context)
        EntityWriter.setName(ref, "B", in: context)
        EntityWriter.setPrivateNotes(ref, "内部备注", in: context)
        #expect(EntityReader.name(ref, in: context) == "B")
        #expect(EntityReader.notes(ref, in: context).privateNotes == "内部备注")
    }

    @Test func softDeleteMarksDeleted() throws {
        let context = try ctx()
        let ref = EntityWriter.createPin(kind: .poi, datasetId: UUID(), name: "A",
                                         latitude: 1, longitude: 2, in: context)
        EntityWriter.softDelete(ref, in: context)
        let p = EntityReader.fetch(POI.self, ref.id, context)
        #expect(p?.deleted == true)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/EntityWriterTests 2>&1 | tail -5`
Expected: FAIL（`Cannot find 'EntityWriter'`）

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/EntityWriter.swift
import Foundation
import SwiftData

@MainActor
enum EntityWriter {
    static func createPin(kind: EntityKind, datasetId: UUID, name: String,
                          latitude: Double, longitude: Double, in context: ModelContext) -> EntityRef {
        let id: UUID
        switch kind {
        case .compound:
            let e = Compound(datasetId: datasetId, name: name, latitude: latitude, longitude: longitude)
            context.insert(e); id = e.id
        case .school:
            let e = School(datasetId: datasetId, name: name, latitude: latitude, longitude: longitude)
            context.insert(e); id = e.id
        case .poi:
            let e = POI(datasetId: datasetId, name: name, latitude: latitude, longitude: longitude)
            context.insert(e); id = e.id
        case .area:
            let e = Area(datasetId: datasetId, name: name)
            context.insert(e); id = e.id
        }
        return EntityRef(id: id, kind: kind)
    }

    static func setName(_ ref: EntityRef, _ name: String, in context: ModelContext) {
        touch(ref, in: context) { c in c.name = name } s: { $0.name = name } p: { $0.name = name } a: { $0.name = name }
    }

    static func setPrivateNotes(_ ref: EntityRef, _ v: String?, in context: ModelContext) {
        touch(ref, in: context) { $0.privateNotes = v } s: { $0.privateNotes = v } p: { $0.privateNotes = v } a: { $0.privateNotes = v }
    }

    static func setNotes(_ ref: EntityRef, _ v: String?, in context: ModelContext) {
        touch(ref, in: context) { $0.notes = v } s: { $0.notes = v } p: { $0.notes = v } a: { $0.notes = v }
    }

    static func setCoordinate(_ ref: EntityRef, lat: Double, lon: Double, in context: ModelContext) {
        touch(ref, in: context) { $0.latitude = lat; $0.longitude = lon }
            s: { $0.latitude = lat; $0.longitude = lon }
            p: { $0.latitude = lat; $0.longitude = lon }
            a: { _ in } // Area 无单点
    }

    static func setOverrideStyleJSON(_ ref: EntityRef, _ json: String?, in context: ModelContext) {
        touch(ref, in: context) { $0.overrideStyleJSON = json } s: { $0.overrideStyleJSON = json }
            p: { $0.overrideStyleJSON = json } a: { $0.overrideStyleJSON = json }
    }

    static func setCustomFieldsJSON(_ ref: EntityRef, _ json: String?, in context: ModelContext) {
        touch(ref, in: context) { $0.customFieldsJSON = json } s: { $0.customFieldsJSON = json }
            p: { $0.customFieldsJSON = json } a: { $0.customFieldsJSON = json }
    }

    static func softDelete(_ ref: EntityRef, in context: ModelContext) {
        touch(ref, in: context) { $0.deleted = true } s: { $0.deleted = true } p: { $0.deleted = true } a: { $0.deleted = true }
    }

    /// 写单个 baseField（按 EntityFieldSchema 的 key）。未知 key 忽略。
    static func setValue(_ ref: EntityRef, key: String, value: AnyJSON, in context: ModelContext) {
        switch ref.kind {
        case .compound: if let e = EntityReader.fetch(Compound.self, ref.id, context) { applyCompound(e, key, value); e.updatedAt = Date() }
        case .school: if let e = EntityReader.fetch(School.self, ref.id, context) { applySchool(e, key, value); e.updatedAt = Date() }
        case .poi: if let e = EntityReader.fetch(POI.self, ref.id, context) { applyPOI(e, key, value); e.updatedAt = Date() }
        case .area: if let e = EntityReader.fetch(Area.self, ref.id, context) { applyArea(e, key, value); e.updatedAt = Date() }
        }
    }

    // MARK: - per-type field apply

    private static func str(_ v: AnyJSON) -> String? { if case let .string(s) = v { return s }; return nil }
    private static func intv(_ v: AnyJSON) -> Int? { if case let .int(i) = v { return i }; return nil }
    private static func boolv(_ v: AnyJSON) -> Bool? { if case let .bool(b) = v { return b }; return nil }

    private static func applyCompound(_ e: Compound, _ k: String, _ v: AnyJSON) {
        switch k {
        case "buildYear": e.buildYear = intv(v)
        case "developer": e.developer = str(v)
        case "propertyMgmt": e.propertyMgmt = str(v)
        case "finishType": e.finishType = str(v)
        case "deliveryTime": e.deliveryTime = str(v)
        case "isNewHouse": e.isNewHouse = boolv(v) ?? e.isNewHouse
        case "areaSegments": e.areaSegments = str(v)
        case "priceSegments": e.priceSegments = str(v)
        case "address": e.address = str(v)
        default: break
        }
    }

    private static func applySchool(_ e: School, _ k: String, _ v: AnyJSON) {
        switch k {
        case "category": e.category = str(v)
        case "grade": e.grade = str(v)
        case "form": e.form = str(v)
        case "foundYear": e.foundYear = intv(v)
        case "capacity": e.capacity = intv(v)
        case "communitiesText": e.communitiesText = str(v)
        case "phone": e.phone = str(v)
        case "address": e.address = str(v)
        default: break
        }
    }

    private static func applyPOI(_ e: POI, _ k: String, _ v: AnyJSON) {
        switch k {
        case "category": e.category = str(v)
        case "address": e.address = str(v)
        default: break
        }
    }

    private static func applyArea(_ e: Area, _ k: String, _ v: AnyJSON) {
        switch k {
        case "category": e.category = str(v)
        case "textDescription": e.textDescription = str(v)
        default: break
        }
    }

    /// 统一取出实体执行 mutation 并 bump updatedAt。
    private static func touch(_ ref: EntityRef, in context: ModelContext,
                              _ c: (Compound) -> Void, s: (School) -> Void,
                              p: (POI) -> Void, a: (Area) -> Void) {
        switch ref.kind {
        case .compound: if let e = EntityReader.fetch(Compound.self, ref.id, context) { c(e); e.updatedAt = Date() }
        case .school: if let e = EntityReader.fetch(School.self, ref.id, context) { s(e); e.updatedAt = Date() }
        case .poi: if let e = EntityReader.fetch(POI.self, ref.id, context) { p(e); e.updatedAt = Date() }
        case .area: if let e = EntityReader.fetch(Area.self, ref.id, context) { a(e); e.updatedAt = Date() }
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（4 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EntityWriter.swift PropertyAtlas/PropertyAtlasTests/DataKit/EntityWriterTests.swift
git commit -m "feat(data): EntityWriter create/setField/softDelete by EntityRef"
```

---

## Task 4: OverrideStyleCodec — overrideStyleJSON ↔ struct

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/OverrideStyleCodec.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/OverrideStyleCodecTests.swift`

§5.5：`{"shape":"diamond","fillHex":"#7C3AED","glyph":"★","size":28,"labelVisible":true}`，任一字段可缺。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/DataKit/OverrideStyleCodecTests.swift
import Testing
@testable import PropertyAtlas

struct OverrideStyleCodecTests {
    @Test func decodesPartial() throws {
        let o = OverrideStyleCodec.decode(##"{"shape":"diamond","size":28}"##)
        #expect(o.shape == "diamond")
        #expect(o.size == 28)
        #expect(o.fillHex == nil)
        #expect(o.labelVisible == nil)
    }

    @Test func encodeOmitsNil() throws {
        var o = OverrideStyle()
        o.fillHex = "#FF0000"
        let json = OverrideStyleCodec.encode(o)
        #expect(json != nil)
        #expect(json!.contains("fillHex"))
        #expect(!json!.contains("shape"))
    }

    @Test func encodeEmptyReturnsNil() {
        #expect(OverrideStyleCodec.encode(OverrideStyle()) == nil)
    }

    @Test func roundTrip() {
        var o = OverrideStyle()
        o.shape = "star"; o.glyph = "★"; o.labelVisible = true
        let json = OverrideStyleCodec.encode(o)!
        let back = OverrideStyleCodec.decode(json)
        #expect(back.shape == "star")
        #expect(back.glyph == "★")
        #expect(back.labelVisible == true)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/OverrideStyleCodecTests 2>&1 | tail -5`
Expected: FAIL（`Cannot find 'OverrideStyle'`）

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/OverrideStyleCodec.swift
import Foundation

struct OverrideStyle: Equatable {
    var shape: String?
    var fillHex: String?
    var glyph: String?
    var glyphHex: String?
    var size: Int?
    var labelVisible: Bool?

    var isEmpty: Bool {
        shape == nil && fillHex == nil && glyph == nil && glyphHex == nil && size == nil && labelVisible == nil
    }
}

enum OverrideStyleCodec {
    static func decode(_ json: String?) -> OverrideStyle {
        guard let json, let decoded: [String: AnyJSON] = try? JSONHelpers.decode(json) else {
            return OverrideStyle()
        }
        var o = OverrideStyle()
        if case let .string(v) = decoded["shape"] { o.shape = v }
        if case let .string(v) = decoded["fillHex"] { o.fillHex = v }
        if case let .string(v) = decoded["glyph"] { o.glyph = v }
        if case let .string(v) = decoded["glyphHex"] { o.glyphHex = v }
        if case let .int(v) = decoded["size"] { o.size = v }
        if case let .double(v) = decoded["size"] { o.size = Int(v) }
        if case let .bool(v) = decoded["labelVisible"] { o.labelVisible = v }
        return o
    }

    /// 全空 → nil（清空 override = 跟随主题）。
    static func encode(_ o: OverrideStyle) -> String? {
        guard !o.isEmpty else { return nil }
        var dict: [String: AnyJSON] = [:]
        if let v = o.shape { dict["shape"] = .string(v) }
        if let v = o.fillHex { dict["fillHex"] = .string(v) }
        if let v = o.glyph { dict["glyph"] = .string(v) }
        if let v = o.glyphHex { dict["glyphHex"] = .string(v) }
        if let v = o.size { dict["size"] = .int(v) }
        if let v = o.labelVisible { dict["labelVisible"] = .bool(v) }
        return try? JSONHelpers.encode(dict)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（4 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/OverrideStyleCodec.swift PropertyAtlas/PropertyAtlasTests/DataKit/OverrideStyleCodecTests.swift
git commit -m "feat(data): OverrideStyleCodec encode/decode entity style override"
```

---

## Task 5: EdgeStore — 双向查询 + groupBy label

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EdgeStoreQueryTests.swift`

§4.1 查询：`fromId==X OR toId==X` → groupBy(label)。返回"对端 ref + label + note"，按 label 分组、组内按 sortOrder。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/DataKit/EdgeStoreQueryTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EdgeStoreQueryTests {
    private func ctx() throws -> ModelContext {
        let c = try TestContainer.makeInMemory(for: [Edge.self])
        return ModelContext(c)
    }

    @Test func collectsBothDirectionsGroupedByLabel() throws {
        let context = try ctx()
        let ds = UUID(); let school = UUID(); let c1 = UUID(); let c2 = UUID()
        context.insert(Edge(datasetId: ds, fromId: school, fromType: "school", toId: c1, toType: "compound", label: "周边小区"))
        context.insert(Edge(datasetId: ds, fromId: c2, fromType: "compound", toId: school, toType: "school", label: "周边小区"))
        let ref = EntityRef(id: school, kind: .school)
        let groups = EdgeStore.relations(of: ref, datasetId: ds, in: context)
        #expect(groups.count == 1)
        #expect(groups[0].label == "周边小区")
        #expect(groups[0].items.count == 2)
        let otherIds = Set(groups[0].items.map { $0.other.id })
        #expect(otherIds == Set([c1, c2]))
    }

    @Test func skipsDeletedEdges() throws {
        let context = try ctx()
        let ds = UUID(); let a = UUID(); let b = UUID()
        let e = Edge(datasetId: ds, fromId: a, fromType: "school", toId: b, toType: "compound", label: "L")
        e.deleted = true
        context.insert(e)
        let groups = EdgeStore.relations(of: EntityRef(id: a, kind: .school), datasetId: ds, in: context)
        #expect(groups.isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/EdgeStoreQueryTests 2>&1 | tail -5`
Expected: FAIL（`Cannot find 'EdgeStore'`）

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift
import Foundation
import SwiftData

@MainActor
enum EdgeStore {
    struct RelationItem: Identifiable {
        let edgeId: UUID
        let other: EntityRef
        let note: String?
        var id: UUID { edgeId }
    }

    struct RelationGroup: Identifiable {
        let label: String
        let items: [RelationItem]
        var id: String { label }
    }

    /// 与 ref 相连的所有未删 Edge，按 label 分组（空 label 组剔除），组内按 sortOrder。
    static func relations(of ref: EntityRef, datasetId: UUID, in context: ModelContext) -> [RelationGroup] {
        let id = ref.id
        let dsId = datasetId
        let fd = FetchDescriptor<Edge>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted && ($0.fromId == id || $0.toId == id) },
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let edges = (try? context.fetch(fd)) ?? []
        var byLabel: [String: [RelationItem]] = [:]
        var order: [String] = []
        for e in edges where !e.label.isEmpty {
            let other: EntityRef
            if e.fromId == id {
                guard let k = EntityKind(rawValue: e.toType) else { continue }
                other = EntityRef(id: e.toId, kind: k)
            } else {
                guard let k = EntityKind(rawValue: e.fromType) else { continue }
                other = EntityRef(id: e.fromId, kind: k)
            }
            if byLabel[e.label] == nil { byLabel[e.label] = []; order.append(e.label) }
            byLabel[e.label]?.append(RelationItem(edgeId: e.id, other: other, note: e.note))
        }
        return order.map { RelationGroup(label: $0, items: byLabel[$0] ?? []) }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（2 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift PropertyAtlas/PropertyAtlasTests/DataKit/EdgeStoreQueryTests.swift
git commit -m "feat(data): EdgeStore bidirectional relations grouped by label"
```

---

## Task 6: EdgeStore.add — 校验（自连拒绝 / 重复 skip）

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EdgeStoreAddTests.swift`

§4.2：`from==to` 拒绝；同 `(from,to,label)` 重复 warn+skip（含反向同对同 label 视为重复）。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/DataKit/EdgeStoreAddTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EdgeStoreAddTests {
    private func ctx() throws -> ModelContext {
        ModelContext(try TestContainer.makeInMemory(for: [Edge.self]))
    }

    @Test func addCreatesEdge() throws {
        let context = try ctx()
        let ds = UUID()
        let r = EdgeStore.add(datasetId: ds, from: EntityRef(id: UUID(), kind: .school),
                              to: EntityRef(id: UUID(), kind: .compound), label: "周边", in: context)
        #expect(r == .added)
    }

    @Test func selfLinkRejected() throws {
        let context = try ctx()
        let x = UUID()
        let r = EdgeStore.add(datasetId: UUID(), from: EntityRef(id: x, kind: .school),
                              to: EntityRef(id: x, kind: .school), label: "L", in: context)
        #expect(r == .rejectedSelfLink)
    }

    @Test func duplicateSkipped() throws {
        let context = try ctx()
        let ds = UUID(); let a = EntityRef(id: UUID(), kind: .school); let b = EntityRef(id: UUID(), kind: .compound)
        _ = EdgeStore.add(datasetId: ds, from: a, to: b, label: "L", in: context)
        let second = EdgeStore.add(datasetId: ds, from: a, to: b, label: "L", in: context)
        #expect(second == .skippedDuplicate)
    }

    @Test func reverseDuplicateSkipped() throws {
        let context = try ctx()
        let ds = UUID(); let a = EntityRef(id: UUID(), kind: .school); let b = EntityRef(id: UUID(), kind: .compound)
        _ = EdgeStore.add(datasetId: ds, from: a, to: b, label: "L", in: context)
        let rev = EdgeStore.add(datasetId: ds, from: b, to: a, label: "L", in: context)
        #expect(rev == .skippedDuplicate)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/EdgeStoreAddTests 2>&1 | tail -5`
Expected: FAIL（`add` 不存在）

- [ ] **Step 3: 写实现（追加到 EdgeStore）**

```swift
    enum AddResult: Equatable { case added, rejectedSelfLink, skippedDuplicate }

    @discardableResult
    static func add(datasetId: UUID, from: EntityRef, to: EntityRef, label: String,
                    directed: Bool = false, note: String? = nil, in context: ModelContext) -> AddResult {
        guard from.id != to.id else { return .rejectedSelfLink }
        let dsId = datasetId
        let fid = from.id, tid = to.id
        let fd = FetchDescriptor<Edge>(predicate: #Predicate {
            $0.datasetId == dsId && !$0.deleted && $0.label == label &&
            (($0.fromId == fid && $0.toId == tid) || ($0.fromId == tid && $0.toId == fid))
        })
        if ((try? context.fetch(fd)) ?? []).isEmpty == false { return .skippedDuplicate }
        context.insert(Edge(datasetId: datasetId, fromId: from.id, fromType: from.typeString,
                            toId: to.id, toType: to.typeString, label: label, directed: directed, note: note))
        return .added
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（4 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift PropertyAtlas/PropertyAtlasTests/DataKit/EdgeStoreAddTests.swift
git commit -m "feat(data): EdgeStore.add with self-link + duplicate validation"
```

---

## Task 7: EdgeStore 删除 — 单 edge 软删 + 实体级联软删

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/DataKit/EdgeStoreDeleteTests.swift`

§4.2：删 entity → 级联软删其所有相关 Edge。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/DataKit/EdgeStoreDeleteTests.swift
import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct EdgeStoreDeleteTests {
    private func ctx() throws -> ModelContext {
        ModelContext(try TestContainer.makeInMemory(for: [Edge.self]))
    }

    @Test func removeEdgeSoftDeletes() throws {
        let context = try ctx()
        let ds = UUID(); let a = EntityRef(id: UUID(), kind: .school); let b = EntityRef(id: UUID(), kind: .compound)
        _ = EdgeStore.add(datasetId: ds, from: a, to: b, label: "L", in: context)
        let group = EdgeStore.relations(of: a, datasetId: ds, in: context).first!
        EdgeStore.removeEdge(group.items[0].edgeId, in: context)
        #expect(EdgeStore.relations(of: a, datasetId: ds, in: context).isEmpty)
    }

    @Test func cascadeSoftDeleteForEntity() throws {
        let context = try ctx()
        let ds = UUID(); let hub = EntityRef(id: UUID(), kind: .school)
        _ = EdgeStore.add(datasetId: ds, from: hub, to: EntityRef(id: UUID(), kind: .compound), label: "L1", in: context)
        _ = EdgeStore.add(datasetId: ds, from: EntityRef(id: UUID(), kind: .area), to: hub, label: "L2", in: context)
        EdgeStore.cascadeSoftDelete(entityId: hub.id, datasetId: ds, in: context)
        #expect(EdgeStore.relations(of: hub, datasetId: ds, in: context).isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/EdgeStoreDeleteTests 2>&1 | tail -5`
Expected: FAIL

- [ ] **Step 3: 写实现（追加到 EdgeStore）**

```swift
    static func removeEdge(_ edgeId: UUID, in context: ModelContext) {
        var fd = FetchDescriptor<Edge>(predicate: #Predicate { $0.id == edgeId }); fd.fetchLimit = 1
        if let e = try? context.fetch(fd).first { e.deleted = true; e.updatedAt = Date() }
    }

    static func cascadeSoftDelete(entityId: UUID, datasetId: UUID, in context: ModelContext) {
        let dsId = datasetId
        let fd = FetchDescriptor<Edge>(predicate: #Predicate {
            $0.datasetId == dsId && !$0.deleted && ($0.fromId == entityId || $0.toId == entityId)
        })
        for e in (try? context.fetch(fd)) ?? [] { e.deleted = true; e.updatedAt = Date() }
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（2 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EdgeStore.swift PropertyAtlas/PropertyAtlasTests/DataKit/EdgeStoreDeleteTests.swift
git commit -m "feat(data): EdgeStore removeEdge + cascade soft-delete"
```

---

## Task 8: AppState — selection / mode / editTab

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/States/AppState.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/States/AppStateTests.swift`

§6.7：切 dataset → reset selection；切 theme 不动 selection。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/States/AppStateTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct AppStateTests {
    @Test func selectSetsRefAndDefaultsToReadMode() {
        let s = AppState()
        let ref = EntityRef(id: UUID(), kind: .school)
        s.select(ref)
        #expect(s.selectedRef == ref)
        #expect(s.editingMode == .read)
    }

    @Test func editEntersEditMode() {
        let s = AppState()
        s.select(EntityRef(id: UUID(), kind: .poi))
        s.beginEditing()
        #expect(s.editingMode == .edit)
        #expect(s.currentEditTab == .basic)
    }

    @Test func clearSelectionResetsMode() {
        let s = AppState()
        s.select(EntityRef(id: UUID(), kind: .poi))
        s.beginEditing()
        s.clearSelection()
        #expect(s.selectedRef == nil)
        #expect(s.editingMode == .read)
    }

    @Test func switchDatasetResetsSelection() {
        let s = AppState()
        s.activeDatasetId = UUID()
        s.select(EntityRef(id: UUID(), kind: .area))
        s.switchDataset(to: UUID())
        #expect(s.selectedRef == nil)
    }

    @Test func switchThemeKeepsSelection() {
        let s = AppState()
        let ref = EntityRef(id: UUID(), kind: .area)
        s.select(ref)
        s.activeThemeId = UUID()
        #expect(s.selectedRef == ref)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/AppStateTests 2>&1 | tail -5`
Expected: FAIL（`Cannot find 'AppState'`）

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/States/AppState.swift
import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum EditingMode { case read, edit, live }
    enum EditTab { case basic, relations, media, custom, privateNotes }

    var activeDatasetId: UUID?
    var activeThemeId: UUID?
    var selectedRef: EntityRef?
    var editingMode: EditingMode = .read
    var currentEditTab: EditTab = .basic

    func select(_ ref: EntityRef) {
        selectedRef = ref
        editingMode = .read
    }

    func beginEditing() {
        guard selectedRef != nil else { return }
        editingMode = .edit
        currentEditTab = .basic
    }

    func clearSelection() {
        selectedRef = nil
        editingMode = .read
    }

    func switchDataset(to id: UUID) {
        activeDatasetId = id
        clearSelection()
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（5 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/States/AppState.swift PropertyAtlas/PropertyAtlasTests/States/AppStateTests.swift
git commit -m "feat(state): AppState selection + editing mode + edit tab"
```

---

## Task 9: SpotlightResolver — selection → dim/highlight 集合

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/SpotlightResolver.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/SpotlightResolverTests.swift`

§4.3：选中 entity 时其他 dim，关联组高亮（`spotlightOnSelect`）。本服务给出"高亮 id 集"（= selected + 关联对端），view 据此判 dim。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/MapRender/SpotlightResolverTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

struct SpotlightResolverTests {
    @Test func nilSelectionMeansNoSpotlight() {
        let r = SpotlightResolver.highlightedIds(selected: nil, relatedIds: [], enabled: true)
        #expect(r == nil) // nil = 不 dim 任何
    }

    @Test func disabledMeansNoSpotlight() {
        let r = SpotlightResolver.highlightedIds(selected: UUID(), relatedIds: [UUID()], enabled: false)
        #expect(r == nil)
    }

    @Test func includesSelectedAndRelated() {
        let sel = UUID(); let a = UUID(); let b = UUID()
        let r = SpotlightResolver.highlightedIds(selected: sel, relatedIds: [a, b], enabled: true)
        #expect(r == Set([sel, a, b]))
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/SpotlightResolverTests 2>&1 | tail -5`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/SpotlightResolver.swift
import Foundation

enum SpotlightResolver {
    /// 返回应高亮（不 dim）的 id 集；nil = 不启用 spotlight（全部正常）。
    static func highlightedIds(selected: UUID?, relatedIds: [UUID], enabled: Bool) -> Set<UUID>? {
        guard enabled, let selected else { return nil }
        var set = Set(relatedIds)
        set.insert(selected)
        return set
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（3 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/SpotlightResolver.swift PropertyAtlas/PropertyAtlasTests/MapRender/SpotlightResolverTests.swift
git commit -m "feat(render): SpotlightResolver highlighted-id set from selection"
```

---

## Task 10: PinAnnotation/View — dim + highlight 渲染

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/MapRender/PinAnnotation.swift`
- Modify: `PropertyAtlas/PropertyAtlas/MapRender/PinAnnotationView.swift`

无单测（视觉）；build verify。

- [ ] **Step 1: PinAnnotation 加可变标记**

`PinAnnotation` 现有属性 `let style`。新增两个 `var`（标记由 StudioRootView 构建时设定）：

```swift
    var dimmed: Bool = false
    var highlighted: Bool = false
```

（加在 `let style: PinStyle` 之后。`init` 不变，调用方构建后赋值。）

- [ ] **Step 2: PinAnnotationView.refresh() 末尾接 dim/highlight**

在 `refresh()` 末尾（`centerOffset = ...` 之后）追加：

```swift
        if let a = annotation as? PinAnnotation {
            alpha = a.dimmed ? 0.28 : 1.0
            if a.highlighted {
                shapeLayer.shadowColor = UIColor.systemYellow.cgColor
                shapeLayer.shadowOpacity = 0.9
                shapeLayer.shadowRadius = 5
                shapeLayer.lineWidth = 2.5
            } else {
                shapeLayer.shadowColor = UIColor.black.cgColor
                shapeLayer.shadowOpacity = 0.25
                shapeLayer.shadowRadius = 2
                shapeLayer.lineWidth = 1.5
            }
        }
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/PinAnnotation.swift PropertyAtlas/PropertyAtlas/MapRender/PinAnnotationView.swift
git commit -m "feat(render): pin dim + highlight visual states"
```

---

## Task 11: EdgeLineFactory — drawEdgeLines → MKPolyline

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/EdgeLineFactory.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/MapRender/EdgeLineFactoryTests.swift`

§4.5：Theme.drawEdgeLines 列出的 label，对相应 edge 两端坐标画线。工厂输入「edge（from/to coord）列表」输出 MKPolyline。坐标解析在调用方（StudioRootView 有实体坐标表），工厂只接 `(CLLocationCoordinate2D, CLLocationCoordinate2D)`，保持可测。

- [ ] **Step 1: 写失败测试**

```swift
// PropertyAtlasTests/MapRender/EdgeLineFactoryTests.swift
import CoreLocation
import MapKit
import Testing
@testable import PropertyAtlas

struct EdgeLineFactoryTests {
    @Test func buildsPolylinePerSegment() {
        let segs = [
            (CLLocationCoordinate2D(latitude: 39.1, longitude: 117.1),
             CLLocationCoordinate2D(latitude: 39.2, longitude: 117.2)),
            (CLLocationCoordinate2D(latitude: 39.0, longitude: 117.0),
             CLLocationCoordinate2D(latitude: 39.3, longitude: 117.3)),
        ]
        let lines = EdgeLineFactory.polylines(from: segs)
        #expect(lines.count == 2)
        #expect(lines[0].pointCount == 2)
    }

    @Test func emptyInputEmptyOutput() {
        #expect(EdgeLineFactory.polylines(from: []).isEmpty)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test ... -only-testing:PropertyAtlasTests/EdgeLineFactoryTests 2>&1 | tail -5`
Expected: FAIL

- [ ] **Step 3: 写实现**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/EdgeLineFactory.swift
import CoreLocation
import MapKit

enum EdgeLineFactory {
    static func polylines(from segments: [(CLLocationCoordinate2D, CLLocationCoordinate2D)]) -> [MKPolyline] {
        segments.map { seg in
            var coords = [seg.0, seg.1]
            return MKPolyline(coordinates: &coords, count: 2)
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2
Expected: PASS（2 tests）

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/EdgeLineFactory.swift PropertyAtlas/PropertyAtlasTests/MapRender/EdgeLineFactoryTests.swift
git commit -m "feat(render): EdgeLineFactory polyline per segment"
```

---

## Task 12: EdgeLineRenderer + MapKitView 连线分支

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/EdgeLineRenderer.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Map/MapKitView.swift`

build verify（依赖 MapKit 渲染）。

- [ ] **Step 1: 写 EdgeLineRenderer**

```swift
// PropertyAtlas/PropertyAtlas/MapRender/EdgeLineRenderer.swift
#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

final class EdgeLineRenderer: MKPolylineRenderer {
    override init(polyline: MKPolyline) {
        super.init(polyline: polyline)
        strokeColor = UIColor.systemIndigo.withAlphaComponent(0.7)
        lineWidth = 2
        lineDashPattern = [4, 4]
    }
}
#endif
```

- [ ] **Step 2: MapKitView.rendererFor 加 polyline 分支**

在 `mapView(_:rendererFor:)` 内、`rendererFor?(overlay)` 注入之后、polygon 分支之前插入：

```swift
            #if targetEnvironment(macCatalyst)
            if let line = overlay as? MKPolyline {
                return EdgeLineRenderer(polyline: line)
            }
            #endif
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/EdgeLineRenderer.swift PropertyAtlas/PropertyAtlas/Map/MapKitView.swift
git commit -m "feat(render): dashed EdgeLineRenderer + MapKitView polyline branch"
```

---

## Task 13: EntityCard — 读详情卡（header + 字段表）

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Detail/EntityCard.swift`

§4.3 详情卡 header + default tab（baseFields）。Edge tabs/媒体 tab 在 Task 14。build verify。

- [ ] **Step 1: 写 EntityCard（字段表版）**

```swift
// PropertyAtlas/PropertyAtlas/Studio/Detail/EntityCard.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EntityCard: View {
    let ref: EntityRef
    let datasetId: UUID
    let onEdit: () -> Void
    let onClose: () -> Void
    let onSelectRelated: (EntityRef) -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fieldTable
                    RelationTabsView(ref: ref, datasetId: datasetId, onSelectRelated: onSelectRelated)
                }
                .padding(12)
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 720)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(kindChip).font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.gray.opacity(0.2), in: Capsule())
            VStack(alignment: .leading, spacing: 2) {
                Text(EntityReader.name(ref, in: context) ?? "—")
                    .font(.system(size: 15, weight: .bold))
            }
            Spacer()
            Button(action: onEdit) { Image(systemName: "pencil") }.buttonStyle(.plain)
            Button(action: onClose) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain)
        }
        .padding(10)
    }

    private var kindChip: String {
        switch ref.kind {
        case .compound: "小区"; case .school: "学校"; case .poi: "POI"; case .area: "片区"
        }
    }

    private var fieldTable: some View {
        let rows: [(String, String)] = EntityFieldSchema.fields(for: ref.kind).compactMap { f in
            guard let v = EntityReader.value(ref, key: f.key, in: context) else { return nil }
            let s = Self.display(v)
            return s.isEmpty ? nil : (f.label, s)
        }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.0) { label, value in
                HStack(alignment: .top, spacing: 6) {
                    Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    Text(value).font(.system(size: 12)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    static func display(_ v: AnyJSON) -> String {
        switch v {
        case let .string(s): s
        case let .int(i): String(i)
        case let .double(d): String(d)
        case let .bool(b): b ? "是" : "否"
        default: ""
        }
    }
}
#endif
```

> `RelationTabsView` 在 Task 14 创建。本 task 先放占位 stub，使 Task 13 可独立 build：在文件末尾 `#endif` 之前临时加：
> ```swift
> #if targetEnvironment(macCatalyst)
> struct RelationTabsView: View {
>     let ref: EntityRef; let datasetId: UUID; let onSelectRelated: (EntityRef) -> Void
>     var body: some View { EmptyView() }
> }
> #endif
> ```
> Task 14 用真实实现替换此 stub（移到独立文件）。

- [ ] **Step 2: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Detail/EntityCard.swift
git commit -m "feat(studio): EntityCard read detail header + field table"
```

---

## Task 14: RelationTabsView — Edge 分组 tab + 关联跳转

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Detail/RelationTabsView.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Detail/EntityCard.swift`（删 stub）

§4.3：tab 列表 = Edge 按 label 分组；点关联项 → onSelectRelated 换卡。build verify。

- [ ] **Step 1: 删 EntityCard 内的 RelationTabsView stub**

删除 Task 13 Step 1 末尾临时加的 `RelationTabsView` stub 块。

- [ ] **Step 2: 写 RelationTabsView**

```swift
// PropertyAtlas/PropertyAtlas/Studio/Detail/RelationTabsView.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct RelationTabsView: View {
    let ref: EntityRef
    let datasetId: UUID
    let onSelectRelated: (EntityRef) -> Void

    @Environment(\.modelContext) private var context
    @State private var selectedLabel: String?

    var body: some View {
        let groups = EdgeStore.relations(of: ref, datasetId: datasetId, in: context)
        if groups.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(groups) { g in
                            let active = (selectedLabel ?? groups.first?.label) == g.label
                            Button {
                                selectedLabel = g.label
                            } label: {
                                Text("\(g.label) (\(g.items.count))").font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(active ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.12), in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                let shown = groups.first { $0.label == (selectedLabel ?? groups.first?.label) } ?? groups[0]
                ForEach(shown.items) { item in
                    Button { onSelectRelated(item.other) } label: {
                        HStack(spacing: 6) {
                            Text(EntityReader.name(item.other, in: context) ?? "—")
                                .font(.system(size: 12))
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
#endif
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Detail/RelationTabsView.swift PropertyAtlas/PropertyAtlas/Studio/Detail/EntityCard.swift
git commit -m "feat(studio): RelationTabsView edge groups + related navigation"
```

---

## Task 15: EntityEditor shell — 5 tab 骨架

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift`

§6.3 shell：header（kind chip + name + ⋯ menu）+ Tabs（基本/关联/媒体/自定义/私密）。tab 内容在后续 task。build verify。

- [ ] **Step 1: 写 EntityEditor shell**

```swift
// PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EntityEditor: View {
    let ref: EntityRef
    let datasetId: UUID
    @Bindable var appState: AppState
    let onClose: () -> Void
    let onDelete: () -> Void
    let onSelectRelated: (EntityRef) -> Void

    @Environment(\.modelContext) private var context
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            ScrollView {
                Group {
                    switch appState.currentEditTab {
                    case .basic: EditorBasicTab(ref: ref, datasetId: datasetId)
                    case .relations: EditorRelationsTab(ref: ref, datasetId: datasetId, onSelectRelated: onSelectRelated)
                    case .media: EditorMediaTab(ref: ref)
                    case .custom: EditorCustomTab(ref: ref, datasetId: datasetId, showPrivate: false)
                    case .privateNotes: EditorCustomTab(ref: ref, datasetId: datasetId, showPrivate: true)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 320)
        .frame(maxHeight: 760)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        .onAppear { name = EntityReader.name(ref, in: context) ?? "" }
        .onChange(of: ref) { _, _ in name = EntityReader.name(ref, in: context) ?? "" }
    }

    private var header: some View {
        HStack(spacing: 8) {
            TextField("名称", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .bold))
                .onSubmit { EntityWriter.setName(ref, name, in: context) }
            Menu {
                Button(role: .destructive) { onDelete() } label: { Label("删除", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle") }
            Button(action: { EntityWriter.setName(ref, name, in: context); onClose() }) {
                Image(systemName: "checkmark.circle.fill")
            }.buttonStyle(.plain)
        }
        .padding(10)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tab("基本", .basic); tab("关联", .relations); tab("媒体", .media)
            tab("自定义", .custom); tab("私密", .privateNotes)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
    }

    private func tab(_ title: String, _ value: AppState.EditTab) -> some View {
        let active = appState.currentEditTab == value
        return Button { appState.currentEditTab = value } label: {
            Text(title).font(.system(size: 11, weight: active ? .bold : .regular))
                .foregroundStyle(active ? Color.accentColor : .secondary)
        }.buttonStyle(.plain)
    }
}
#endif
```

> 后续 task 创建 `EditorBasicTab` / `EditorRelationsTab` / `EditorMediaTab` / `EditorCustomTab`。本 task 为可独立 build，临时在文件末尾 `#endif` 之前加 4 个 stub：
> ```swift
> #if targetEnvironment(macCatalyst)
> struct EditorBasicTab: View { let ref: EntityRef; let datasetId: UUID; var body: some View { EmptyView() } }
> struct EditorRelationsTab: View { let ref: EntityRef; let datasetId: UUID; let onSelectRelated: (EntityRef) -> Void; var body: some View { EmptyView() } }
> struct EditorMediaTab: View { let ref: EntityRef; var body: some View { EmptyView() } }
> struct EditorCustomTab: View { let ref: EntityRef; let datasetId: UUID; let showPrivate: Bool; var body: some View { EmptyView() } }
> #endif
> ```
> 各后续 task 删对应 stub、移到独立文件实现。

- [ ] **Step 2: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift
git commit -m "feat(studio): EntityEditor shell with 5-tab scaffold"
```

---

## Task 16: EditorBasicTab — 坐标 + baseField 编辑（自动保存）

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Editor/EditorBasicTab.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift`（删 EditorBasicTab stub）

§6.3 基本 tab：坐标 + per-type baseFields（据 EntityFieldSchema 通用渲染）+ 样式 disclosure（Task 17）。build verify。

- [ ] **Step 1: 删 EntityEditor 内 EditorBasicTab stub**

- [ ] **Step 2: 写 EditorBasicTab**

```swift
// PropertyAtlas/PropertyAtlas/Studio/Editor/EditorBasicTab.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EditorBasicTab: View {
    let ref: EntityRef
    let datasetId: UUID
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ref.kind != .area {
                coordRow
            }
            ForEach(EntityFieldSchema.fields(for: ref.kind), id: \.key) { f in
                fieldEditor(f)
            }
            StyleOverrideSection(ref: ref)
        }
    }

    private var coordRow: some View {
        let c = EntityReader.coordinate(ref, in: context)
        return HStack(spacing: 6) {
            Text("坐标").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Text(c.map { String(format: "%.5f, %.5f", $0.latitude, $0.longitude) } ?? "—")
                .font(.system(size: 12)).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func fieldEditor(_ f: FieldDescriptor) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(f.label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            switch f.kind {
            case .string, .enumRef:
                StringFieldEditor(ref: ref, key: f.key)
            case .int:
                IntFieldEditor(ref: ref, key: f.key)
            case .bool:
                BoolFieldEditor(ref: ref, key: f.key)
            }
        }
    }
}

private struct StringFieldEditor: View {
    let ref: EntityRef; let key: String
    @Environment(\.modelContext) private var context
    @State private var text = ""
    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 12)).textFieldStyle(.roundedBorder)
            .onAppear { if case let .string(v) = EntityReader.value(ref, key: key, in: context) { text = v } }
            .onSubmit { EntityWriter.setValue(ref, key: key, value: .string(text), in: context) }
    }
}

private struct IntFieldEditor: View {
    let ref: EntityRef; let key: String
    @Environment(\.modelContext) private var context
    @State private var text = ""
    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 12)).textFieldStyle(.roundedBorder)
            .onAppear { if case let .int(v) = EntityReader.value(ref, key: key, in: context) { text = String(v) } }
            .onSubmit { if let n = Int(text) { EntityWriter.setValue(ref, key: key, value: .int(n), in: context) } }
    }
}

private struct BoolFieldEditor: View {
    let ref: EntityRef; let key: String
    @Environment(\.modelContext) private var context
    @State private var on = false
    var body: some View {
        Toggle("", isOn: $on)
            .labelsHidden()
            .onAppear { if case let .bool(v) = EntityReader.value(ref, key: key, in: context) { on = v } }
            .onChange(of: on) { _, v in EntityWriter.setValue(ref, key: key, value: .bool(v), in: context) }
    }
}
#endif
```

> `StyleOverrideSection` 在 Task 17 创建。本 task 为可独立 build，临时在 `#endif` 之前加 stub：
> ```swift
> #if targetEnvironment(macCatalyst)
> struct StyleOverrideSection: View { let ref: EntityRef; var body: some View { EmptyView() } }
> #endif
> ```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Editor/EditorBasicTab.swift PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift
git commit -m "feat(studio): EditorBasicTab coord + schema-driven baseField editors"
```

---

## Task 17: StyleOverrideSection — §5.5 样式 disclosure

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Editor/StyleOverrideSection.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Editor/EditorBasicTab.swift`（删 stub）

§5.5：形状/填色/glyph/size/label override，"清空 → 跟随主题"。写回 `overrideStyleJSON`。build verify。

- [ ] **Step 1: 删 EditorBasicTab 内 StyleOverrideSection stub**

- [ ] **Step 2: 写 StyleOverrideSection**

```swift
// PropertyAtlas/PropertyAtlas/Studio/Editor/StyleOverrideSection.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct StyleOverrideSection: View {
    let ref: EntityRef
    @Environment(\.modelContext) private var context
    @State private var expanded = false
    @State private var override = OverrideStyle()

    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("形状").font(.system(size: 11)).frame(width: 60, alignment: .leading)
                    Picker("", selection: Binding(
                        get: { override.shape ?? "" },
                        set: { override.shape = $0.isEmpty ? nil : $0; persist() }
                    )) {
                        Text("跟随").tag("")
                        ForEach(shapes, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden()
                }
                HStack {
                    Text("Glyph").font(.system(size: 11)).frame(width: 60, alignment: .leading)
                    TextField("0/2", text: Binding(
                        get: { override.glyph ?? "" },
                        set: { override.glyph = $0.isEmpty ? nil : String($0.prefix(2)); persist() }
                    )).textFieldStyle(.roundedBorder).frame(width: 60)
                }
                HStack {
                    Text("填色").font(.system(size: 11)).frame(width: 60, alignment: .leading)
                    TextField("#RRGGBB", text: Binding(
                        get: { override.fillHex ?? "" },
                        set: { override.fillHex = $0.isEmpty ? nil : $0; persist() }
                    )).textFieldStyle(.roundedBorder).frame(width: 90)
                }
                Button("清空 → 跟随主题") {
                    override = OverrideStyle(); persist()
                }.font(.system(size: 11)).foregroundStyle(.red)
            }
            .padding(.top, 6)
        } label: {
            Text("样式 (默认跟随主题)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
        }
        .onAppear { override = OverrideStyleCodec.decode(EntityReader.overrideStyleJSON(ref, in: context)) }
    }

    private func persist() {
        EntityWriter.setOverrideStyleJSON(ref, OverrideStyleCodec.encode(override), in: context)
    }
}
#endif
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Editor/StyleOverrideSection.swift PropertyAtlas/PropertyAtlas/Studio/Editor/EditorBasicTab.swift
git commit -m "feat(studio): StyleOverrideSection writes entity overrideStyleJSON"
```

---

## Task 18: EditorRelationsTab + RelationPicker — Edge 编辑入口

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Editor/EditorRelationsTab.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift`（删 stub）

§4.4 入口 1：关联 tab `[+ 加关联]` → 选目标实体 → 选 label（EnumOption scope="edge.label"，可加新）→ 保存。build verify。

- [ ] **Step 1: 删 EntityEditor 内 EditorRelationsTab stub**

- [ ] **Step 2: 写 EditorRelationsTab（含 inline RelationPicker）**

```swift
// PropertyAtlas/PropertyAtlas/Studio/Editor/EditorRelationsTab.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EditorRelationsTab: View {
    let ref: EntityRef
    let datasetId: UUID
    let onSelectRelated: (EntityRef) -> Void
    @Environment(\.modelContext) private var context
    @State private var showPicker = false
    @State private var refreshToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { showPicker = true } label: { Label("加关联", systemImage: "plus.circle") }
                .font(.system(size: 12))
            let groups = EdgeStore.relations(of: ref, datasetId: datasetId, in: context)
            ForEach(groups) { g in
                VStack(alignment: .leading, spacing: 4) {
                    Text(g.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(g.items) { item in
                        HStack(spacing: 6) {
                            Button { onSelectRelated(item.other) } label: {
                                Text(EntityReader.name(item.other, in: context) ?? "—").font(.system(size: 12))
                            }.buttonStyle(.plain)
                            Spacer()
                            Button {
                                EdgeStore.removeEdge(item.edgeId, in: context); refreshToken += 1
                            } label: { Image(systemName: "minus.circle").foregroundStyle(.red) }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .id(refreshToken)
        .sheet(isPresented: $showPicker) {
            RelationPicker(ref: ref, datasetId: datasetId) { target, label in
                EdgeStore.add(datasetId: datasetId, from: ref, to: target, label: label, in: context)
                refreshToken += 1; showPicker = false
            } onCancel: { showPicker = false }
        }
    }
}

private struct RelationPicker: View {
    let ref: EntityRef
    let datasetId: UUID
    let onPick: (EntityRef, String) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var context
    @State private var kind: EntityKind = .compound
    @State private var query = ""
    @State private var label = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("加关联").font(.headline)
            Picker("类型", selection: $kind) {
                ForEach(EntityKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            TextField("搜索名称", text: $query).textFieldStyle(.roundedBorder)
            labelPicker
            ScrollView {
                ForEach(candidates(), id: \.id) { c in
                    Button {
                        guard !label.isEmpty else { return }
                        onPick(EntityRef(id: c.id, kind: kind), label)
                    } label: {
                        HStack { Text(c.name).font(.system(size: 12)); Spacer() }
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.vertical, 2)
                }
            }.frame(height: 200)
            HStack { Spacer(); Button("取消", action: onCancel) }
        }
        .padding(16).frame(width: 360)
    }

    private var labelPicker: some View {
        let dsId = datasetId
        let fd = FetchDescriptor<EnumOption>(
            predicate: #Predicate { $0.datasetId == dsId && $0.scope == "edge.label" && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let opts = (try? context.fetch(fd)) ?? []
        return HStack {
            Picker("关系", selection: $label) {
                Text("选关系…").tag("")
                ForEach(opts, id: \.id) { Text($0.label).tag($0.label) }
            }
            TextField("或新建", text: $label).textFieldStyle(.roundedBorder).frame(width: 100)
        }
    }

    private struct Candidate: Identifiable { let id: UUID; let name: String }

    private func candidates() -> [Candidate] {
        let dsId = datasetId
        let q = query
        func map<T: PersistentModel>(_ list: [T], _ name: (T) -> String, _ id: (T) -> UUID) -> [Candidate] {
            list.map { Candidate(id: id($0), name: name($0)) }
                .filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) }
        }
        switch kind {
        case .compound:
            let fd = FetchDescriptor<Compound>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            return map((try? context.fetch(fd)) ?? [], { $0.name }, { $0.id })
        case .school:
            let fd = FetchDescriptor<School>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            return map((try? context.fetch(fd)) ?? [], { $0.name }, { $0.id })
        case .poi:
            let fd = FetchDescriptor<POI>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            return map((try? context.fetch(fd)) ?? [], { $0.name }, { $0.id })
        case .area:
            let fd = FetchDescriptor<Area>(predicate: #Predicate { $0.datasetId == dsId && !$0.deleted })
            return map((try? context.fetch(fd)) ?? [], { $0.name }, { $0.id })
        }
    }
}
#endif
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Editor/EditorRelationsTab.swift PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift
git commit -m "feat(studio): EditorRelationsTab + RelationPicker for edge CRUD"
```

---

## Task 19: EditorCustomTab — 自定义字段 + 私密 tab

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Editor/EditorCustomTab.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift`（删 stub）

自定义 tab：按 `CustomFieldDef` 列渲染（string 编辑，写回 `customFieldsJSON`）。私密 tab（showPrivate=true）：`privateNotes` TextEditor。build verify。

- [ ] **Step 1: 删 EntityEditor 内 EditorCustomTab stub**

- [ ] **Step 2: 写 EditorCustomTab**

```swift
// PropertyAtlas/PropertyAtlas/Studio/Editor/EditorCustomTab.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EditorCustomTab: View {
    let ref: EntityRef
    let datasetId: UUID
    let showPrivate: Bool
    @Environment(\.modelContext) private var context
    @State private var privateText = ""

    var body: some View {
        if showPrivate {
            VStack(alignment: .leading, spacing: 6) {
                Label("私密备注（不进 export / 直播）", systemImage: "lock.fill")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                TextEditor(text: $privateText)
                    .font(.system(size: 12)).frame(minHeight: 160)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.gray.opacity(0.3)))
                    .onAppear { privateText = EntityReader.notes(ref, in: context).privateNotes ?? "" }
                    .onChange(of: privateText) { _, v in
                        EntityWriter.setPrivateNotes(ref, v.isEmpty ? nil : v, in: context)
                    }
            }
        } else {
            customFields
        }
    }

    private var customFields: some View {
        let dsId = datasetId
        let etype = ref.typeString
        let fd = FetchDescriptor<CustomFieldDef>(
            predicate: #Predicate { $0.datasetId == dsId && $0.entityType == etype && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let defs = (try? context.fetch(fd)) ?? []
        return VStack(alignment: .leading, spacing: 10) {
            if defs.isEmpty {
                Text("无自定义字段").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach(defs, id: \.id) { def in
                HStack(alignment: .top, spacing: 6) {
                    Text(def.label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    CustomStringEditor(ref: ref, key: def.key)
                }
            }
        }
    }
}

private struct CustomStringEditor: View {
    let ref: EntityRef; let key: String
    @Environment(\.modelContext) private var context
    @State private var text = ""

    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 12)).textFieldStyle(.roundedBorder)
            .onAppear { if case let .string(v) = EntityReader.value(ref, key: key, in: context) { text = v } }
            .onSubmit { write() }
    }

    private func write() {
        var dict: [String: AnyJSON] = EntityReader.customFieldsJSON(ref, in: context)
            .flatMap { try? JSONHelpers.decode($0) } ?? [:]
        dict[key] = text.isEmpty ? .null : .string(text)
        EntityWriter.setCustomFieldsJSON(ref, try? JSONHelpers.encode(dict), in: context)
    }
}
#endif
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Editor/EditorCustomTab.swift PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift
git commit -m "feat(studio): EditorCustomTab custom fields + private notes"
```

---

## Task 20: EditorMediaTab — 照片列表（最小）

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Editor/EditorMediaTab.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift`（删 stub）

最小版：列已挂 Photo（按 ownerEntityId）+ 占位「加图」按钮（实际 PhotosPicker 集成留 P3.5）。build verify。

- [ ] **Step 1: 删 EntityEditor 内 EditorMediaTab stub**

- [ ] **Step 2: 写 EditorMediaTab**

```swift
// PropertyAtlas/PropertyAtlas/Studio/Editor/EditorMediaTab.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EditorMediaTab: View {
    let ref: EntityRef
    @Environment(\.modelContext) private var context

    var body: some View {
        let ownerId = ref.id
        let fd = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.ownerEntityId == ownerId && !$0.deleted },
            sortBy: [SortDescriptor(\.order)]
        )
        let photos = (try? context.fetch(fd)) ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("照片 (\(photos.count))").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(photos, id: \.id) { p in
                HStack(spacing: 6) {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                    Text(p.caption ?? p.url).font(.system(size: 12)).lineLimit(1)
                }
            }
            Text("（加图 / 加文档：PhotosPicker 集成留 P3.5）")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
}
#endif
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Editor/EditorMediaTab.swift PropertyAtlas/PropertyAtlas/Studio/Editor/EntityEditor.swift
git commit -m "feat(studio): EditorMediaTab photo list (minimal)"
```

---

## Task 21: RightDrawer — 按 mode 宿主 card/editor

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/RightDrawer.swift`

按 `appState.editingMode` + `selectedRef` 显示 EntityCard（read）或 EntityEditor（edit）。build verify。

- [ ] **Step 1: 写 RightDrawer**

```swift
// PropertyAtlas/PropertyAtlas/Studio/RightDrawer.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct RightDrawer: View {
    @Bindable var appState: AppState
    let datasetId: UUID
    @Environment(\.modelContext) private var context

    var body: some View {
        if let ref = appState.selectedRef {
            Group {
                switch appState.editingMode {
                case .edit:
                    EntityEditor(
                        ref: ref, datasetId: datasetId, appState: appState,
                        onClose: { appState.editingMode = .read },
                        onDelete: {
                            EdgeStore.cascadeSoftDelete(entityId: ref.id, datasetId: datasetId, in: context)
                            EntityWriter.softDelete(ref, in: context)
                            appState.clearSelection()
                        },
                        onSelectRelated: { appState.select($0) }
                    )
                default:
                    EntityCard(
                        ref: ref, datasetId: datasetId,
                        onEdit: { appState.beginEditing() },
                        onClose: { appState.clearSelection() },
                        onSelectRelated: { appState.select($0) }
                    )
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}
#endif
```

- [ ] **Step 2: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/RightDrawer.swift
git commit -m "feat(studio): RightDrawer hosts card/editor by editing mode"
```

---

## Task 22: StudioRootView 接线 — AppState + selection + spotlight + RightDrawer

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`

把 AppState 注入 StudioRootView；pin tap → `appState.select`；构建 pins 时按 SpotlightResolver 设 dim/highlight；drawEdgeLines 出 polyline；RightDrawer 浮在 trailing。build + smoke。

- [ ] **Step 1: StudioRootView 加 AppState + selection 接线**

在 `StudioRootView` 内：

1. 加 `@State private var appState = AppState()`（替换原 `selectedEntityId`）。
2. `MapContainerView` 的 `onSchoolSelect` 改为按当前可见 pins 解析 tap id → kind：传 `onSchoolSelect: { id in handleTap(id) }`，新增方法：

```swift
    private func handleTap(_ id: UUID?) {
        guard let id else { appState.clearSelection(); return }
        // pins 已知 entityType：在 buildPins 时建 idKind 映射；这里查 selectedRef
        if let kind = lastIdKind[id] { appState.select(EntityRef(id: id, kind: kind)) }
    }
```

3. 加 `@State private var lastIdKind: [UUID: EntityKind] = [:]`，在 `buildPins` 内每追加一个 PinAnnotation 时记录 `map[entityId]=kind`，返回 `(pins, idKind)`，body 内 `lastIdKind = idKind`。

> 由于 `buildPins` 现返回 `[MKAnnotation]`，改签名返回 `(pins: [MKAnnotation], idKind: [UUID: EntityKind])`，并在 body 用：
> ```swift
> let built = buildPins(...)
> let pins = built.pins
> // body 内不能直接赋 @State；用 .onChange/.task 同步：
> ```
> 在 `ZStack { ... }` 后加 `.onChange(of: pins.count) { _, _ in lastIdKind = built.idKind }` 并在 `.onAppear` 也设一次。或更简单：把 idKind 计算移到独立 `computeIdKind()` 并在 onAppear/onChange(datasetId) 刷新。采用后者（见 Step 2 完整代码）。

- [ ] **Step 2: StudioRootView body 完整替换（含 spotlight + edge lines + RightDrawer）**

将 `StudioRootView` 的 `body` 与 `buildPins`/`buildAreaOverlays` 调整为：

```swift
    var body: some View {
        let activeTheme = themeContext?.activeTheme
        let palettesById: [UUID: Palette] = Dictionary(uniqueKeysWithValues: palettes.map { ($0.id, $0) })
        let activeRuleIds = Set(activeTheme?.styleRuleIds ?? [])
        let rulesForTheme = styleRules.filter { activeRuleIds.contains($0.id) }
        let visibility = visibilityFromTheme(activeTheme)
        let dsId = themeContext?.datasetIdValue ?? UUID()

        // spotlight：选中 entity 的关联对端 id
        let relatedIds: [UUID] = appState.selectedRef.map {
            EdgeStore.relations(of: $0, datasetId: dsId, in: modelContext)
                .flatMap { $0.items.map { $0.other.id } }
        } ?? []
        let highlight = SpotlightResolver.highlightedIds(
            selected: appState.selectedRef?.id, relatedIds: relatedIds,
            enabled: activeTheme?.spotlightOnSelect ?? false
        )

        let pins = buildPins(
            compounds: visibility["compound"] == true ? compounds : [],
            schools: visibility["school"] == true ? schools : [],
            pois: visibility["poi"] == true ? pois : [],
            theme: activeTheme, rules: rulesForTheme, palettes: palettesById,
            highlight: highlight
        )
        let (areaOverlays, styleMap) = visibility["area"] == true
            ? buildAreaOverlays(areas: areas, theme: activeTheme, rules: rulesForTheme, palettes: palettesById)
            : ([], [:])
        let edgeLines = buildEdgeLines(theme: activeTheme, datasetId: dsId)
        let overlays = areaOverlays + edgeLines

        ZStack {
            MapContainerView(
                camera: $camera, overlays: overlays, annotations: pins,
                rendererFor: { overlay in
                    if let polygon = overlay as? MKPolygon, let style = styleMap[ObjectIdentifier(overlay)] {
                        return AreaOverlayRenderer(polygon: polygon, style: style)
                    }
                    return nil
                },
                onRegionChange: { visibleRegion = $0 },
                onSchoolSelect: { id in
                    if let id, let kind = idKind(for: id, in: pins) { appState.select(EntityRef(id: id, kind: kind)) }
                    else { appState.clearSelection() }
                }
            )
            .ignoresSafeArea()

            if let ctx = themeContext {
                StudioOverlay(title: $title, subtitle: $subtitle, watermark: $watermark,
                              aspect: $aspect, themeContext: ctx)
            }

            HStack {
                Spacer()
                RightDrawer(appState: appState, datasetId: dsId)
                    .padding(.top, 80).padding(.trailing, 16).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .animation(.easeInOut(duration: 0.2), value: appState.selectedRef)
        }
        .onAppear { ensureThemeContext() }
        .onChange(of: datasets.first?.id) { _, _ in ensureThemeContext() }
    }

    private func idKind(for id: UUID, in pins: [MKAnnotation]) -> EntityKind? {
        for case let p as PinAnnotation in pins where p.entityId == id {
            return EntityKind(rawValue: p.entityType)
        }
        return nil
    }

    private func buildEdgeLines(theme: Theme?, datasetId: UUID) -> [MKOverlay] {
        guard let labels = theme?.drawEdgeLines, !labels.isEmpty else { return [] }
        let labelSet = Set(labels)
        let fd = FetchDescriptor<Edge>(predicate: #Predicate { $0.datasetId == datasetId && !$0.deleted })
        let edges = ((try? modelContext.fetch(fd)) ?? []).filter { labelSet.contains($0.label) }
        var segs: [(CLLocationCoordinate2D, CLLocationCoordinate2D)] = []
        for e in edges {
            guard let a = EntityReader.coordinate(EntityRef(id: e.fromId, kind: EntityKind(rawValue: e.fromType) ?? .poi), in: modelContext),
                  let b = EntityReader.coordinate(EntityRef(id: e.toId, kind: EntityKind(rawValue: e.toType) ?? .poi), in: modelContext)
            else { continue }
            segs.append((a, b))
        }
        return EdgeLineFactory.polylines(from: segs)
    }
```

`buildPins` 改加 `highlight: Set<UUID>?` 参数，在每个 `PinAnnotation` 构建后设标记：

```swift
            let pin = PinAnnotation(entityId: c.id, entityType: "compound", name: c.name,
                                    coordinate: c.coordinate, style: style)
            if let highlight {
                pin.highlighted = highlight.contains(c.id)
                pin.dimmed = !highlight.contains(c.id)
            }
            result.append(pin)
```

（school/poi 三处同样处理。）`buildPins` 返回类型保持 `[MKAnnotation]`。

> `themeContext?.datasetIdValue`：`ThemeContext` 现无公开 datasetId。在 `ThemeContext` 加：
> ```swift
> var datasetIdValue: UUID { dataset.id }
> ```

- [ ] **Step 3: ThemeContext 暴露 datasetIdValue**

`MapRender/ThemeContext.swift` 加 `var datasetIdValue: UUID { dataset.id }`。

- [ ] **Step 4: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/RootView.swift PropertyAtlas/PropertyAtlas/MapRender/ThemeContext.swift
git commit -m "feat(studio): wire AppState selection + spotlight + edge lines + RightDrawer"
```

---

## Task 23: 创建流程 — 右键(Mac)/长按(iPad) 建 Pin

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Map/MapKitView.swift`
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`

§6.4 第 1 条：地图右键(Mac)/长按(iPad) → 菜单 `[+ Compound/+ School/+ POI]` → 落点建 entity，右抽屉打开 editor。build + smoke。

- [ ] **Step 1: MapKitView 加坐标手势回调**

`MapKitView` 加 `var onLongPressCoordinate: ((CLLocationCoordinate2D) -> Void)?`，coordinator 持同名闭包。`makeUIView` 内加手势：

```swift
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        v.addGestureRecognizer(longPress)
        context.coordinator.mapViewRef = v
```

`updateUIView` / `makeUIView` 内设 `context.coordinator.onLongPressCoordinate = onLongPressCoordinate`。

Coordinator 加：

```swift
        weak var mapViewRef: MKMapView?
        var onLongPressCoordinate: ((CLLocationCoordinate2D) -> Void)?

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began, let mv = mapViewRef else { return }
            let pt = g.location(in: mv)
            let coord = mv.convert(pt, toCoordinateFrom: mv)
            onLongPressCoordinate?(coord)
        }
```

> Mac Catalyst 下 `UILongPressGestureRecognizer` 对 trackpad 长按/右键长按生效，满足 §6.4 Mac 入口（右键菜单的完整 contextMenu 集成留 P3.5；本 task 用长按统一两端）。

`MapContainerView` 透传 `onLongPressCoordinate` 参数（init 加，body 传给 MapKitView），默认 nil。

- [ ] **Step 2: RootView 接建 Pin 菜单**

StudioRootView 加：

```swift
    @State private var pendingCoordinate: CLLocationCoordinate2D?
    @State private var showCreateMenu = false
```

`MapContainerView(...)` 加参数 `onLongPressCoordinate: { coord in pendingCoordinate = coord; showCreateMenu = true }`。

在 `ZStack` 末尾（`.onChange` 之前）加 confirmationDialog：

```swift
        .confirmationDialog("新建实体", isPresented: $showCreateMenu, titleVisibility: .visible) {
            Button("+ 小区") { createPin(.compound) }
            Button("+ 学校") { createPin(.school) }
            Button("+ POI") { createPin(.poi) }
            Button("取消", role: .cancel) {}
        }
```

加方法：

```swift
    private func createPin(_ kind: EntityKind) {
        guard let coord = pendingCoordinate, let dsId = themeContext?.datasetIdValue else { return }
        let ref = EntityWriter.createPin(kind: kind, datasetId: dsId, name: "未命名",
                                         latitude: coord.latitude, longitude: coord.longitude, in: modelContext)
        appState.select(ref)
        appState.beginEditing()
    }
```

- [ ] **Step 3: Build verify**

Run: `xcodebuild build ... 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Map/MapKitView.swift PropertyAtlas/PropertyAtlas/RootView.swift
git commit -m "feat(studio): long-press/right-click create pin → open editor"
```

---

## Task 24: smoke + CLAUDE.md P3 节点

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: 全套单测 + build**

Run:
```bash
xcodebuild test -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' > /tmp/p3_test.log 2>&1; echo "EXIT=$?"
grep -ac "' passed on '" /tmp/p3_test.log
grep -ac "' failed (" /tmp/p3_test.log
```
Expected: 0 failed unit cases（UI test runner 环境失败可忽略，与 P2 同）。

- [ ] **Step 2: Mac Catalyst 启动 smoke**

```bash
APP="/Users/fujie/Library/Developer/Xcode/DerivedData/PropertyAtlas-bprzusitconimnalstksmnielbtk/Build/Products/Debug-maccatalyst/PropertyAtlas.app"
open "$APP"; sleep 4
pgrep -x PropertyAtlas >/dev/null && echo "ALIVE" || echo "CRASH"; pkill -x PropertyAtlas
```
Expected: `ALIVE`。手动确认（人工）：点 pin → 详情卡浮出；编辑→改字段→关闭→重选值保留；加关联→对端出现在 tab；长按地图→建 Pin→editor 开。

- [ ] **Step 3: 更新 CLAUDE.md**

Key Documents 加：
```markdown
- 实施计划 P3 (已完成): `docs/superpowers/plans/2026-05-31-p3-interaction-editing-core.md`
```

Critical Architecture 加 NOTE：
```markdown
> **P3 (2026-05-31) 完成后**: `AppState` 驱动 selection/editingMode/editTab。
> 点 pin → `EntityCard`(读) → `EntityEditor`(5 tab: 基本/关联/媒体/自定义/私密)。
> Edge 经 `EdgeStore` 双向查询 + 校验 + 级联软删；关联 tab 增删。实体读写
> 经 `EntityReader`/`EntityWriter`(按 `EntityRef`)，可编辑 baseField 由
> `EntityFieldSchema` 单一声明。override 样式经 `OverrideStyleCodec`。spotlight
> (`SpotlightResolver`)+drawEdgeLines(`EdgeLineFactory`) 已接。长按/右键建 Pin。
> 延后: POI 外部搜索 / Area 绘制+raster / PhotosPicker → P3.5；Settings/Filter/Layer → P4。
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): note P3 interaction + editing core completion"
```

---

## Self-Review 总结

**Spec 覆盖 vs §4 + §6（核心闭环范围）:**
- §4.1 Edge schema + 双向查询 groupBy label: Task 5
- §4.2 校验（自连/重复/级联软删）: Task 6 / 7
- §4.3 详情卡 tab（header + 字段表 + edge 分组 + 关联跳转）: Task 13 / 14（媒体 tab 读最小版 Task 20）
- §4.4 Edge 编辑入口 1（关联 tab picker）: Task 18；入口 2（Settings 表格）: **延 P4**
- §4.5 视觉（drawEdgeLines dashed + 选中脉冲高亮）: Task 9-12 / 22
- §5.5 Entity override 编辑 UI: Task 4 / 17
- §6.1 主布局（RightDrawer 浮动）: Task 21 / 22；LeftDrawer(Layers/Legend): **延 P4**
- §6.2 取景态 chrome 全隐: **延 P3.5**（本 plan 未含 mode toggle UI）
- §6.3 EntityEditor 5 tab: Task 15-20
- §6.4 创建流程：Pin 长按/右键: Task 23；POI 搜索 / Area 绘制: **延 P3.5**
- §6.5 Settings: **延 P4**
- §6.7 AppState: Task 8

**明确延后（已在范围边界声明）:** POI 外部搜索、Area polygon/raster、PhotosPicker、取景态、Settings 全页、§5.7/5.8、CloudKit。

**Placeholder 扫描:** 无 TBD；UI stub 均在同 task 或下一 task 明确替换（Task 13/15/16 的 stub → Task 14/16/17 删除）。

**Type 一致性核对:**
- `EntityKind` rawValue = `"compound"/"school"/"poi"/"area"`，与 `PinAnnotation.entityType`、`Edge.fromType`、`styleEntity.entityType` 一致。
- `EntityRef(id:kind:)`、`EntityReader.fetch(_:_:_:)`(4 重载)、`EntityWriter.createPin/setValue/setName/...`、`EdgeStore.relations/add/removeEdge/cascadeSoftDelete`、`OverrideStyleCodec.encode/decode`、`AppState.select/beginEditing/clearSelection`、`SpotlightResolver.highlightedIds`、`EdgeLineFactory.polylines` —— 跨 task 签名一致。
- `EntityReader.value` 经 `styleEntity.field`，与 P2 `StyleEntity.field(_)` 复用，键名（finishType/category/grade/form/isNewHouse…）与 styleEntity adapter 中 base 字段键一致。
- `ThemeContext.datasetIdValue` Task 22 新增，Task 22 内使用一致。

**已知 follow-up（P3.5）:** POI MKLocalSearch、Area 绘制/raster、PhotosPicker 加图加文档、取景态 chrome 隐藏 + mode toggle、右键 contextMenu（区别于长按）。

---

**End of P3 plan**
