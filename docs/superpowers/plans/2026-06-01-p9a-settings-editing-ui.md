# P9a Settings 编辑 UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Checkbox (`- [ ]`) steps.

**Goal:** 给视图驱动模型加一个 Studio 内的 Settings 编辑 UI:可视化创建/编辑 `MapView`(含 PrimaryFilter groupBy + 条件 + NormalFilter)、`Layer`(含 zIndex/themeId)、`Palette`、`EnumOption` —— 让直播工具无需改代码即可配置染色/过滤/图层/视图。

**Architecture (本期定稿):**
- **纯 additive UI**:不改任何 @Model schema(所有模型 P1/P8 已就位),不删旧。无破坏性清库 smoke。
- **入口**:Studio 工具栏加 ⚙️ 按钮 → `SettingsSheet`(tab 容器),sheet 形式,复用 EntityEditor 的呈现习惯(@Environment(\.modelContext) 直接 mutate + SwiftData 自动保存,设 `updatedAt`)。
- **可测纯逻辑抽出**:`ViewConfigCodec`(MapView 的 primaryFilterJSON/normalFiltersJSON ⇄ `PrimaryFilter`/`[NormalFilter]` 读写)、`FieldKeyCatalog`(实体类型可用字段 = EntityFieldSchema base + CustomFieldDef custom;edge.label 来自 EnumOption)、`HexColor` 解析(已存在)。这些有单测;SwiftUI View 靠编译 + 这些单测验证。
- **逐图层 theme**:Layer 编辑器暴露 `themeId`/`zIndex`;渲染仍用 P8b 的务实单 active theme(启用图层 zIndex 最高且有 themeId 者)。真正的逐实体-逐图层 theme 解析仍延后。
- **持久化**:配置模型直接 `context.insert(...)` 新建 / mutate 字段 + `updatedAt = Date()`;软删置 `deleted = true`。无显式 `save()`(SwiftData 自动保存,沿用现状)。

**Tech Stack:** SwiftUI(Mac Catalyst)· SwiftData · Swift Testing · 复用 `MapViewContext`/`MapDimension`/`PrimaryFilter`/`NormalFilter`/`FilterCondition`/`EntityFieldSchema`/`JSONHelpers`/`HexColor`/`EnumOption`。

**前置**: P8b 已合(MapViewContext/视图驱动 RootView)。所有配置 @Model 已存在。

**关键现状(已核实):**
- `StudioToolbar(viewContext: MapViewContext, aspect: Binding<CanvasAspect>, onSnapshot:)` —— View 选择器 Menu 在此。`StudioOverlay(...,viewContext:)` host 它。`StudioRootView` body 持有 `viewContext: MapViewContext?` 等 @State。
- `MapViewContext`: `.activeMapView`、`.allMapViews`、`.switchView(to:)`、`.datasetIdValue`。
- `MapView` 字段:id/datasetId/name/enabledLayerIds:[UUID]/primaryFilterJSON/normalFiltersJSON/visibilityJSON/paletteId:UUID?/cameraPresetId:UUID?/bgMapStyle/drawEdgeLines:[String]/copyTitle?/copySubtitle?/copyWatermark?/spotlightOnSelect/sortOrder/isActive/…;`init(id:datasetId:name:)`。
- `Layer` 字段:id/datasetId/name/iconSF?/colorHex?/staticRefsJSON?/dynamicQueryJSON?/minZoom?/maxZoom?/isDefault/enabled/sortOrder/zIndex:Int/themeId:UUID?;`init(id:datasetId:name:)`。
- `Theme` 字段(P8b 后):id/datasetId/name/isActive/styleRuleIds/defaultStylesJSON/showLegend/sortOrder/…;`init(id:datasetId:name:)`。
- `Palette` 字段:id/name/colorsHex:[String]/builtIn/sortOrder;`init(id:name:colorsHex:builtIn:)`。
- `EnumOption` 字段:id/datasetId/scope:String/label:String/sortOrder/colorHex:String?;`init(id:datasetId:scope:label:sortOrder:colorHex:)`。`scope` 形如 `"edge.label"`、`"school.category"`、`"compound.finishType"`。
- `CameraPreset` 字段:id/datasetId/name/centerLat/centerLon/distance/pitch/heading/sortOrder;`init(id:datasetId:name:centerLat:centerLon:distance:pitch:heading:)`。
- `MapDimension{kind:DimensionKind, fieldKey?, fieldSource?, edgeLabel?, edgeDirection?, edgeTargetField?; var key; init(kind:fieldKey:fieldSource:edgeLabel:edgeDirection:edgeTargetField:)}`;`DimensionKind: String, Codable, CaseIterable { layer, entityType, field, edgeField }`。
- `PrimaryFilter{conditions:[FilterCondition], groupBy:MapDimension?}`(Codable);`NormalFilter{id:UUID,name:String,dimension:MapDimension; init(id:name:dimension:)}`;`FilterCondition{dimension:MapDimension, op:StyleConditionOp, value:AnyJSON}`。
- `StyleConditionOp: String, Codable { equals, notEquals, inOp="in", contains, gte, lte, exists }`(在 `MapRender/ConditionEvaluator.swift`)。
- `EntityFieldSchema.fields(for: EntityKind) -> [FieldDescriptor]`;`struct FieldDescriptor{key:String,label:String,kind:FieldKind,enumScope:String?}`;`enum FieldKind{string,int,bool,enumRef}`。`EntityKind` 原值 compound/school/poi/area。
- `CustomFieldDef{datasetId,entityType,key,label,type,...}`。
- `JSONHelpers.encode(_ value: some Encodable) throws -> String`;`JSONHelpers.decode<T: Decodable>(_ string: String) throws -> T`。
- `HexColor.parse(_:) -> UIColor?`(已用于 LegendView)。`AnyJSON{string/int/double/bool/array/object/null}`。
- `EnumOption` 查询样式:`FetchDescriptor<EnumOption>(predicate: #Predicate { $0.datasetId == dsId && $0.scope == s && !$0.deleted }, sortBy: [SortDescriptor(\.sortOrder)])`。

**新增文件:** `Studio/Settings/SettingsSheet.swift`、`Studio/Settings/ViewSettingsTab.swift`、`Studio/Settings/LayerSettingsTab.swift`、`Studio/Settings/PaletteSettingsTab.swift`、`Studio/Settings/EnumOptionSettingsTab.swift`、`Studio/Settings/Components/{ColorHexField,DimensionPicker,FilterConditionRow,AnyJSONValueField,PrimaryFilterEditor}.swift`、`DataKit/ViewConfigCodec.swift`、`DataKit/FieldKeyCatalog.swift` + 测试。
**改:** `Studio/StudioToolbar.swift`、`Studio/StudioOverlay.swift`、`RootView.swift`(入口 + sheet)、`CLAUDE.md`。

> 所有 `xcodebuild` 从 worktree `PropertyAtlas` 子目录运行。Swift Testing(非 XCTest)。提交 `git -c commit.gpgsign=false commit -am`。SourceKit "No such module 'Testing'"/"Cannot find type" 是陈旧索引噪声,以 `xcodebuild` 为准。SwiftUI View 无单测 → 靠 `xcodebuild build` SUCCEEDED 验证。

---

### Task 0: Settings 入口 + 空壳 SettingsSheet

**Files:** Create `PropertyAtlas/PropertyAtlas/Studio/Settings/SettingsSheet.swift`; Modify `Studio/StudioToolbar.swift`、`Studio/StudioOverlay.swift`、`RootView.swift`

- [ ] **Step 1: 实现空壳 SettingsSheet.swift**
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

enum SettingsTab: String, CaseIterable, Identifiable {
    case view = "视图", layer = "图层", palette = "调色板", enumOption = "枚举"
    var id: String { rawValue }
}

struct SettingsSheet: View {
    @Bindable var viewContext: MapViewContext
    let onClose: () -> Void
    @State private var tab: SettingsTab = .view

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置").font(.headline)
                Spacer()
                Button("完成", action: onClose).keyboardShortcut(.defaultAction)
            }
            .padding(12)
            Picker("", selection: $tab) {
                ForEach(SettingsTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            Divider().padding(.top, 8)
            ScrollView {
                Group {
                    switch tab {
                    case .view: ViewSettingsTab(viewContext: viewContext)
                    case .layer: LayerSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .palette: PaletteSettingsTab()
                    case .enumOption: EnumOptionSettingsTab(datasetId: viewContext.datasetIdValue)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 460, height: 820)
    }
}
#endif
```
> T0 只建壳;4 个 tab View 在后续任务实现。为让 T0 编译,本步先给每个 tab 一个**占位**实现(放在各自文件,后续任务替换):
- `ViewSettingsTab.swift`: `struct ViewSettingsTab: View { @Bindable var viewContext: MapViewContext; var body: some View { Text("视图设置") } }`(注:`#if targetEnvironment(macCatalyst)` 包裹)
- `LayerSettingsTab.swift`: `struct LayerSettingsTab: View { let datasetId: UUID; var body: some View { Text("图层设置") } }`
- `PaletteSettingsTab.swift`: `struct PaletteSettingsTab: View { var body: some View { Text("调色板") } }`
- `EnumOptionSettingsTab.swift`: `struct EnumOptionSettingsTab: View { let datasetId: UUID; var body: some View { Text("枚举") } }`
每个文件 `#if targetEnvironment(macCatalyst) import SwiftUI / import SwiftData ... #endif`。

- [ ] **Step 2: 入口接线**
`StudioToolbar.swift` 加参数 `var showSettings: Binding<Bool>`,在 aspect Menu 后、Divider 前加:
```swift
Button { showSettings.wrappedValue = true } label: { Text("⚙️ 设置") }
```
`StudioOverlay.swift` 加 `@Binding var showSettings: Bool`,传给 `StudioToolbar(viewContext:aspect:onSnapshot:showSettings:)`(把 `showSettings: $showSettings` 传入)。
`RootView.swift` `StudioRootView`:加 `@State private var showSettings = false`;`StudioOverlay(...)` 调用处加 `showSettings: $showSettings`;在 ZStack 上(`StudioOverlay` 块附近)加:
```swift
.sheet(isPresented: $showSettings) {
    if let ctx = viewContext {
        SettingsSheet(viewContext: ctx, onClose: { showSettings = false })
    }
}
```

- [ ] **Step 3: 编译**
Run: `cd <worktree>/PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -20`
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): Settings sheet shell + toolbar entry (placeholder tabs)"`

---

### Task 1: ViewConfigCodec(MapView filter JSON ⇄ 值类型)

**Files:** Create `PropertyAtlas/PropertyAtlas/DataKit/ViewConfigCodec.swift`; Test `PropertyAtlasTests/DataKit/ViewConfigCodecTests.swift`

纯逻辑:从 MapView 读出 `PrimaryFilter`/`[NormalFilter]`,改后写回 JSON。供 View 编辑器用。

- [ ] **Step 1: 失败测试**
```swift
import Testing
import Foundation
@testable import PropertyAtlas

struct ViewConfigCodecTests {
    @Test func primaryRoundTrips() {
        let dim = MapDimension(kind: .field, fieldKey: "grade", fieldSource: "base")
        let pf = PrimaryFilter(conditions: [], groupBy: dim)
        let json = ViewConfigCodec.encodePrimary(pf)
        let back = ViewConfigCodec.decodePrimary(json)
        #expect(back.groupBy?.fieldKey == "grade")
    }

    @Test func decodeBadPrimaryYieldsEmpty() {
        let pf = ViewConfigCodec.decodePrimary("not json")
        #expect(pf.conditions.isEmpty)
        #expect(pf.groupBy == nil)
    }

    @Test func normalsRoundTrip() {
        let nf = NormalFilter(name: "学段", dimension: MapDimension(kind: .field, fieldKey: "category", fieldSource: "base"))
        let json = ViewConfigCodec.encodeNormals([nf])
        let back = ViewConfigCodec.decodeNormals(json)
        #expect(back.count == 1)
        #expect(back.first?.name == "学段")
    }

    @Test func decodeBadNormalsYieldsEmpty() {
        #expect(ViewConfigCodec.decodeNormals("garbage").isEmpty)
    }
}
```

- [ ] **Step 2: 跑确认失败**
`cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests/ViewConfigCodecTests 2>&1 | tail -25`

- [ ] **Step 3: 实现**
```swift
import Foundation

/// MapView 的 primaryFilterJSON / normalFiltersJSON ⇄ 值类型。解码失败回退空值(UI 永不崩)。
enum ViewConfigCodec {
    static func decodePrimary(_ json: String) -> PrimaryFilter {
        (try? JSONHelpers.decode(json) as PrimaryFilter) ?? PrimaryFilter(conditions: [], groupBy: nil)
    }
    static func encodePrimary(_ pf: PrimaryFilter) -> String {
        (try? JSONHelpers.encode(pf)) ?? #"{"conditions":[],"groupBy":null}"#
    }
    static func decodeNormals(_ json: String) -> [NormalFilter] {
        (try? JSONHelpers.decode(json) as [NormalFilter]) ?? []
    }
    static func encodeNormals(_ nfs: [NormalFilter]) -> String {
        (try? JSONHelpers.encode(nfs)) ?? "[]"
    }
}
```
> 若 `JSONHelpers.decode` 的泛型调用形式不同(如需 `JSONHelpers.decode(json, as: PrimaryFilter.self)`),按真实签名适配。

- [ ] **Step 4: 跑确认通过**(4 测试)
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): ViewConfigCodec (MapView filter JSON ⇄ values)"`

---

### Task 2: FieldKeyCatalog(可选字段 / 枚举值 / edge 标签 来源)

**Files:** Create `PropertyAtlas/PropertyAtlas/DataKit/FieldKeyCatalog.swift`; Test `PropertyAtlasTests/DataKit/FieldKeyCatalogTests.swift`

供 DimensionPicker:列某实体类型可选字段(base + custom)、列某 scope 的 EnumOption 值、列 edge 标签。

- [ ] **Step 1: 失败测试**
```swift
import Testing
import Foundation
import SwiftData
@testable import PropertyAtlas

@MainActor
struct FieldKeyCatalogTests {
    @Test func baseFieldsForSchool() {
        let fields = FieldKeyCatalog.fields(entityType: "school", datasetId: UUID(), context: nil)
        #expect(fields.contains { $0.key == "category" })   // School 有 category
    }

    @Test func enumValuesByScope() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let dsId = UUID()
        let o = EnumOption(datasetId: dsId, scope: "edge.label", label: "所属片区")
        ctx.insert(o); try ctx.save()
        let labels = FieldKeyCatalog.enumLabels(scope: "edge.label", datasetId: dsId, context: ctx)
        #expect(labels.contains("所属片区"))
    }

    @Test func unknownEntityTypeYieldsEmptyBase() {
        let fields = FieldKeyCatalog.fields(entityType: "bogus", datasetId: UUID(), context: nil)
        #expect(fields.isEmpty)
    }
}
```

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**(适配 `EntityFieldSchema.fields(for:)` / `FieldDescriptor` / `EntityKind` 真实形)
```swift
import Foundation
import SwiftData

/// 维度编辑器的数据源:可选字段(base+custom)、枚举值、edge 标签。
@MainActor
enum FieldKeyCatalog {
    struct FieldItem: Hashable {
        let key: String
        let label: String
        let source: String   // "base" | "custom"
        let enumScope: String?
    }

    static func fields(entityType: String, datasetId: UUID, context: ModelContext?) -> [FieldItem] {
        guard let kind = EntityKind(rawValue: entityType) else { return [] }
        var out: [FieldItem] = EntityFieldSchema.fields(for: kind).map {
            FieldItem(key: $0.key, label: $0.label, source: "base", enumScope: $0.enumScope)
        }
        if let ctx = context {
            let fd = FetchDescriptor<CustomFieldDef>(
                predicate: #Predicate { $0.datasetId == datasetId && $0.entityType == entityType && !$0.deleted },
                sortBy: [SortDescriptor(\.sortOrder)]
            )
            for c in (try? ctx.fetch(fd)) ?? [] {
                out.append(FieldItem(key: c.key, label: c.label, source: "custom", enumScope: "\(entityType).\(c.key)"))
            }
        }
        return out
    }

    static func enumLabels(scope: String, datasetId: UUID, context: ModelContext?) -> [String] {
        guard let ctx = context else { return [] }
        let fd = FetchDescriptor<EnumOption>(
            predicate: #Predicate { $0.datasetId == datasetId && $0.scope == scope && !$0.deleted },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return ((try? ctx.fetch(fd)) ?? []).map(\.label)
    }

    static func edgeLabels(datasetId: UUID, context: ModelContext?) -> [String] {
        enumLabels(scope: "edge.label", datasetId: datasetId, context: context)
    }
}
```

- [ ] **Step 4: 跑确认通过**(3 测试)
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): FieldKeyCatalog (fields/enum/edge sources for dimension picker)"`

---

### Task 3: ColorHexField + AnyJSONValueField(可复用输入件)

**Files:** Create `PropertyAtlas/PropertyAtlas/Studio/Settings/Components/ColorHexField.swift`、`.../AnyJSONValueField.swift`; Test `PropertyAtlasTests/Studio/ColorHexFieldLogicTests.swift`(只测纯逻辑 normalize)

- [ ] **Step 1: 失败测试**(把可测的纯逻辑放静态函数)
```swift
import Testing
@testable import PropertyAtlas

struct ColorHexFieldLogicTests {
    @Test func normalizesHash() {
        #expect(ColorHexField.normalize("E41A1C") == "#E41A1C")
        #expect(ColorHexField.normalize("#abc123") == "#ABC123")
        #expect(ColorHexField.normalize("  #fff ") == "#FFF")
    }
}
```

- [ ] **Step 2: 跑确认失败**

- [ ] **Step 3: 实现**
`ColorHexField.swift`:
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct ColorHexField: View {
    let title: String
    @Binding var hex: String   // 可空用 "" 表示无

    static func normalize(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespaces).uppercased()
        if t.isEmpty { return "" }
        if !t.hasPrefix("#") { t = "#" + t }
        return t
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title).frame(width: 84, alignment: .leading).font(.system(size: 12))
            Circle().fill(Color(uiColor: HexColor.parse(hex) ?? .clear))
                .frame(width: 16, height: 16).overlay(Circle().stroke(.secondary.opacity(0.3)))
            TextField("#RRGGBB", text: $hex)
                .font(.system(size: 12).monospaced())
                .onSubmit { hex = Self.normalize(hex) }
        }
    }
}
#endif
```
`AnyJSONValueField.swift`(把 `AnyJSON` 标量绑定到一个文本/开关;复杂类型回退文本):
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 把 AnyJSON 标量编辑为字符串。inOp 等多值场景由调用方用逗号分隔串处理。
struct AnyJSONValueField: View {
    @Binding var value: AnyJSON

    private var text: Binding<String> {
        Binding(
            get: { ValueFormat.display(value) },
            set: { value = .string($0) }   // 默认按字符串存;数字比较 op 仍可用(evaluate 内做数值解析)
        )
    }

    var body: some View {
        TextField("值", text: text).font(.system(size: 12))
    }
}
#endif
```
> `ValueFormat.display` 已存在(P8b)。若需要布尔/数字专门控件,本期先统一字符串(`FilterCondition.evaluate` 的 gte/lte 已按数值解析)。

- [ ] **Step 4: 跑确认通过** + 编译整 app(`xcodebuild build ... | tail -10`)。
- [ ] **Step 5: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): ColorHexField + AnyJSONValueField components"`

---

### Task 4: DimensionPicker(维度编辑器)

**Files:** Create `PropertyAtlas/PropertyAtlas/Studio/Settings/Components/DimensionPicker.swift`

把 `MapDimension` 绑定编辑:kind 选择 + 按 kind 显示字段/edge 参数。无纯逻辑测试(全 UI)→ 编译验证。

- [ ] **Step 1: 实现**
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct DimensionPicker: View {
    @Binding var dimension: MapDimension
    let entityType: String          // 当前编辑上下文的实体类型(取字段候选);可传 "school" 等
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("维度", selection: kindBinding) {
                ForEach(DimensionKind.allCases, id: \.self) { Text(label(for: $0)).tag($0) }
            }.font(.system(size: 12))

            switch dimension.kind {
            case .field:
                Picker("字段", selection: fieldKeyBinding) {
                    Text("—").tag("")
                    ForEach(fieldItems, id: \.key) { Text($0.label).tag($0.key) }
                }.font(.system(size: 12))
            case .edgeField:
                Picker("关系", selection: edgeLabelBinding) {
                    Text("—").tag("")
                    ForEach(edgeLabels, id: \.self) { Text($0).tag($0) }
                }.font(.system(size: 12))
                Picker("方向", selection: edgeDirBinding) {
                    Text("下游").tag("downstream"); Text("上游").tag("upstream"); Text("双向").tag("either")
                }.font(.system(size: 12))
                TextField("对端字段(空=名称)", text: edgeTargetBinding).font(.system(size: 12))
            case .layer, .entityType:
                EmptyView()
            }
        }
    }

    private var fieldItems: [FieldKeyCatalog.FieldItem] {
        FieldKeyCatalog.fields(entityType: entityType, datasetId: datasetId, context: modelContext)
    }
    private var edgeLabels: [String] {
        FieldKeyCatalog.edgeLabels(datasetId: datasetId, context: modelContext)
    }

    private func label(for k: DimensionKind) -> String {
        switch k { case .field: "字段"; case .edgeField: "关系字段"; case .layer: "图层"; case .entityType: "实体类型" }
    }

    private var kindBinding: Binding<DimensionKind> {
        Binding(get: { dimension.kind }, set: { dimension = MapDimension(kind: $0) })
    }
    private var fieldKeyBinding: Binding<String> {
        Binding(get: { dimension.fieldKey ?? "" }, set: {
            let src = fieldItems.first { i in i.key == $0 }?.source ?? "base"
            dimension = MapDimension(kind: .field, fieldKey: $0.isEmpty ? nil : $0, fieldSource: src)
        })
    }
    private var edgeLabelBinding: Binding<String> {
        Binding(get: { dimension.edgeLabel ?? "" }, set: {
            dimension = MapDimension(kind: .edgeField, edgeLabel: $0.isEmpty ? nil : $0,
                                     edgeDirection: dimension.edgeDirection ?? "downstream",
                                     edgeTargetField: dimension.edgeTargetField)
        })
    }
    private var edgeDirBinding: Binding<String> {
        Binding(get: { dimension.edgeDirection ?? "downstream" }, set: {
            dimension = MapDimension(kind: .edgeField, edgeLabel: dimension.edgeLabel,
                                     edgeDirection: $0, edgeTargetField: dimension.edgeTargetField)
        })
    }
    private var edgeTargetBinding: Binding<String> {
        Binding(get: { dimension.edgeTargetField ?? "" }, set: {
            dimension = MapDimension(kind: .edgeField, edgeLabel: dimension.edgeLabel,
                                     edgeDirection: dimension.edgeDirection ?? "downstream",
                                     edgeTargetField: $0.isEmpty ? nil : $0)
        })
    }
}
#endif
```

- [ ] **Step 2: 编译**(`xcodebuild build ... | tail -15`)→ BUILD SUCCEEDED。
- [ ] **Step 3: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): DimensionPicker (kind + field/edge params)"`

---

### Task 5: FilterConditionRow + PrimaryFilterEditor

**Files:** Create `.../Components/FilterConditionRow.swift`、`.../Components/PrimaryFilterEditor.swift`

- [ ] **Step 1: 实现 FilterConditionRow.swift**
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct FilterConditionRow: View {
    @Binding var condition: FilterCondition
    let entityType: String
    let datasetId: UUID
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("条件").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash").font(.system(size: 11)) }
                    .buttonStyle(.plain)
            }
            DimensionPicker(dimension: dimBinding, entityType: entityType, datasetId: datasetId)
            Picker("运算", selection: opBinding) {
                ForEach(ops, id: \.self) { Text($0.rawValue).tag($0) }
            }.font(.system(size: 12))
            if condition.op != .exists {
                AnyJSONValueField(value: valueBinding)
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private let ops: [StyleConditionOp] = [.equals, .notEquals, .inOp, .contains, .gte, .lte, .exists]
    private var dimBinding: Binding<MapDimension> {
        Binding(get: { condition.dimension }, set: { condition = FilterCondition(dimension: $0, op: condition.op, value: condition.value) })
    }
    private var opBinding: Binding<StyleConditionOp> {
        Binding(get: { condition.op }, set: { condition = FilterCondition(dimension: condition.dimension, op: $0, value: condition.value) })
    }
    private var valueBinding: Binding<AnyJSON> {
        Binding(get: { condition.value }, set: { condition = FilterCondition(dimension: condition.dimension, op: condition.op, value: $0) })
    }
}
#endif
```
> 若 `FilterCondition` 无 memberwise init(它是 struct,默认有),用 `FilterCondition(dimension:op:value:)`。`StyleConditionOp` 需 `Hashable`(String raw enum 自动满足)。

- [ ] **Step 2: 实现 PrimaryFilterEditor.swift**
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 编辑一个 PrimaryFilter(条件 AND 列表 + 可选 groupBy)。绑定到调用方的 @State PrimaryFilter。
struct PrimaryFilterEditor: View {
    @Binding var filter: PrimaryFilter
    let entityType: String
    let datasetId: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("主过滤(分组 + 条件)").font(.system(size: 12, weight: .bold))

            Toggle("启用分组染色 (groupBy)", isOn: groupByEnabled).font(.system(size: 12))
            if filter.groupBy != nil {
                DimensionPicker(dimension: groupByBinding, entityType: entityType, datasetId: datasetId)
                    .padding(.leading, 8)
            }

            Divider().opacity(0.4)
            Text("条件 (AND)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(filter.conditions.indices, id: \.self) { i in
                FilterConditionRow(condition: conditionBinding(i), entityType: entityType, datasetId: datasetId,
                                   onDelete: { filter.conditions.remove(at: i) })
            }
            Button { filter.conditions.append(FilterCondition(dimension: MapDimension(kind: .field), op: .equals, value: .string(""))) }
                label: { Label("加条件", systemImage: "plus") }.font(.system(size: 12))
        }
    }

    private var groupByEnabled: Binding<Bool> {
        Binding(get: { filter.groupBy != nil },
                set: { filter.groupBy = $0 ? MapDimension(kind: .field) : nil })
    }
    private var groupByBinding: Binding<MapDimension> {
        Binding(get: { filter.groupBy ?? MapDimension(kind: .field) }, set: { filter.groupBy = $0 })
    }
    private func conditionBinding(_ i: Int) -> Binding<FilterCondition> {
        Binding(get: { filter.conditions[i] }, set: { filter.conditions[i] = $0 })
    }
}
#endif
```

- [ ] **Step 3: 编译** → BUILD SUCCEEDED。
- [ ] **Step 4: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): FilterConditionRow + PrimaryFilterEditor"`

---

### Task 6: ViewSettingsTab(视图编辑器 —— 核心)

**Files:** Modify `PropertyAtlas/PropertyAtlas/Studio/Settings/ViewSettingsTab.swift`(替换 T0 占位)

编辑 active MapView 全部可视字段 + PrimaryFilter(用 PrimaryFilterEditor)+ NormalFilters。新建/切换/删除视图。

- [ ] **Step 1: 实现**(替换占位)
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct ViewSettingsTab: View {
    @Bindable var viewContext: MapViewContext
    @Environment(\.modelContext) private var modelContext
    @Query private var palettes: [Palette]
    @Query private var cameraPresets: [CameraPreset]
    @Query private var layers: [Layer]

    @State private var primary = PrimaryFilter(conditions: [], groupBy: nil)
    @State private var normals: [NormalFilter] = []

    private let primaryEntityType = "school"   // 字段候选上下文;维度按字段名跨类型取值,不限制实际匹配

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("视图", selection: activeBinding) {
                    ForEach(viewContext.allMapViews, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                }.font(.system(size: 12))
                Button { addView() } label: { Image(systemName: "plus") }
                if let mv = viewContext.activeMapView, viewContext.allMapViews.count > 1 {
                    Button(role: .destructive) { deleteView(mv) } label: { Image(systemName: "trash") }
                }
            }

            if let mv = viewContext.activeMapView {
                row("名称") { TextField("名称", text: nameBinding(mv)) }
                Text("可见类型").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                visibilityToggles(mv)
                Text("启用图层").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                ForEach(layers.filter { $0.datasetId == mv.datasetId && !$0.deleted }, id: \.id) { layer in
                    Toggle(layer.name, isOn: layerBinding(mv, layer.id)).font(.system(size: 12))
                }
                Picker("调色板", selection: paletteBinding(mv)) {
                    Text("默认高对比").tag(UUID?.none)
                    ForEach(palettes.filter { !$0.deleted }, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                }.font(.system(size: 12))
                Picker("相机", selection: cameraBinding(mv)) {
                    Text("无").tag(UUID?.none)
                    ForEach(cameraPresets.filter { $0.datasetId == mv.datasetId && !$0.deleted }, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                }.font(.system(size: 12))
                Toggle("选中聚光", isOn: spotlightBinding(mv)).font(.system(size: 12))
                row("标题") { TextField("标题", text: optBinding(\.copyTitle, mv)) }
                row("副标题") { TextField("副标题", text: optBinding(\.copySubtitle, mv)) }
                row("水印") { TextField("水印", text: optBinding(\.copyWatermark, mv)) }

                Divider().opacity(0.4)
                PrimaryFilterEditor(filter: $primary, entityType: primaryEntityType, datasetId: mv.datasetId)
                    .onChange(of: primary) { _, new in mv.primaryFilterJSON = ViewConfigCodec.encodePrimary(new); mv.updatedAt = Date() }

                Divider().opacity(0.4)
                normalFiltersSection(mv)
            } else {
                Text("无视图").foregroundStyle(.secondary)
            }
        }
        .onAppear { loadFilters() }
        .onChange(of: viewContext.activeMapView?.id) { _, _ in loadFilters() }
    }

    private func loadFilters() {
        guard let mv = viewContext.activeMapView else { return }
        primary = ViewConfigCodec.decodePrimary(mv.primaryFilterJSON)
        normals = ViewConfigCodec.decodeNormals(mv.normalFiltersJSON)
    }

    private func normalFiltersSection(_ mv: MapView) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("普通过滤(图例 + 计数)").font(.system(size: 12, weight: .bold))
            ForEach(normals.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("名称", text: Binding(get: { normals[i].name }, set: { normals[i].name = $0; saveNormals(mv) }))
                            .font(.system(size: 12))
                        Button(role: .destructive) { normals.remove(at: i); saveNormals(mv) } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
                    }
                    DimensionPicker(dimension: Binding(get: { normals[i].dimension }, set: { normals[i].dimension = $0; saveNormals(mv) }),
                                    entityType: primaryEntityType, datasetId: mv.datasetId)
                }
                .padding(8).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
            Button { normals.append(NormalFilter(name: "新过滤", dimension: MapDimension(kind: .field))); saveNormals(mv) }
                label: { Label("加普通过滤", systemImage: "plus") }.font(.system(size: 12))
        }
    }
    private func saveNormals(_ mv: MapView) { mv.normalFiltersJSON = ViewConfigCodec.encodeNormals(normals); mv.updatedAt = Date() }

    private func row<V: View>(_ label: String, @ViewBuilder _ content: () -> V) -> some View {
        HStack { Text(label).frame(width: 64, alignment: .leading).font(.system(size: 12)); content() }
    }
    private var activeBinding: Binding<UUID?> {
        Binding(get: { viewContext.activeMapView?.id }, set: { id in
            if let v = viewContext.allMapViews.first(where: { $0.id == id }) { viewContext.switchView(to: v) }
        })
    }
    private func nameBinding(_ mv: MapView) -> Binding<String> {
        Binding(get: { mv.name }, set: { mv.name = $0; mv.updatedAt = Date() })
    }
    private func optBinding(_ kp: ReferenceWritableKeyPath<MapView, String?>, _ mv: MapView) -> Binding<String> {
        Binding(get: { mv[keyPath: kp] ?? "" }, set: { mv[keyPath: kp] = $0.isEmpty ? nil : $0; mv.updatedAt = Date() })
    }
    private func spotlightBinding(_ mv: MapView) -> Binding<Bool> {
        Binding(get: { mv.spotlightOnSelect }, set: { mv.spotlightOnSelect = $0; mv.updatedAt = Date() })
    }
    private func paletteBinding(_ mv: MapView) -> Binding<UUID?> {
        Binding(get: { mv.paletteId }, set: { mv.paletteId = $0; mv.updatedAt = Date() })
    }
    private func cameraBinding(_ mv: MapView) -> Binding<UUID?> {
        Binding(get: { mv.cameraPresetId }, set: { mv.cameraPresetId = $0; mv.updatedAt = Date() })
    }
    private func layerBinding(_ mv: MapView, _ id: UUID) -> Binding<Bool> {
        Binding(get: { mv.enabledLayerIds.contains(id) }, set: { on in
            var s = Set(mv.enabledLayerIds); if on { s.insert(id) } else { s.remove(id) }
            mv.enabledLayerIds = Array(s); mv.updatedAt = Date()
        })
    }
    private func visibilityToggles(_ mv: MapView) -> some View {
        let types = [("compound","小区"),("school","学校"),("poi","POI"),("area","片区")]
        return ForEach(types, id: \.0) { t in
            Toggle(t.1, isOn: Binding(
                get: { (decodeVis(mv)[t.0] ?? true) },
                set: { on in var d = decodeVis(mv); d[t.0] = on; mv.visibilityJSON = encodeVis(d); mv.updatedAt = Date() }
            )).font(.system(size: 12))
        }
    }
    private func decodeVis(_ mv: MapView) -> [String: Bool] {
        (try? JSONSerialization.jsonObject(with: Data(mv.visibilityJSON.utf8)) as? [String: Bool]) ?? ["compound":true,"school":true,"poi":true,"area":true]
    }
    private func encodeVis(_ d: [String: Bool]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: d), let s = String(data: data, encoding: .utf8) else { return mvDefaultVis }
        return s
    }
    private let mvDefaultVis = #"{"compound":true,"school":true,"poi":true,"area":true}"#

    private func addView() {
        let v = MapView(datasetId: viewContext.datasetIdValue, name: "新视图")
        v.sortOrder = (viewContext.allMapViews.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(v)
        viewContext.switchView(to: v)
    }
    private func deleteView(_ mv: MapView) {
        mv.deleted = true; mv.updatedAt = Date()
        if let other = viewContext.allMapViews.first(where: { $0.id != mv.id }) { viewContext.switchView(to: other) }
    }
}
#endif
```
> `ReferenceWritableKeyPath` 用于 @Model(class)的可选 String 字段;若编译器对 keyPath 推断不顺,改为三个显式 binding 方法。`primaryEntityType` 固定 "school" 仅用于字段候选下拉,不限制实际过滤。

- [ ] **Step 2: 编译** → BUILD SUCCEEDED。
- [ ] **Step 3: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): ViewSettingsTab (MapView fields + PrimaryFilter + NormalFilters editor)"`

---

### Task 7: LayerSettingsTab(图层编辑器,含 zIndex/themeId)

**Files:** Modify `Studio/Settings/LayerSettingsTab.swift`(替换占位)

- [ ] **Step 1: 实现**
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct LayerSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var layers: [Layer]
    @Query private var themes: [Theme]

    private var dsLayers: [Layer] {
        layers.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.zIndex < $1.zIndex }
    }
    private var dsThemes: [Theme] { themes.filter { $0.datasetId == datasetId && !$0.deleted } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("图层").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addLayer() } label: { Label("新图层", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(dsLayers, id: \.id) { layer in layerCard(layer) }
        }
    }

    private func layerCard(_ l: Layer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { l.name }, set: { l.name = $0; l.updatedAt = Date() })).font(.system(size: 12, weight: .semibold))
                Button(role: .destructive) { l.deleted = true; l.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
            }
            HStack {
                Text("zIndex").font(.system(size: 11)).foregroundStyle(.secondary)
                Stepper(value: Binding(get: { l.zIndex }, set: { l.zIndex = $0; l.updatedAt = Date() }), in: 0...999) { Text("\(l.zIndex)").font(.system(size: 12).monospacedDigit()) }
            }
            Picker("主题", selection: Binding(get: { l.themeId }, set: { l.themeId = $0; l.updatedAt = Date() })) {
                Text("无").tag(UUID?.none)
                ForEach(dsThemes, id: \.id) { Text($0.name).tag($0.id as UUID?) }
            }.font(.system(size: 12))
            ColorHexField(title: "图例色", hex: Binding(get: { l.colorHex ?? "" }, set: { l.colorHex = $0.isEmpty ? nil : ColorHexField.normalize($0); l.updatedAt = Date() }))
            HStack {
                Text("SF 图标").frame(width: 84, alignment: .leading).font(.system(size: 12))
                TextField("如 building.2", text: Binding(get: { l.iconSF ?? "" }, set: { l.iconSF = $0.isEmpty ? nil : $0; l.updatedAt = Date() })).font(.system(size: 12))
            }
            HStack {
                Toggle("启用", isOn: Binding(get: { l.enabled }, set: { l.enabled = $0; l.updatedAt = Date() })).font(.system(size: 12))
                Toggle("默认开", isOn: Binding(get: { l.isDefault }, set: { l.isDefault = $0; l.updatedAt = Date() })).font(.system(size: 12))
            }
            HStack {
                zoomField("minZoom", get: { l.minZoom }, set: { l.minZoom = $0; l.updatedAt = Date() })
                zoomField("maxZoom", get: { l.maxZoom }, set: { l.maxZoom = $0; l.updatedAt = Date() })
            }
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func zoomField(_ title: String, get: @escaping () -> Double?, set: @escaping (Double?) -> Void) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
            TextField("—", text: Binding(get: { get().map { String(Int($0)) } ?? "" }, set: { set($0.isEmpty ? nil : Double($0)) }))
                .font(.system(size: 12).monospaced()).frame(width: 44)
        }
    }

    private func addLayer() {
        let l = Layer(datasetId: datasetId, name: "新图层")
        l.zIndex = (dsLayers.map(\.zIndex).max() ?? 0) + 1
        l.sortOrder = l.zIndex
        modelContext.insert(l)
    }
}
#endif
```

- [ ] **Step 2: 编译** → BUILD SUCCEEDED。
- [ ] **Step 3: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): LayerSettingsTab (zIndex/themeId/color/zoom CRUD)"`

---

### Task 8: PaletteSettingsTab(调色板编辑器)

**Files:** Modify `Studio/Settings/PaletteSettingsTab.swift`(替换占位)

- [ ] **Step 1: 实现**
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct PaletteSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var palettes: [Palette]

    private var live: [Palette] { palettes.filter { !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("调色板").font(.system(size: 12, weight: .bold))
                Spacer()
                Button { addPalette() } label: { Label("新建", systemImage: "plus") }.font(.system(size: 12))
            }
            ForEach(live, id: \.id) { pal in paletteCard(pal) }
        }
    }

    private func paletteCard(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("名称", text: Binding(get: { p.name }, set: { p.name = $0; p.updatedAt = Date() })).font(.system(size: 12, weight: .semibold))
                if p.builtIn { Text("内置").font(.system(size: 9)).foregroundStyle(.secondary) }
                Spacer()
                if !p.builtIn {
                    Button(role: .destructive) { p.deleted = true; p.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
                }
            }
            ForEach(p.colorsHex.indices, id: \.self) { i in
                HStack {
                    Circle().fill(Color(uiColor: HexColor.parse(p.colorsHex[i]) ?? .gray)).frame(width: 16, height: 16)
                    TextField("#RRGGBB", text: Binding(
                        get: { p.colorsHex[i] },
                        set: { var c = p.colorsHex; c[i] = ColorHexField.normalize($0); p.colorsHex = c; p.updatedAt = Date() }
                    )).font(.system(size: 12).monospaced())
                    Button(role: .destructive) { var c = p.colorsHex; c.remove(at: i); p.colorsHex = c; p.updatedAt = Date() } label: { Image(systemName: "minus.circle").font(.system(size: 11)) }.buttonStyle(.plain)
                }
            }
            Button { var c = p.colorsHex; c.append("#888888"); p.colorsHex = c; p.updatedAt = Date() } label: { Label("加颜色", systemImage: "plus") }.font(.system(size: 11))
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func addPalette() {
        let p = Palette(name: "新调色板", colorsHex: ["#E41A1C", "#377EB8", "#4DAF4A"], builtIn: false)
        p.sortOrder = (live.map(\.sortOrder).max() ?? 0) + 1
        modelContext.insert(p)
    }
}
#endif
```
> Palette 无 datasetId(全局);照其模型。`colorsHex` 重新赋整数组以触发 SwiftData 脏标记。

- [ ] **Step 2: 编译** → BUILD SUCCEEDED。
- [ ] **Step 3: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): PaletteSettingsTab (color array CRUD)"`

---

### Task 9: EnumOptionSettingsTab(枚举值编辑器,含 edge.label)

**Files:** Modify `Studio/Settings/EnumOptionSettingsTab.swift`(替换占位)

- [ ] **Step 1: 实现**
```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData

struct EnumOptionSettingsTab: View {
    let datasetId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query private var options: [EnumOption]
    @State private var scope: String = "edge.label"
    @State private var newScope: String = ""

    private var scopes: [String] {
        let s = Set(options.filter { $0.datasetId == datasetId && !$0.deleted }.map(\.scope))
        return Array(s).sorted()
    }
    private var rows: [EnumOption] {
        options.filter { $0.datasetId == datasetId && $0.scope == scope && !$0.deleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("范围", selection: $scope) {
                ForEach(scopes, id: \.self) { Text($0).tag($0) }
            }.font(.system(size: 12))
            HStack {
                TextField("新范围 (如 school.category / edge.label)", text: $newScope).font(.system(size: 12))
                Button("用此范围") { if !newScope.isEmpty { scope = newScope; newScope = "" } }.font(.system(size: 11))
            }
            Divider().opacity(0.4)
            ForEach(rows, id: \.id) { opt in
                HStack {
                    TextField("值", text: Binding(get: { opt.label }, set: { opt.label = $0; opt.updatedAt = Date() })).font(.system(size: 12))
                    ColorHexField(title: "色", hex: Binding(get: { opt.colorHex ?? "" }, set: { opt.colorHex = $0.isEmpty ? nil : ColorHexField.normalize($0); opt.updatedAt = Date() }))
                    Button(role: .destructive) { opt.deleted = true; opt.updatedAt = Date() } label: { Image(systemName: "trash").font(.system(size: 11)) }.buttonStyle(.plain)
                }
            }
            Button { addOption() } label: { Label("加值", systemImage: "plus") }.font(.system(size: 12))
        }
    }

    private func addOption() {
        let s = scope.isEmpty ? "edge.label" : scope
        let o = EnumOption(datasetId: datasetId, scope: s, label: "新值",
                           sortOrder: (rows.map(\.sortOrder).max() ?? 0) + 1, colorHex: nil)
        modelContext.insert(o)
    }
}
#endif
```

- [ ] **Step 2: 编译** → BUILD SUCCEEDED。
- [ ] **Step 3: 提交** `git -c commit.gpgsign=false commit -am "feat(settings): EnumOptionSettingsTab (scope-filtered enum CRUD)"`

---

### Task 10: 全量测试 + 运行 smoke + CLAUDE.md

**Files:** Modify `CLAUDE.md`

- [ ] **Step 1: 全量单测 + 整 app 构建**
Run: `cd <worktree>/PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:PropertyAtlasTests 2>&1 | grep -E "TEST SUCCEEDED|TEST FAILED"` → SUCCEEDED。
Run: `xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' 2>&1 | tail -5` → BUILD SUCCEEDED。
> P9a 纯 additive UI,无 schema 变更 → **无清库 smoke**。运行期视觉验证由控制者(主 agent)在现有 store 上做一次非破坏 launch。

- [ ] **Step 2: 运行 smoke(主 agent,非破坏)**
主 agent:确认 app 未运行 → 用 worktree 构建(`BUILT_PRODUCTS_DIR`)launch 一次 → 打开 Studio → ⚙️ 设置 → 核对四 tab 显示/可增删改、新建视图设 groupBy=字段后地图按该字段分组染色。无需删库(additive)。失败则记录回退。

- [ ] **Step 3: 更新 CLAUDE.md** —— P8b 节点后加 P9a 节点(Settings 编辑 UI:SettingsSheet 四 tab、ViewConfigCodec/FieldKeyCatalog、DimensionPicker/PrimaryFilterEditor、Layer 含 zIndex/themeId、Palette、EnumOption;入口 ⚙️ 工具栏;纯 additive)。把计划列表加 P9a(已完成),并列剩余 P9 子项:P9b(CloudKit `.private` + 删 Legacy* + 删 FilterFieldConfig/LegendSwatch)、Theme/StyleRule/CameraPreset/CustomFieldDef 编辑器、逐实体-逐图层 theme 解析。

- [ ] **Step 4: 提交** `git -c commit.gpgsign=false commit -am "docs(claude): note P9a settings editing UI completion"`

---

## Self-Review

- **Spec 覆盖**:spec §9 P9 的 "Settings 编辑 UI(View/Layer/PrimaryFilter/NormalFilter/Dimension/EnumOption/Palette)" 本期覆盖;edge.label 编辑随 EnumOption(scope 任意)。**延后**(spec §9 余项):Theme/StyleRule 深度编辑器、CameraPreset/CustomFieldDef 编辑器、CloudKit `.private`、删 Legacy*、删 FilterFieldConfig/LegendSwatch、真正逐实体-逐图层 theme 解析 → 后续 P9b/P9c。
- **类型一致**:`ViewConfigCodec.encode/decodePrimary/Normals`(T1)、`FieldKeyCatalog.fields/enumLabels/edgeLabels`(T2)、`ColorHexField.normalize`(T3)、`AnyJSONValueField`(T3)、`DimensionPicker`(T4)、`FilterConditionRow`/`PrimaryFilterEditor`(T5)、`SettingsSheet`/四 `*SettingsTab`(T0/T6-T9)。tab 构造参数与 SettingsSheet 调用一致(ViewSettingsTab(viewContext:)、LayerSettingsTab(datasetId:)、PaletteSettingsTab()、EnumOptionSettingsTab(datasetId:))。
- **占位扫描**:无 TBD;T0 占位 View 在 T6-T9 替换。每步完整代码。
- **风险**:① SwiftUI Binding/keyPath 细节(尤其 `optBinding` 的 `ReferenceWritableKeyPath`)实现期按编译器适配。② 纯 additive,无 schema 变更 → 无清库;运行 smoke 非破坏。③ `MapViewContext` 的 `@Bindable`/`@Query` 在 sheet 内刷新:配置改动经 `updatedAt` 触发,active 切换经 `switchView`。④ `primaryEntityType` 固定 "school" 仅为字段候选;维度按字段名跨类型取值。⑤ DimensionPicker 的 `.field` 字段下拉用 FieldKeyCatalog(base+custom)。
