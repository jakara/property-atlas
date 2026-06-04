# 图层成员归属模型(单归属)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把图层从「类型白名单并集」改成「单归属成员模型」——每个实体经 `layerId` 恰好归属一个图层,可见 ⟺ 所属图层启用。

**Architecture:** 四个实体 `@Model` 各加 `layerId: UUID?`(nil 兜底到 dataset 的【默认】图层)。`LayerEvaluator` 重写为按 `layerId` 归属判定,删除 match-all/类型放行。迁移把现有数据全归【默认】(原【全部】改名),启动幂等 backfill 兜底旧库。UI:编辑器加「所属图层」下拉、长按新建弹层选启用图层、删层成员退回默认。

**Tech Stack:** SwiftUI · SwiftData · Swift Testing · Mac Catalyst。spec:`docs/superpowers/specs/2026-06-04-layer-membership-model.md`。

**构建命令(每个 build 步骤复用):**
```
cd PropertyAtlas && xcodebuild -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -configuration Debug build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
**测试命令:**
```
cd PropertyAtlas && xcodebuild test -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/LayerEvaluatorTests 2>&1 | grep -E "Test Suite|passed|failed|error:"
```

---

## File Structure

| 文件 | 职责 / 改动 |
|---|---|
| `PropertyAtlas/Models/Entities/{Compound,School,POI,Area}.swift` | 各加 `var layerId: UUID?` |
| `PropertyAtlas/DataKit/LayerAssignable.swift`(新) | `protocol LayerAssignable` + 四实体 conformance |
| `PropertyAtlas/MapRender/LayerEvaluator.swift` | 重写:`Candidate{id,layerId}`、`ActiveLayer{id,...}`、按 layerId 判可见/归属 |
| `PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift` | 全量重写 |
| `PropertyAtlas/DataKit/EntityReader.swift` | `layerId(_:in:)` |
| `PropertyAtlas/DataKit/EntityWriter.swift` | `setLayer(_:_:in:)`;`createPin` 加 `layerId` 参数 |
| `PropertyAtlas/DataKit/LegacyMigrator.swift` | 默认层改名「默认」;`backfillLayerIds(in:)` |
| `PropertyAtlas/States/SeedImporter.swift` | 启动 + seed 后调 backfill |
| `PropertyAtlas/RootView.swift` | `Cand.layerId`、`namedLayers`/`evalCands`/`defaultLayerId` 接新签名、`createPin(layerId:)`、长按改弹层 |
| `PropertyAtlas/Studio/Editor/LayerPickerRow.swift`(新) | 编辑器「所属图层」下拉 |
| `PropertyAtlas/Studio/Editor/EditorBasicTab.swift` | 插入 `LayerPickerRow` |
| `PropertyAtlas/Studio/CreateEntitySheet.swift`(新) | 长按新建:类型 + 启用图层选择 |
| `PropertyAtlas/Studio/Settings/LayerSettingsTab.swift` | 默认层禁删;删层前成员退回默认 |

---

## Task 1: 实体加 `layerId` 字段

**Files:** Modify `PropertyAtlas/PropertyAtlas/Models/Entities/Compound.swift`, `School.swift`, `POI.swift`, `Area.swift`

- [ ] **Step 1:** 四个文件各在 `var datasetId: UUID = UUID()` 行**下方**加一行(默认 nil,SwiftData 轻量迁移):

```swift
    var layerId: UUID?
```

- [ ] **Step 2:** Build。

Run 构建命令。Expected: `** BUILD SUCCEEDED **`(加可选属性不破坏现有 init / 调用)。

- [ ] **Step 3:** Commit。

```bash
git add PropertyAtlas/PropertyAtlas/Models/Entities/Compound.swift PropertyAtlas/PropertyAtlas/Models/Entities/School.swift PropertyAtlas/PropertyAtlas/Models/Entities/POI.swift PropertyAtlas/PropertyAtlas/Models/Entities/Area.swift
git commit -m "feat(layer): add layerId field to 4 entity models"
```

---

## Task 2: `LayerAssignable` 协议

**Files:** Create `PropertyAtlas/PropertyAtlas/DataKit/LayerAssignable.swift`

- [ ] **Step 1:** 写文件(给 backfill / 删层重指派提供泛型操作)。四实体已有 `datasetId` / `deleted` / (Task 1 后)`layerId`,conformance 为空。

```swift
import Foundation
import SwiftData

/// 可按 layerId 归属的实体(用于 backfill 与删层成员重指派的泛型遍历)。
protocol LayerAssignable: AnyObject {
    var datasetId: UUID { get }
    var deleted: Bool { get }
    var layerId: UUID? { get set }
}

extension Compound: LayerAssignable {}
extension School: LayerAssignable {}
extension POI: LayerAssignable {}
extension Area: LayerAssignable {}
```

- [ ] **Step 2:** Build。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3:** Commit。

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LayerAssignable.swift
git commit -m "feat(layer): add LayerAssignable protocol + conformances"
```

---

## Task 3: 重写 `LayerEvaluator`(按 layerId 归属)+ 测试

**Files:** Modify `PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift`;Rewrite `PropertyAtlas/PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift`

- [ ] **Step 1: 先写新测试(会失败)** — 全量替换 `LayerEvaluatorTests.swift`:

```swift
// PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerEvaluatorTests {
    private func cand(_ id: UUID, _ layerId: UUID?) -> LayerEvaluator.Candidate {
        LayerEvaluator.Candidate(id: id, layerId: layerId)
    }
    private func layer(_ id: UUID, enabled: Bool = true, min: Double? = nil, max: Double? = nil) -> LayerEvaluator.ActiveLayer {
        LayerEvaluator.ActiveLayer(id: id, enabled: enabled, minZoom: min, maxZoom: max)
    }

    @Test func noLayersDefinedShowsAll() {
        let def = UUID(); let a = UUID(); let b = UUID()
        let v = LayerEvaluator.visibleIds(layers: [], zoom: 10,
            candidates: [cand(a, nil), cand(b, def)], defaultLayerId: def)
        #expect(v == Set([a, b]))
    }

    @Test func allLayersDisabledHidesAll() {
        let def = UUID(); let a = UUID()
        let v = LayerEvaluator.visibleIds(layers: [layer(def, enabled: false)], zoom: 10,
            candidates: [cand(a, def)], defaultLayerId: def)
        #expect(v.isEmpty)
    }

    @Test func onlyMembersOfEnabledLayersVisible() {
        let def = UUID(); let other = UUID()
        let inDef = UUID(); let inOther = UUID(); let nilHome = UUID()
        let v = LayerEvaluator.visibleIds(
            layers: [layer(def, enabled: true), layer(other, enabled: false)],
            zoom: 10,
            candidates: [cand(inDef, def), cand(inOther, other), cand(nilHome, nil)],
            defaultLayerId: def
        )
        // def 启用 → inDef + nilHome(nil 兜底到 def)可见;other 禁用 → inOther 隐藏
        #expect(v == Set([inDef, nilHome]))
    }

    @Test func zoomOutOfRangeDeactivatesLayer() {
        let def = UUID(); let a = UUID()
        let v = LayerEvaluator.visibleIds(
            layers: [layer(def, enabled: true, min: 12, max: 21)],
            zoom: 8, candidates: [cand(a, def)], defaultLayerId: def)
        #expect(v.isEmpty)
    }

    @Test func membershipMapsEntityToItsHomeLayerName() {
        let def = UUID(); let other = UUID(); let s = UUID()
        let named = [
            LayerEvaluator.NamedLayer(name: "默认", layer: layer(def, enabled: true)),
            LayerEvaluator.NamedLayer(name: "取景", layer: layer(other, enabled: true)),
        ]
        let m = LayerEvaluator.membership(layers: named, zoom: 12,
            candidates: [cand(s, other)], defaultLayerId: def)
        #expect(m[s] == ["取景"])
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run 测试命令。Expected: 编译失败(`Candidate` 无 `layerId` 初始化器 / `visibleIds` 缺 `defaultLayerId`)。

- [ ] **Step 3: 重写 `LayerEvaluator.swift`** — 全量替换:

```swift
// PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift
import Foundation

@MainActor
enum LayerEvaluator {
    struct Candidate {
        let id: UUID
        let layerId: UUID?
    }

    struct ActiveLayer {
        let id: UUID
        let enabled: Bool
        let minZoom: Double?
        let maxZoom: Double?

        func isActive(at zoom: Double) -> Bool {
            guard enabled else { return false }
            if let minZoom, zoom < minZoom { return false }
            if let maxZoom, zoom > maxZoom { return false }
            return true
        }
    }

    struct NamedLayer {
        let name: String
        let layer: ActiveLayer
    }

    /// 单归属:实体可见 ⟺ 其所属图层(layerId,nil 兜底到 defaultLayerId)启用且在 zoom 范围内。
    /// 未定义任何图层 → 无约束显示全部;定义了但无启用 → 全隐藏。
    static func visibleIds(
        layers: [ActiveLayer], zoom: Double, candidates: [Candidate], defaultLayerId: UUID
    ) -> Set<UUID> {
        guard !layers.isEmpty else { return Set(candidates.map(\.id)) }
        let activeIds = Set(layers.filter { $0.isActive(at: zoom) }.map(\.id))
        guard !activeIds.isEmpty else { return [] }
        var visible = Set<UUID>()
        for c in candidates {
            let home = c.layerId ?? defaultLayerId
            if activeIds.contains(home) { visible.insert(c.id) }
        }
        return visible
    }

    /// 每个实体 → 其所属启用图层名(单元素)。供 MapDimension.layer 投影 + 可见集 layerNames。
    static func membership(
        layers: [NamedLayer], zoom: Double, candidates: [Candidate], defaultLayerId: UUID
    ) -> [UUID: [String]] {
        var nameById: [UUID: String] = [:]
        for nl in layers where nl.layer.isActive(at: zoom) { nameById[nl.layer.id] = nl.name }
        var out: [UUID: [String]] = [:]
        for c in candidates {
            let home = c.layerId ?? defaultLayerId
            if let name = nameById[home] { out[c.id] = [name] }
        }
        return out
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run 测试命令。Expected: `LayerEvaluatorTests` 全 passed。

注:`LayerQuery.swift` 不再被引用(保留文件);若 `LayerQueryTests.swift` 仍引用旧 API 无需动(LayerQuery 类型未删)。`matchesAll` 私有方法已随重写删除。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/LayerEvaluator.swift PropertyAtlas/PropertyAtlasTests/MapRender/LayerEvaluatorTests.swift
git commit -m "feat(layer): rewrite LayerEvaluator for single-membership by layerId"
```

---

## Task 4: `EntityReader.layerId` + `EntityWriter.setLayer` + `createPin(layerId:)`

**Files:** Modify `PropertyAtlas/PropertyAtlas/DataKit/EntityReader.swift`, `EntityWriter.swift`

- [ ] **Step 1:** `EntityReader.swift` — 在 `overrideStyleJSON(...)` 方法后加:

```swift
    static func layerId(_ ref: EntityRef, in context: ModelContext) -> UUID? {
        switch ref.kind {
        case .compound: fetch(Compound.self, ref.id, context)?.layerId
        case .school: fetch(School.self, ref.id, context)?.layerId
        case .poi: fetch(POI.self, ref.id, context)?.layerId
        case .area: fetch(Area.self, ref.id, context)?.layerId
        }
    }
```

- [ ] **Step 2:** `EntityWriter.swift` — 在 `softDelete(...)` 方法后加:

```swift
    static func setLayer(_ ref: EntityRef, _ layerId: UUID?, in context: ModelContext) {
        touch(ref, in: context) { $0.layerId = layerId } s: { $0.layerId = layerId } p: { $0.layerId = layerId } a: { $0.layerId = layerId }
    }
```

- [ ] **Step 3:** `EntityWriter.swift` — `createPin` 加 `layerId` 参数并赋值。把签名

```swift
    static func createPin(
        kind: EntityKind,
        datasetId: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        in context: ModelContext
    ) -> EntityRef {
```

改为(加一行参数):

```swift
    static func createPin(
        kind: EntityKind,
        datasetId: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        layerId: UUID?,
        in context: ModelContext
    ) -> EntityRef {
```

并在每个 `case` 的 `context.insert(e)` **之前**加 `e.layerId = layerId`,例如 compound 分支:

```swift
        case .compound:
            let e = Compound(datasetId: datasetId, name: name, latitude: latitude, longitude: longitude)
            e.layerId = layerId
            context.insert(e)
            id = e.id
```

school / poi / area 三个分支同样各加 `e.layerId = layerId`(在各自 `context.insert(e)` 前)。

- [ ] **Step 4:** Build。会因 `RootView.createPin` 旧调用缺 `layerId` 报错——Task 5 之前先**临时**在 RootView 调用处补 `layerId: nil` 让其编译?不:Task 6 会改 RootView。为保持每步可编译,本步在 `RootView.swift:412` 的 `EntityWriter.createPin(...)` 调用里**临时**加 `layerId: nil,`(在 `longitude:` 行后、`in:` 前)。

Run 构建命令。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EntityReader.swift PropertyAtlas/PropertyAtlas/DataKit/EntityWriter.swift PropertyAtlas/PropertyAtlas/RootView.swift
git commit -m "feat(layer): EntityReader.layerId + EntityWriter.setLayer/createPin(layerId:)"
```

---

## Task 5: 迁移改名 + 启动 backfill

**Files:** Modify `PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift`, `PropertyAtlas/PropertyAtlas/States/SeedImporter.swift`

- [ ] **Step 1:** `LegacyMigrator.swift` — 默认层改名。把:

```swift
        let defaultLayer = Layer(datasetId: dataset.id, name: "全部")
```

改为:

```swift
        let defaultLayer = Layer(datasetId: dataset.id, name: "默认")
```

- [ ] **Step 2:** `LegacyMigrator.swift` — 在 `cleanupOrphans(in:)` 方法**之后**加 backfill(幂等:只补 nil):

```swift
    /// 把 layerId == nil 的实体补设为本 dataset 的【默认】图层。幂等,每次启动可调。
    static func backfillLayerIds(in ctx: ModelContext) {
        let datasets = (try? ctx.fetch(FetchDescriptor<Dataset>())) ?? []
        let layers = (try? ctx.fetch(FetchDescriptor<Layer>())) ?? []
        for ds in datasets {
            guard let home = layers.first(where: { $0.datasetId == ds.id && $0.isDefault && !$0.deleted })?.id
            else { continue }
            assignNilToDefault(Compound.self, ds.id, home, ctx)
            assignNilToDefault(School.self, ds.id, home, ctx)
            assignNilToDefault(POI.self, ds.id, home, ctx)
            assignNilToDefault(Area.self, ds.id, home, ctx)
        }
    }

    private static func assignNilToDefault<T>(
        _ type: T.Type, _ dsId: UUID, _ home: UUID, _ ctx: ModelContext
    ) where T: PersistentModel & LayerAssignable {
        let all = (try? ctx.fetch(FetchDescriptor<T>())) ?? []
        for e in all where e.datasetId == dsId && e.layerId == nil && !e.deleted {
            e.layerId = home
        }
    }
```

- [ ] **Step 3:** `SeedImporter.swift` — `runIfNeeded` 顶部 backfill(旧库)+ seed 后 backfill(新库)。把开头:

```swift
        // 每次启动清理无主实体(独立于 seed 守卫)
        LegacyMigrator.cleanupOrphans(in: context)
        // 已有 Dataset → 已 seed,跳过
        if try !context.fetch(FetchDescriptor<Dataset>()).isEmpty {
            progress(1.0, "已就绪")
            return false
        }
```

改为:

```swift
        // 每次启动清理无主实体(独立于 seed 守卫)
        LegacyMigrator.cleanupOrphans(in: context)
        LegacyMigrator.backfillLayerIds(in: context) // 旧库兜底:nil → 默认层
        // 已有 Dataset → 已 seed,跳过
        if try !context.fetch(FetchDescriptor<Dataset>()).isEmpty {
            try context.save()
            progress(1.0, "已就绪")
            return false
        }
```

并把 seed 分支结尾:

```swift
        progress(0.70, "迁移写入实体")
        try LegacyMigrator.run(seeds: bundle, in: context)

        progress(0.95, "保存")
        try context.save()
```

改为:

```swift
        progress(0.70, "迁移写入实体")
        try LegacyMigrator.run(seeds: bundle, in: context)
        LegacyMigrator.backfillLayerIds(in: context) // 新库:全部实体归默认层

        progress(0.95, "保存")
        try context.save()
```

- [ ] **Step 4:** Build。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/LegacyMigrator.swift PropertyAtlas/PropertyAtlas/States/SeedImporter.swift
git commit -m "feat(layer): rename default layer to 默认 + idempotent layerId backfill"
```

---

## Task 6: RootView 接新引擎签名 + 默认层 id + createPin(layerId:)

**Files:** Modify `PropertyAtlas/PropertyAtlas/RootView.swift`

- [ ] **Step 1:** `Cand` 结构加 `layerId`。找到(约 247 行附近):

```swift
    private struct Cand {
        let id: UUID
        let type: String
        let name: String
        let entity: StyleEntity
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
    }
```

在 `let type: String` 下加一行:

```swift
        let layerId: UUID?
```

- [ ] **Step 2:** `buildCandidates` 每个 `out.append(.init(...))` 加 `layerId:`。四处分别用各自实体的 `.layerId`。例如 compound:

```swift
                out.append(.init(id: c.id, type: "compound", name: c.name, entity: c.styleEntity,
                                 coordinate: c.coordinate, hasCoordinate: c.latitude != 0 || c.longitude != 0,
                                 layerId: c.layerId))
```

school 用 `s.layerId`、poi 用 `p.layerId`、area 用 `a.layerId`,同样追加 `layerId:` 末参。

- [ ] **Step 3:** 替换 `namedLayers` / `evalCands` / `layerVisible` 三段(约 114–124 行)。先在其上方取默认层 id,再改三处:

```swift
        let defaultLayerId = layersForDataset(dsId).first(where: { $0.isDefault })?.id
            ?? layersForDataset(dsId).first?.id ?? dsId
        let namedLayers = layersForDataset(dsId).map {
            LayerEvaluator.NamedLayer(
                name: $0.name,
                layer: LayerEvaluator.ActiveLayer(
                    id: $0.id, enabled: layerState.isEnabled($0.id),
                    minZoom: $0.minZoom, maxZoom: $0.maxZoom
                )
            )
        }
        let evalCands = cands.map { LayerEvaluator.Candidate(id: $0.id, layerId: $0.layerId) }
        let layerVisible = LayerEvaluator.visibleIds(
            layers: namedLayers.map(\.layer), zoom: zoom, candidates: evalCands,
            defaultLayerId: defaultLayerId
        )
```

- [ ] **Step 4:** 更新 `membership` 调用。找到:

```swift
        let membership = LayerEvaluator.membership(layers: namedLayers, zoom: zoom, candidates: evalCands)
```

改为:

```swift
        let membership = LayerEvaluator.membership(
            layers: namedLayers, zoom: zoom, candidates: evalCands, defaultLayerId: defaultLayerId
        )
```

- [ ] **Step 5:** `createPin` 改为带 layerId 参数(Task 7 的弹层会调它)。把:

```swift
    private func createPin(_ kind: EntityKind) {
        guard let coord = pendingCoordinate, let dsId = viewContext?.datasetIdValue else { return }
        let ref = EntityWriter.createPin(
            kind: kind, datasetId: dsId, name: "未命名",
            latitude: coord.latitude, longitude: coord.longitude, layerId: nil, in: modelContext
        )
        appState.select(ref)
        appState.beginEditing()
    }
```

改为:

```swift
    private func createPin(_ kind: EntityKind, layerId: UUID?) {
        guard let coord = pendingCoordinate, let dsId = viewContext?.datasetIdValue else { return }
        let ref = EntityWriter.createPin(
            kind: kind, datasetId: dsId, name: "未命名",
            latitude: coord.latitude, longitude: coord.longitude, layerId: layerId, in: modelContext
        )
        appState.select(ref)
        appState.beginEditing()
    }
```

- [ ] **Step 6:** 旧 `confirmationDialog` 调 `createPin(.compound)` 等会因签名变化报错——Task 7 会整体替换该 dialog。本步**临时**把 dialog 里三处改为 `createPin(.compound, layerId: nil)` / `.school` / `.poi` 让其编译。

- [ ] **Step 7:** Build。Expected: `** BUILD SUCCEEDED **`。空数据/默认层在,地图显示全部(行为等价上一轮)。

- [ ] **Step 8: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/RootView.swift
git commit -m "feat(layer): wire RootView to layerId-based evaluator + default layer id"
```

---

## Task 7: 长按新建弹层(类型 + 启用图层选择)

**Files:** Create `PropertyAtlas/PropertyAtlas/Studio/CreateEntitySheet.swift`;Modify `PropertyAtlas/PropertyAtlas/RootView.swift`

- [ ] **Step 1:** 新建 `CreateEntitySheet.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 长按地图新建实体:选类型 + 选一个启用图层。
struct CreateEntitySheet: View {
    let enabledLayers: [(id: UUID, name: String)]
    let defaultLayerId: UUID?
    let onCreate: (EntityKind, UUID?) -> Void
    let onCancel: () -> Void

    @State private var kind: EntityKind = .compound
    @State private var layerId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建实体").font(Studio.sans(17, .bold)).foregroundStyle(Studio.on)

            Text("类型").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            GlassSegmented(
                options: [(.compound, "小区"), (.school, "学校"), (.poi, "POI"), (.area, "片区")],
                selection: $kind
            )

            Text("归属图层").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            if enabledLayers.isEmpty {
                Text("无启用图层 → 进【默认】").font(Studio.sans(12)).foregroundStyle(Studio.on3)
            } else {
                VStack(spacing: 2) {
                    ForEach(enabledLayers, id: \.id) { l in
                        Button { layerId = l.id } label: {
                            HStack {
                                Text(l.name).font(Studio.sans(13)).foregroundStyle(Studio.on)
                                Spacer()
                                if (layerId ?? defaultLayerId) == l.id {
                                    Image(systemName: "checkmark").foregroundStyle(Studio.cool)
                                }
                            }
                            .padding(.horizontal, 10).frame(height: 38)
                            .background((layerId ?? defaultLayerId) == l.id ? Studio.glassHover : .clear,
                                        in: RoundedRectangle(cornerRadius: Studio.rControl, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                Spacer()
                Button("取消") { onCancel() }.buttonStyle(.tbtn(.ghost))
                Button("建立") { onCreate(kind, layerId ?? defaultLayerId) }.buttonStyle(.tbtn(.primary))
            }
        }
        .padding(18)
        .frame(width: 320)
        .background(Studio.glassStrong).background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Studio.rPanel, style: .continuous))
        .environment(\.colorScheme, .dark)
        .onAppear { layerId = defaultLayerId }
    }
}
#endif
```

- [ ] **Step 2:** `RootView.swift` — 替换 `confirmationDialog`。删掉(约 230–236 行):

```swift
        .confirmationDialog("新建实体", isPresented: $showCreateMenu, titleVisibility: .visible) {
            Button("+ 小区") { createPin(.compound, layerId: nil) }
            Button("+ 学校") { createPin(.school, layerId: nil) }
            Button("+ POI") { createPin(.poi, layerId: nil) }
            Button("取消", role: .cancel) {}
        }
```

换成:

```swift
        .sheet(isPresented: $showCreateMenu) {
            if let dsId = viewContext?.datasetIdValue {
                let layers = layersForDataset(dsId)
                let defaultId = layers.first(where: { $0.isDefault })?.id
                let enabled = layers.filter { layerState.isEnabled($0.id) }.map { (id: $0.id, name: $0.name) }
                CreateEntitySheet(
                    enabledLayers: enabled,
                    defaultLayerId: defaultId,
                    onCreate: { kind, layerId in
                        showCreateMenu = false
                        createPin(kind, layerId: layerId)
                    },
                    onCancel: { showCreateMenu = false }
                )
                .presentationDetents([.medium])
            }
        }
```

- [ ] **Step 3:** Build。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4:** 手动验:运行 app,长按地图 → 弹层显示类型分段 + 启用图层列表(默认选中【默认】)→ 建立 → pin 出现且归属所选层。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/CreateEntitySheet.swift PropertyAtlas/PropertyAtlas/RootView.swift
git commit -m "feat(layer): long-press create sheet with type + enabled-layer pick"
```

---

## Task 8: 编辑器「所属图层」下拉

**Files:** Create `PropertyAtlas/PropertyAtlas/Studio/Editor/LayerPickerRow.swift`;Modify `PropertyAtlas/PropertyAtlas/Studio/Editor/EditorBasicTab.swift`

- [ ] **Step 1:** 新建 `LayerPickerRow.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 实体「所属图层」下拉。改即写入 layerId 并保存。
struct LayerPickerRow: View {
    let ref: EntityRef
    let datasetId: UUID
    @Environment(\.modelContext) private var context
    @Query private var layers: [Layer]

    private var dsLayers: [Layer] {
        layers.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.zIndex < $1.zIndex }
    }
    private var defaultId: UUID? { dsLayers.first(where: { $0.isDefault })?.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("所属图层").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            Picker("", selection: Binding(
                get: { EntityReader.layerId(ref, in: context) ?? defaultId },
                set: { newValue in
                    EntityWriter.setLayer(ref, newValue, in: context)
                    try? context.save()
                }
            )) {
                ForEach(dsLayers, id: \.id) { Text($0.name).tag($0.id as UUID?) }
            }
            .labelsHidden().tint(Studio.cool)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
```

- [ ] **Step 2:** `EditorBasicTab.swift` — 在基本信息字段区插入该行。读文件找到字段 `VStack`/列表主体,在坐标行附近加一行(传该 tab 已有的 `ref` / `datasetId`):

```swift
            LayerPickerRow(ref: ref, datasetId: datasetId)
```

(若 `EditorBasicTab` 的属性名不是 `ref` / `datasetId`,用其实际持有的等价值;该 tab 由 `EntityEditor(ref:datasetId:...)` 传入,二者必存在。)

- [ ] **Step 3:** Build。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4:** 手动验:选中实体 → 编辑 → 基本 tab 出现「所属图层」下拉;改成别的图层 → 仅启用该层时该实体可见。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Editor/LayerPickerRow.swift PropertyAtlas/PropertyAtlas/Studio/Editor/EditorBasicTab.swift
git commit -m "feat(layer): entity editor 所属图层 picker"
```

---

## Task 9: 图层设置——默认层禁删 + 删层成员退回默认

**Files:** Modify `PropertyAtlas/PropertyAtlas/Studio/Settings/LayerSettingsTab.swift`

- [ ] **Step 1:** `cardHeader(_:)` 里的删除按钮仅非默认层显示。把:

```swift
            Button(role: .destructive) { deleteLayer(l)
            } label: {
                Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
            }.buttonStyle(.plain)
```

改为:

```swift
            if !l.isDefault {
                Button(role: .destructive) { deleteLayer(l)
                } label: {
                    Image(systemName: "trash").font(.system(size: 12)).foregroundStyle(Studio.bad)
                }.buttonStyle(.plain)
            }
```

- [ ] **Step 2:** 替换 `deleteLayer(_:)` 为先把成员退回默认层再硬删:

```swift
    private func deleteLayer(_ l: Layer) {
        guard !l.isDefault else { return }
        if let home = dsLayers.first(where: { $0.isDefault })?.id {
            reassignMembers(from: l.id, to: home)
        }
        modelContext.delete(l)
        try? modelContext.save()
    }

    private func reassignMembers(from old: UUID, to home: UUID) {
        func move<T>(_ type: T.Type) where T: PersistentModel & LayerAssignable {
            let all = (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
            for e in all where e.layerId == old { e.layerId = home }
        }
        move(Compound.self); move(School.self); move(POI.self); move(Area.self)
    }
```

- [ ] **Step 3:** Build。Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4:** 手动验:建图层→把某实体移入→删该图层→实体重新出现在【默认】;【默认】图层无删除按钮。

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/LayerSettingsTab.swift
git commit -m "feat(layer): default layer undeletable + reassign members on layer delete"
```

---

## Task 10: 清库重迁 smoke + 全量回归

**Files:** 无代码改动(验证)

- [ ] **Step 1:** 全量 build + 全量测试。

Run:
```
cd PropertyAtlas && xcodebuild test -project PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | grep -E "Test Suite 'All|passed|failed|error:|BUILD"
```
Expected: 全 passed,`** TEST SUCCEEDED **`。

- [ ] **Step 2:** 清库重迁(单启动)。删 store(参照 `docs/claude/swiftdata-store.md` 路径,或 `/tmp/propertyatlas_paths.txt` 里的 StoreURL),启动 app 一次。验证:
  - 实体数不变(小区/学校/POI 与迁移前一致)
  - 图层列表里默认层名为「默认」
  - 地图显示全部实体(全部归默认层,默认层启用)

- [ ] **Step 3:** 交互回归:
  - 取消所有图层勾选 → 空屏
  - 仅勾【默认】→ 全部回来
  - 长按新建 → 弹层选层 → pin 归该层
  - 编辑器改实体所属图层 → 仅启用该层时可见
  - 删非默认层 → 成员回默认层
  - 【默认】层无删除按钮

- [ ] **Step 4:** SwiftLint(触及文件)。

Run: `cd /Users/fujie/projects/天津买房 && swiftlint lint --quiet 2>&1 | grep -E "Models/Entities|MapRender/LayerEvaluator|DataKit/(Entity|LegacyMigrator|LayerAssignable)|Studio/(Editor/LayerPickerRow|CreateEntitySheet|Settings/LayerSettingsTab)|States/SeedImporter" | head`
Expected: 无输出(新代码无新违规)。

- [ ] **Step 5:** 更新 `CLAUDE.md` 加一条 P 记录(单归属图层模型),commit。

```bash
git add CLAUDE.md
git commit -m "docs: record single-membership layer model (layerId)"
```

---

## Self-Review 结论

- **Spec 覆盖**:数据模型(T1)、引擎重写(T3)、候选/默认层(T6)、迁移+backfill(T5)、编辑器下拉(T8)、长按弹层(T7)、删层禁删/退回(T9)、边界(T3 测试 + T10 验证)—— 全覆盖。
- **类型一致**:`LayerEvaluator.Candidate{id,layerId}`、`ActiveLayer{id,enabled,minZoom,maxZoom}`、`visibleIds(...,defaultLayerId:)`、`membership(...,defaultLayerId:)`、`EntityWriter.createPin(...,layerId:,in:)`、`EntityWriter.setLayer(_:_:in:)`、`EntityReader.layerId(_:in:)`、`LegacyMigrator.backfillLayerIds(in:)` 跨任务一致。
- **占位符**:无。每步含完整代码 / 命令 / 预期。
- **可编译性**:T4/T6 用临时 `layerId: nil` 桥接,T7 才替换 dialog——每步均保持可 build。
```
