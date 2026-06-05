# 视图持有样式 Stage A 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把样式归到视图(MapView):新增强类型 `ViewEntityStyle`(每视图×4 实体)作默认样式、实体加强类型可空 override 列、调色板内联进 MapView;`StyleResolver` 去掉 `StyleRule` 一段;启动幂等迁移器零丢失搬运旧 theme/palette/override → 新模型。旧 `StyleRule`/`Theme`/`Palette` @Model 本阶段**保留不删**(Stage B 才删)。

**Architecture:** 纯加法 schema(SwiftData 自动轻量迁移)+ 运行时切到新模型 + 启动迁移器桥接。求值链:`builtin → ViewEntityStyle(view,type) → 分组染色 groupFillHex → 实体 override 列`。全程强类型,无 JSON 样式解析。

**Tech Stack:** SwiftUI · SwiftData · MapKit · Swift Testing · Mac Catalyst (`#if targetEnvironment(macCatalyst)`)。

**关键约束(读 spec `docs/superpowers/specs/2026-06-06-view-owned-style-redesign.md`):**
- 不丢数据:实体/边/标记/视图过滤原地保留;旧 theme/palette/override 经迁移器搬运后旧行仍留存。
- 文件 ≤ 300 行(CLAUDE.md);SwiftLint 禁 1–2 字符标识符、file_length error >400。
- iOS 17+,Swift Testing(非 XCTest)。
- 提交信息结尾:`Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`

**现状事实(已核实):**
- `Theme`(`Models/Style/Theme.swift`)字段:`defaultStylesJSON`(seed 时为 `"{}"`,即空)、`showLegend`、`styleRuleIds`、`isActive`。
- seed(`LegacyMigrator` ~525–648)建 4 themes + 4 MapViews(`paletteId = defaultPalette`);视觉差异来自 `seedSchoolStyleRules`(学校 grade/tier),本阶段停止生效(已确认接受)。
- `MapView`(`Models/Display/MapView.swift`)有 `paletteId: UUID?`;无 `paletteHex`/`showLegend`。
- 实体(`Compound`/`School`/`POI`/`Area`)各有 `overrideStyleJSON: String?`(pin 子集:shape/fillHex/glyph/glyphHex/size/labelVisible,见 `OverrideStyleCodec`)。
- `StyleResolver.resolvePin(entity:theme:rules:palettes:groupFillHex:themeDefaults:)`、`resolveArea(entity:theme:rules:palettes:themeDefaults:)`;仅 `RootView.buildPins`/`buildAreaOverlays` 调用。
- `StyleEntity`(`MapRender/ConditionEvaluator.swift`)有 `overrideJSON`(读 `field("__overrideStyleJSON")`);各实体 `styleEntity` 适配器把 `overrideStyleJSON` 塞进 `base["__overrideStyleJSON"]`。
- `MapViewContext.activeTheme`(`MapRender/MapViewContext.swift`)派生 active theme。
- `ModelSchema.allTypes`(`DataKit/ModelSchema.swift`)含 `StyleRule/Palette/Theme`。
- 测试目录:`PropertyAtlas/PropertyAtlasTests/`。

---

## 文件结构

**新建**
- `Models/Display/ViewEntityStyle.swift` — 视图默认样式 @Model(每视图×4)
- `MapRender/StyleFieldConvert.swift` — `ViewEntityStyle`/实体 override 列 ⇄ `PartialPinStyle`/`PartialAreaStyle` 转换(纯函数,可测)
- `DataKit/StyleConsolidationMigrator.swift` — 启动幂等搬运器
- `PropertyAtlasTests/StyleFieldConvertTests.swift`
- `PropertyAtlasTests/StyleConsolidationMigratorTests.swift`

**修改**
- `Models/Display/MapView.swift` — 加 `paletteHex`、`showLegend`
- `Models/Core/Dataset.swift` — 加 `stylesMigratedV2`
- `Models/Entities/{Compound,School,POI,Area}.swift` — 加可空 override 样式列
- `DataKit/ModelSchema.swift` — 注册 `ViewEntityStyle`
- `MapRender/ConditionEvaluator.swift` — `StyleEntity` 加 `overridePin`/`overrideArea`,适配器从列填充
- `MapRender/StyleResolver.swift` — 新求值链,删 rules 段 + JSON override 段
- `RootView.swift` — 预取 `ViewEntityStyle`、喂 resolver、palette 用 `paletteHex`、内容签名
- `DataKit/EntityReader.swift` / `DataKit/EntityWriter.swift` — typed override 读写
- `Studio/Editor/StyleOverrideSection.swift` — 绑定 typed 列
- `Studio/Settings/SettingsSheet.swift` — 8 tab → 5 tab
- `Studio/Settings/ViewSettingsTab.swift` — 加默认样式 + 调色板 + 图例区
- 应用启动处(`StudioRootView` seed/migrate 调用点)— 调 `StyleConsolidationMigrator.run`

**删除(本阶段,纯 UI 死文件)**
- `Studio/Settings/ThemeSettingsTab.swift`、`Studio/Settings/StyleRuleSettingsTab.swift`、`Studio/Settings/PaletteSettingsTab.swift`、`Studio/Settings/Components/StyleConditionRow.swift`、`Studio/Settings/StyleConditionCodec.swift`

> `StyleRule`/`Theme`/`Palette` @Model、`StyleRuleMatcher`、`ConditionEvaluator.matches`、`StyleDefaults.parseThemeDefaults`、`Layer.themeId`、`Dataset.activeThemeId`、`MapView.paletteId`、实体 `overrideStyleJSON` 列、`StyleConsolidationMigrator` → **Stage B 删**。

---

### Task 1: ViewEntityStyle @Model + 注册 schema

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Models/Display/ViewEntityStyle.swift`
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift:7-15`

- [ ] **Step 1: 建模型**

`Models/Display/ViewEntityStyle.swift`:

```swift
import Foundation
import SwiftData

/// 视图维度的实体默认样式(spec: 视图=样式容器)。每个 MapView 持 4 行
/// (compound/school/poi/area)。全部可空,nil = 继承 builtin。pin 类型用 pin 字段,
/// area 用 area 字段。求值链中位于 builtin 之后、分组染色之前。
@Model
final class ViewEntityStyle {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var viewId: UUID = UUID()
    var entityType: String = ""

    // pin 字段
    var shape: String?
    var fillHex: String?
    var strokeHex: String?
    var glyph: String?
    var glyphHex: String?
    var size: Int?
    var labelVisible: Bool?
    // area 字段
    var fillOpacity: Double?
    var strokeWidth: Double?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), datasetId: UUID, viewId: UUID, entityType: String) {
        self.id = id
        self.datasetId = datasetId
        self.viewId = viewId
        self.entityType = entityType
    }
}
```

- [ ] **Step 2: 注册 schema**

`DataKit/ModelSchema.swift`,`Layer.self, MapView.self,` 那行改为含 `ViewEntityStyle.self`:

```swift
        Layer.self, MapView.self, ViewEntityStyle.self,
```

- [ ] **Step 3: 编译**

Run: `cd PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Display/ViewEntityStyle.swift PropertyAtlas/PropertyAtlas/DataKit/ModelSchema.swift
git commit -m "feat(style): ViewEntityStyle @Model (per-view×4 default style)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: MapView 加 paletteHex + showLegend;Dataset 加 stylesMigratedV2

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Models/Display/MapView.swift:21`
- Modify: `PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift:10`

- [ ] **Step 1: MapView 加字段**

`MapView.swift`,在 `var paletteId: UUID?` 下一行加:

```swift
    var paletteHex: [String] = []
    var showLegend: Bool = true
```

- [ ] **Step 2: Dataset 加迁移标记**

`Dataset.swift`,在 `var activeCameraPresetId: UUID?` 下一行加:

```swift
    var stylesMigratedV2: Bool = false
```

- [ ] **Step 3: 编译**

Run: `cd PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`(纯加法,SwiftData 轻量迁移)

- [ ] **Step 4: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Display/MapView.swift PropertyAtlas/PropertyAtlas/Models/Core/Dataset.swift
git commit -m "feat(style): MapView.paletteHex/showLegend + Dataset.stylesMigratedV2

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: 4 实体加可空 override 样式列

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Models/Entities/Compound.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Models/Entities/School.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Models/Entities/POI.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Models/Entities/Area.swift`

> 复用 `ViewEntityStyle` 的字段语义(spec「复用视图维度的实体定义」)。pin 实体(Compound/School/POI)加 pin 子集;Area 加 area 子集。`overrideStyleJSON` 旧列**保留**(Stage B 删)。

- [ ] **Step 1: Compound/School/POI 各加 pin override 列**

三个文件,均在 `var overrideStyleJSON: String?` 下一行加同一块:

```swift
    // 强类型 override(nil = 继承视图默认)。取代 overrideStyleJSON(Stage B 删旧列)。
    var styleShape: String?
    var styleFillHex: String?
    var styleStrokeHex: String?
    var styleGlyph: String?
    var styleGlyphHex: String?
    var styleSize: Int?
    var styleLabelVisible: Bool?
```

- [ ] **Step 2: Area 加 area override 列**

`Area.swift`,在 `var overrideStyleJSON: String?` 下一行加:

```swift
    // 强类型 override(nil = 继承视图默认)。取代 overrideStyleJSON(Stage B 删旧列)。
    var styleFillHex: String?
    var styleFillOpacity: Double?
    var styleStrokeHex: String?
    var styleStrokeWidth: Double?
    var styleLabelVisible: Bool?
```

- [ ] **Step 3: 编译**

Run: `cd PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/Models/Entities/Compound.swift PropertyAtlas/PropertyAtlas/Models/Entities/School.swift PropertyAtlas/PropertyAtlas/Models/Entities/POI.swift PropertyAtlas/PropertyAtlas/Models/Entities/Area.swift
git commit -m "feat(style): typed nullable override columns on 4 entities

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: 样式字段转换器 StyleFieldConvert(纯函数 + TDD)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/MapRender/StyleFieldConvert.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/StyleFieldConvertTests.swift`

> `ViewEntityStyle` 与实体 override 列都是「可空样式字段」,统一转成现有 `PartialPinStyle`/`PartialAreaStyle` 喂求值链。这里只做无副作用映射。

- [ ] **Step 1: 写失败测试**

`PropertyAtlasTests/StyleFieldConvertTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import PropertyAtlas

struct StyleFieldConvertTests {
    @Test func viewStyleToPinPartialMapsFields() {
        let vs = ViewEntityStyle(datasetId: UUID(), viewId: UUID(), entityType: "compound")
        vs.shape = "square"
        vs.fillHex = "#FF0000"
        vs.size = 30
        vs.labelVisible = true
        let partial = StyleFieldConvert.pinPartial(
            shape: vs.shape, fillHex: vs.fillHex, strokeHex: vs.strokeHex,
            glyph: vs.glyph, glyphHex: vs.glyphHex, size: vs.size, labelVisible: vs.labelVisible
        )
        #expect(partial.shape == .square)
        #expect(partial.fillHex == "#FF0000")
        #expect(partial.size == CGFloat(30))
        #expect(partial.labelVisible == true)
        #expect(partial.glyph == nil)
    }

    @Test func badShapeStringBecomesNil() {
        let partial = StyleFieldConvert.pinPartial(
            shape: "not-a-shape", fillHex: nil, strokeHex: nil,
            glyph: nil, glyphHex: nil, size: nil, labelVisible: nil
        )
        #expect(partial.shape == nil)
    }

    @Test func areaPartialMapsFields() {
        let partial = StyleFieldConvert.areaPartial(
            fillHex: "#00FF00", fillOpacity: 0.5, strokeHex: nil, strokeWidth: 2.0, labelVisible: false
        )
        #expect(partial.fillHex == "#00FF00")
        #expect(partial.fillOpacity == 0.5)
        #expect(partial.strokeWidth == 2.0)
        #expect(partial.labelVisible == false)
        #expect(partial.strokeHex == nil)
    }
}
```

- [ ] **Step 2: 跑测试看失败**

Run: `cd PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "Cannot find 'StyleFieldConvert'|BUILD FAILED" | head`
Expected: 编译失败(`StyleFieldConvert` 未定义)

- [ ] **Step 3: 实现**

`MapRender/StyleFieldConvert.swift`:

```swift
import CoreGraphics
import Foundation

/// 可空样式字段(ViewEntityStyle / 实体 override 列)→ PartialPinStyle/PartialAreaStyle。
/// 无副作用纯映射;非法 shape 字符串 → nil(忽略)。
enum StyleFieldConvert {
    static func pinPartial(
        shape: String?, fillHex: String?, strokeHex: String?,
        glyph: String?, glyphHex: String?, size: Int?, labelVisible: Bool?
    ) -> PartialPinStyle {
        PartialPinStyle(
            shape: shape.flatMap { PinShape(rawValue: $0) },
            fillHex: fillHex,
            strokeHex: strokeHex,
            glyph: glyph,
            glyphHex: glyphHex,
            size: size.map { CGFloat($0) },
            labelVisible: labelVisible
        )
    }

    static func areaPartial(
        fillHex: String?, fillOpacity: Double?, strokeHex: String?,
        strokeWidth: Double?, labelVisible: Bool?
    ) -> PartialAreaStyle {
        PartialAreaStyle(
            fillHex: fillHex,
            fillOpacity: fillOpacity,
            strokeHex: strokeHex,
            strokeWidth: strokeWidth,
            labelVisible: labelVisible
        )
    }
}
```

- [ ] **Step 4: 跑测试看通过**

Run: `cd PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "StyleFieldConvertTests|TEST (SUCCEEDED|FAILED)" | tail`
Expected: 3 测试通过,`** TEST SUCCEEDED **`

- [ ] **Step 5: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/StyleFieldConvert.swift PropertyAtlas/PropertyAtlasTests/StyleFieldConvertTests.swift
git commit -m "feat(style): StyleFieldConvert (nullable fields -> PartialPin/AreaStyle)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: StyleEntity 携带 typed override + 适配器从列填充

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/MapRender/ConditionEvaluator.swift:19-41`(StyleEntity 定义)
- Modify: `PropertyAtlas/PropertyAtlas/MapRender/ConditionEvaluator.swift:87-150`(4 个 styleEntity 适配器)

> 把实体 typed override 列经 `StyleFieldConvert` 转成 partial 挂到 `StyleEntity`,供 `StyleResolver` 直接合并(取代旧 `overrideJSON` 路径)。`StyleEntity` 仍保留 `baseFields`/`customFields`/`field(_)`(过滤维度仍用)。

- [ ] **Step 1: StyleEntity 加 override partial 字段**

`ConditionEvaluator.swift`,`struct StyleEntity` 改为(在现有字段后加两个,init 加默认参):

```swift
struct StyleEntity {
    let entityType: String
    let id: UUID
    private let baseFields: [String: AnyJSON]
    private let customFields: [String: AnyJSON]
    /// 实体级 override(typed 列 → partial)。空 partial = 无 override。
    let overridePin: PartialPinStyle
    let overrideArea: PartialAreaStyle

    init(
        entityType: String,
        id: UUID,
        baseFields: [String: AnyJSON],
        customFields: [String: AnyJSON],
        overridePin: PartialPinStyle = PartialPinStyle(),
        overrideArea: PartialAreaStyle = PartialAreaStyle()
    ) {
        self.entityType = entityType
        self.id = id
        self.baseFields = baseFields
        self.customFields = customFields
        self.overridePin = overridePin
        self.overrideArea = overrideArea
    }

    func field(_ name: String) -> AnyJSON? {
        if let v = baseFields[name] { return v }
        return customFields[name]
    }
}
```

- [ ] **Step 2: pin 实体适配器填 overridePin**

`ConditionEvaluator.swift` 三个 pin 适配器(`Compound`/`School`/`POI`)的 `return StyleEntity(...)` 改为带 overridePin。以 Compound 为例(School/POI 同样在 return 处加 `overridePin:` 参,字段名一致):

```swift
        return StyleEntity(
            entityType: "compound", id: id, baseFields: base, customFields: custom,
            overridePin: StyleFieldConvert.pinPartial(
                shape: styleShape, fillHex: styleFillHex, strokeHex: styleStrokeHex,
                glyph: styleGlyph, glyphHex: styleGlyphHex, size: styleSize, labelVisible: styleLabelVisible
            )
        )
```

School、POI 适配器 return 处同样改(三处结构一致,引用各自实体上 Task 3 加的同名列)。

- [ ] **Step 3: Area 适配器填 overrideArea**

`ConditionEvaluator.swift` 的 `Area.styleEntity` return 改为:

```swift
        return StyleEntity(
            entityType: "area", id: id, baseFields: base, customFields: custom,
            overrideArea: StyleFieldConvert.areaPartial(
                fillHex: styleFillHex, fillOpacity: styleFillOpacity, strokeHex: styleStrokeHex,
                strokeWidth: styleStrokeWidth, labelVisible: styleLabelVisible
            )
        )
```

- [ ] **Step 4: 编译(此时 StyleResolver 仍引用旧 overrideJSON,扩展末尾 `var overrideJSON` 仍在,应通过)**

Run: `cd PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/ConditionEvaluator.swift
git commit -m "feat(style): StyleEntity carries typed override partials from entity columns

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: StyleResolver 新求值链 + RootView 切换(同任务,保编译)

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift`
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift`(`rebuildContent`/`buildPins`/`buildAreaOverlays`/`contentSignature`)
- Test: `PropertyAtlas/PropertyAtlasTests/StyleResolverChainTests.swift`

> `resolvePin`/`resolveArea` 删 `theme`/`rules`/`themeDefaults` 参,改收 `viewStyle: ViewEntityStyle?`;override 从 `entity.overridePin`/`overrideArea` 取(删 JSON override)。RootView 按 viewId 预取 4 行 ViewEntityStyle 喂入。

- [ ] **Step 1: 写失败测试(求值链顺序 builtin→view→groupFill→override)**

`PropertyAtlasTests/StyleResolverChainTests.swift`:

```swift
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleResolverChainTests {
    private func pinEntity(override: PartialPinStyle = PartialPinStyle()) -> StyleEntity {
        StyleEntity(entityType: "compound", id: UUID(), baseFields: [:], customFields: [:], overridePin: override)
    }

    @Test func viewStyleOverridesBuiltin() {
        let vs = ViewEntityStyle(datasetId: UUID(), viewId: UUID(), entityType: "compound")
        vs.fillHex = "#111111"
        let style = StyleResolver.resolvePin(entity: pinEntity(), viewStyle: vs, groupFillHex: nil)
        #expect(style.fillHex == "#111111")
    }

    @Test func groupFillOverridesViewStyle() {
        let vs = ViewEntityStyle(datasetId: UUID(), viewId: UUID(), entityType: "compound")
        vs.fillHex = "#111111"
        let style = StyleResolver.resolvePin(entity: pinEntity(), viewStyle: vs, groupFillHex: "#222222")
        #expect(style.fillHex == "#222222")
    }

    @Test func entityOverrideBeatsGroupFill() {
        let vs = ViewEntityStyle(datasetId: UUID(), viewId: UUID(), entityType: "compound")
        vs.fillHex = "#111111"
        let entity = pinEntity(override: PartialPinStyle(fillHex: "#333333"))
        let style = StyleResolver.resolvePin(entity: entity, viewStyle: vs, groupFillHex: "#222222")
        #expect(style.fillHex == "#333333")
    }

    @Test func nilViewStyleFallsBackToBuiltin() {
        let style = StyleResolver.resolvePin(entity: pinEntity(), viewStyle: nil, groupFillHex: nil)
        #expect(style.fillHex == "#A8A8A8") // StyleDefaults.builtinPin
    }
}
```

- [ ] **Step 2: 跑测试看失败**

Run: `cd PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "extra argument|cannot find|BUILD FAILED" | head`
Expected: 编译失败(`resolvePin` 旧签名不含 `viewStyle:`)

- [ ] **Step 3: 重写 StyleResolver**

`MapRender/StyleResolver.swift` 整体替换为(删 theme/rules/themeDefaults/parseDefaults + JSON override + palette-rule helper;保留 area):

```swift
import CoreGraphics
import Foundation

@MainActor
enum StyleResolver {
    static func resolvePin(
        entity: StyleEntity,
        viewStyle: ViewEntityStyle?,
        groupFillHex: String? = nil
    ) -> PinStyle {
        let base = StyleDefaults.builtinPin(for: entity.entityType)
        var partial = PartialPinStyle()
        if let viewStyle {
            partial.merge(StyleFieldConvert.pinPartial(
                shape: viewStyle.shape, fillHex: viewStyle.fillHex, strokeHex: viewStyle.strokeHex,
                glyph: viewStyle.glyph, glyphHex: viewStyle.glyphHex,
                size: viewStyle.size, labelVisible: viewStyle.labelVisible
            ))
        }
        if let groupFillHex { partial.fillHex = groupFillHex }
        partial.merge(entity.overridePin)
        return partial.finalize(default: base)
    }

    static func resolveArea(
        entity: StyleEntity,
        viewStyle: ViewEntityStyle?
    ) -> AreaStyle {
        let base = StyleDefaults.builtinArea()
        var partial = PartialAreaStyle()
        if let viewStyle {
            partial.merge(StyleFieldConvert.areaPartial(
                fillHex: viewStyle.fillHex, fillOpacity: viewStyle.fillOpacity,
                strokeHex: viewStyle.strokeHex, strokeWidth: viewStyle.strokeWidth,
                labelVisible: viewStyle.labelVisible
            ))
        }
        partial.merge(entity.overrideArea)
        return partial.finalize(default: base)
    }
}
```

> 注:删掉了 `extension StyleEntity { var overrideJSON }`。若其它文件引用 `overrideJSON`,Step 5 编译会暴露;仅 StyleResolver 用过,已随之删除。

- [ ] **Step 4: RootView 切换调用**

`RootView.swift` `rebuildContent`:删 `activeTheme`/`rulesForTheme`/`palettesById` 相关样式入参,改预取 ViewEntityStyle。具体:

(a) `rebuildContent` 内,`buildPins`/`buildAreaOverlays` 调用前加预取(用 `dsId` + `activeMapView?.id`):

```swift
        let viewStyles = buildViewStyles(dsId: dsId, viewId: activeMapView?.id)
```

(b) 在 RootView 加方法(放 `buildEdgeProjection` 附近):

```swift
    /// 按 viewId 预取该视图 4 行 ViewEntityStyle → [entityType: ViewEntityStyle]。
    private func buildViewStyles(dsId: UUID, viewId: UUID?) -> [String: ViewEntityStyle] {
        guard let viewId else { return [:] }
        let fetch = FetchDescriptor<ViewEntityStyle>(
            predicate: #Predicate { $0.datasetId == dsId && $0.viewId == viewId && !$0.deleted }
        )
        let rows = (try? modelContext.fetch(fetch)) ?? []
        return Dictionary(rows.map { ($0.entityType, $0) }, uniquingKeysWith: { first, _ in first })
    }
```

(c) `buildPins` 签名去掉 `theme`/`rules`/`palettes`,加 `viewStyles: [String: ViewEntityStyle]`;循环内:

```swift
            let style = StyleResolver.resolvePin(
                entity: c.entity, viewStyle: viewStyles[c.type], groupFillHex: groupColors[c.id]
            )
```

(d) `buildAreaOverlays` 签名去掉 `theme`/`rules`/`palettes`,加 `viewStyles`;循环内:

```swift
            let style = StyleResolver.resolveArea(entity: a.styleEntity, viewStyle: viewStyles["area"])
```

(e) `rebuildContent` 里删 `themeDefaults` 预解析(若 Task 之前残留)、`activeTheme`/`rulesForTheme` 局部;`buildPins(...)`/`buildAreaOverlays(...)` 调用改传 `viewStyles: viewStyles`。

(f) body 顶部 `let activeTheme = viewContext?.activeTheme` 行删除;`activeRuleIds`/`rulesForTheme` 行删除;`rebuildContent`/`refreshCacheIfNeeded`/`contentSignature` 形参里的 `activeTheme:`/`rulesForTheme:` 删除,调用处同步删。

- [ ] **Step 5: GroupColorResolver palette 源 → paletteHex**

`RootView.swift` `rebuildContent`,palette 取值改为:

```swift
        let palette = (activeMapView?.paletteHex.isEmpty == false)
            ? (activeMapView?.paletteHex ?? PaletteAssigner.highContrast)
            : PaletteAssigner.highContrast
```

删除 `palettesById` 局部 + body 顶部 `palettesById` 构造 + 传参(`buildPins`/`buildAreaOverlays`/`buildLegendSpecs` 不再需要 palettes)。`GroupColorResolver.colors(..., palette: palette, ...)` 保持(已收 `[String]`)。

- [ ] **Step 6: contentSignature 调整**

`contentSignature`:删 `activeTheme?.id`/`activeTheme?.updatedAt`/`rulesForTheme` 循环;加视图样式 + 调色板:

```swift
        hasher.combine((activeMapView?.paletteHex ?? []).joined(separator: ","))
        hasher.combine(activeMapView?.showLegend ?? true)
        let styleFetch = FetchDescriptor<ViewEntityStyle>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted }
        )
        for row in (try? modelContext.fetch(styleFetch)) ?? [] {
            hasher.combine(row.viewId)
            hasher.combine(row.entityType)
            hasher.combine(row.updatedAt)
        }
```

(放在原 `activeTheme` hash 位置;`contentSignature` 已含 `activeMapView?.id`,故只对当前视图敏感即可,但全量 ViewEntityStyle updatedAt 也无妨。)

- [ ] **Step 7: 编译 + 跑测试**

Run: `cd PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|StyleResolverChainTests|TEST (SUCCEEDED|FAILED)" | tail -15`
Expected: 4 链测试通过,`** TEST SUCCEEDED **`。如有 `overrideJSON`/`themeDefaults` 等残留引用报错,按错误删除对应残留调用。

- [ ] **Step 8: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift PropertyAtlas/PropertyAtlas/RootView.swift PropertyAtlas/PropertyAtlasTests/StyleResolverChainTests.swift
git commit -m "feat(style): StyleResolver view-style chain; RootView feeds ViewEntityStyle + paletteHex

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: typed override 读写(EntityReader/Writer/Codec/Section)

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/OverrideStyleCodec.swift`
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/EntityReader.swift:51-57`
- Modify: `PropertyAtlas/PropertyAtlas/DataKit/EntityWriter.swift:67-70`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Editor/StyleOverrideSection.swift`

> 实体编辑器读写 typed 列(`styleShape`/`styleFillHex`/...)。`OverrideStyle` struct 复用作 UI 载体;JSON 编码函数 Stage A 仍保留(迁移器 Task 8 解析旧 JSON 要用 `decode`),但读写实体改走 typed 列。

- [ ] **Step 1: EntityReader 加 typed override 读**

`EntityReader.swift`,在现有 `overrideStyleJSON(_:in:)` 之后加(保留旧函数给迁移器读旧值):

```swift
    static func overrideStyle(_ ref: EntityRef, in context: ModelContext) -> OverrideStyle {
        switch ref.kind {
        case .compound:
            guard let e = fetch(Compound.self, ref.id, context) else { return OverrideStyle() }
            return OverrideStyle(shape: e.styleShape, fillHex: e.styleFillHex, glyph: e.styleGlyph,
                                 glyphHex: e.styleGlyphHex, size: e.styleSize, labelVisible: e.styleLabelVisible)
        case .school:
            guard let e = fetch(School.self, ref.id, context) else { return OverrideStyle() }
            return OverrideStyle(shape: e.styleShape, fillHex: e.styleFillHex, glyph: e.styleGlyph,
                                 glyphHex: e.styleGlyphHex, size: e.styleSize, labelVisible: e.styleLabelVisible)
        case .poi:
            guard let e = fetch(POI.self, ref.id, context) else { return OverrideStyle() }
            return OverrideStyle(shape: e.styleShape, fillHex: e.styleFillHex, glyph: e.styleGlyph,
                                 glyphHex: e.styleGlyphHex, size: e.styleSize, labelVisible: e.styleLabelVisible)
        case .area:
            guard let e = fetch(Area.self, ref.id, context) else { return OverrideStyle() }
            return OverrideStyle(shape: nil, fillHex: e.styleFillHex, glyph: nil,
                                 glyphHex: nil, size: nil, labelVisible: e.styleLabelVisible)
        }
    }
```

> `OverrideStyle` struct(`OverrideStyleCodec.swift`)无 strokeHex/area 字段;UI override 维持现有 pin 子集(shape/fillHex/glyph/glyphHex/size/labelVisible),与现状一致。area override 仅 fillHex/labelVisible 经 UI;其余 area typed 列暂不在编辑器暴露(YAGNI,现状 area 也无 override UI 细项)。

- [ ] **Step 2: EntityWriter 加 typed override 写**

`EntityWriter.swift`,在现有 `setOverrideStyleJSON` 之后加:

```swift
    static func setOverrideStyle(_ ref: EntityRef, _ o: OverrideStyle, in context: ModelContext) {
        touch(ref, in: context) { c in
            c.styleShape = o.shape; c.styleFillHex = o.fillHex; c.styleGlyph = o.glyph
            c.styleGlyphHex = o.glyphHex; c.styleSize = o.size; c.styleLabelVisible = o.labelVisible
        } s: { s in
            s.styleShape = o.shape; s.styleFillHex = o.fillHex; s.styleGlyph = o.glyph
            s.styleGlyphHex = o.glyphHex; s.styleSize = o.size; s.styleLabelVisible = o.labelVisible
        } p: { p in
            p.styleShape = o.shape; p.styleFillHex = o.fillHex; p.styleGlyph = o.glyph
            p.styleGlyphHex = o.glyphHex; p.styleSize = o.size; p.styleLabelVisible = o.labelVisible
        } a: { a in
            a.styleFillHex = o.fillHex; a.styleLabelVisible = o.labelVisible
        }
    }
```

> 确认 `touch` 闭包签名为 `(c:,s:,p:,a:)`(见 `EntityWriter.swift:43`)。

- [ ] **Step 3: StyleOverrideSection 改读写 typed**

`Studio/Editor/StyleOverrideSection.swift`:`onAppear` 与 `persist` 改:

```swift
        .onAppear { override = EntityReader.overrideStyle(ref, in: context) }
```

```swift
    private func persist() {
        EntityWriter.setOverrideStyle(ref, override, in: context)
    }
```

- [ ] **Step 4: 编译**

Run: `cd PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/EntityReader.swift PropertyAtlas/PropertyAtlas/DataKit/EntityWriter.swift PropertyAtlas/PropertyAtlas/Studio/Editor/StyleOverrideSection.swift
git commit -m "feat(style): entity override reads/writes typed columns

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: StyleConsolidationMigrator(幂等搬运 + TDD)

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/DataKit/StyleConsolidationMigrator.swift`
- Test: `PropertyAtlas/PropertyAtlasTests/StyleConsolidationMigratorTests.swift`
- Modify: 启动调用点(见 Step 5)

> 每视图幂等闸 = 是否已有 `ViewEntityStyle` 行;实体 override 幂等闸 = `Dataset.stylesMigratedV2`。旧 theme `defaultStylesJSON` 经 `StyleDefaults.parseThemeDefaults` 解析(Stage A 仍在);palette 经 `paletteId` 取 `colorsHex`;实体旧 `overrideStyleJSON` 经 `OverrideStyleCodec.decode`。

- [ ] **Step 1: 写失败测试**

`PropertyAtlasTests/StyleConsolidationMigratorTests.swift`:

```swift
import Testing
import SwiftData
@testable import PropertyAtlas

@MainActor
struct StyleConsolidationMigratorTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(ModelSchema.allTypes), configurations: [config])
        return ModelContext(container)
    }

    @Test func seedsViewStylesAndPaletteFromTheme() throws {
        let ctx = try makeContext()
        let ds = Dataset(); ctx.insert(ds)
        let palette = Palette(name: "p", colorsHex: ["#AAA111", "#BBB222"]); ctx.insert(palette)
        let theme = Theme(datasetId: ds.id, name: "t")
        theme.defaultStylesJSON = #"{"compound":{"fillHex":"#123456","size":28}}"#
        theme.showLegend = false
        ctx.insert(theme)
        ds.activeThemeId = theme.id
        let view = MapView(datasetId: ds.id, name: "v")
        view.paletteId = palette.id
        view.isActive = true
        ctx.insert(view)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let styles = try ctx.fetch(FetchDescriptor<ViewEntityStyle>())
        #expect(styles.count == 4) // compound/school/poi/area
        let compound = styles.first { $0.entityType == "compound" }
        #expect(compound?.fillHex == "#123456")
        #expect(compound?.size == 28)
        let refreshedView = try ctx.fetch(FetchDescriptor<MapView>()).first
        #expect(refreshedView?.paletteHex == ["#AAA111", "#BBB222"])
        #expect(refreshedView?.showLegend == false)
    }

    @Test func idempotentDoesNotClobberUserEdits() throws {
        let ctx = try makeContext()
        let ds = Dataset(); ctx.insert(ds)
        let theme = Theme(datasetId: ds.id, name: "t")
        theme.defaultStylesJSON = #"{"compound":{"fillHex":"#123456"}}"#
        ctx.insert(theme); ds.activeThemeId = theme.id
        let view = MapView(datasetId: ds.id, name: "v"); view.isActive = true; ctx.insert(view)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)
        // 用户编辑
        let style = try ctx.fetch(FetchDescriptor<ViewEntityStyle>()).first { $0.entityType == "compound" }
        style?.fillHex = "#999999"; try ctx.save()
        // 二次跑不覆盖
        StyleConsolidationMigrator.run(in: ctx)
        let after = try ctx.fetch(FetchDescriptor<ViewEntityStyle>()).first { $0.entityType == "compound" }
        #expect(after?.fillHex == "#999999")
    }

    @Test func migratesEntityOverrideJSONToColumns() throws {
        let ctx = try makeContext()
        let ds = Dataset(); ctx.insert(ds)
        let c = Compound(datasetId: ds.id, name: "x", latitude: 1, longitude: 1)
        c.overrideStyleJSON = #"{"fillHex":"#ABCABC","size":40}"#
        ctx.insert(c)
        try ctx.save()

        StyleConsolidationMigrator.run(in: ctx)

        let refreshed = try ctx.fetch(FetchDescriptor<Compound>()).first
        #expect(refreshed?.styleFillHex == "#ABCABC")
        #expect(refreshed?.styleSize == 40)
        let refreshedDs = try ctx.fetch(FetchDescriptor<Dataset>()).first
        #expect(refreshedDs?.stylesMigratedV2 == true)
    }
}
```

> `Dataset()` 需无参 init —— 若 `Dataset` init 带参,测试改用其实际签名(读 `Models/Core/Dataset.swift`);此处用默认空 init 占位,实现 Step 前先核对。

- [ ] **Step 2: 跑测试看失败**

Run: `cd PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "Cannot find 'StyleConsolidationMigrator'|BUILD FAILED" | head`
Expected: 编译失败

- [ ] **Step 3: 实现迁移器**

`DataKit/StyleConsolidationMigrator.swift`:

```swift
import Foundation
import SwiftData

/// Stage A 启动幂等搬运:旧 Theme/Palette/实体 overrideStyleJSON → 新视图样式模型。
/// 每视图闸 = 是否已有 ViewEntityStyle 行;实体 override 闸 = Dataset.stylesMigratedV2。
/// Stage B 删除本文件。
@MainActor
enum StyleConsolidationMigrator {
    static func run(in context: ModelContext) {
        migrateViews(in: context)
        migrateEntityOverrides(in: context)
        try? context.save()
    }

    private static func migrateViews(in context: ModelContext) {
        let views = (try? context.fetch(FetchDescriptor<MapView>(
            predicate: #Predicate { !$0.deleted }
        ))) ?? []
        for view in views {
            let viewId = view.id
            let dsId = view.datasetId
            let existing = (try? context.fetch(FetchDescriptor<ViewEntityStyle>(
                predicate: #Predicate { $0.viewId == viewId && !$0.deleted }
            ))) ?? []
            if !existing.isEmpty { continue } // 闸:已迁移,跳过整视图

            let theme = resolveTheme(for: view, in: context)
            let parsed = theme.flatMap { try? StyleDefaults.parseThemeDefaults($0.defaultStylesJSON) }

            for entityType in ["compound", "school", "poi", "area"] {
                let row = ViewEntityStyle(datasetId: dsId, viewId: viewId, entityType: entityType)
                if entityType == "area", let area = parsed?.area["area"] {
                    row.fillHex = area.fillHex; row.fillOpacity = area.fillOpacity
                    row.strokeHex = area.strokeHex; row.strokeWidth = area.strokeWidth
                    row.labelVisible = area.labelVisible
                } else if let pin = parsed?.pin[entityType] {
                    row.shape = pin.shape?.rawValue; row.fillHex = pin.fillHex
                    row.strokeHex = pin.strokeHex; row.glyph = pin.glyph
                    row.glyphHex = pin.glyphHex; row.size = pin.size.map { Int($0) }
                    row.labelVisible = pin.labelVisible
                }
                context.insert(row)
            }

            if let palette = view.paletteId.flatMap({ pid in
                (try? context.fetch(FetchDescriptor<Palette>(predicate: #Predicate { $0.id == pid })))?.first
            }) {
                view.paletteHex = palette.colorsHex
            }
            if let theme { view.showLegend = theme.showLegend }
        }
    }

    /// 复刻旧 MapViewContext.activeTheme:启用图层 themeId 最高 zIndex → 回退 dataset.activeThemeId。
    private static func resolveTheme(for view: MapView, in context: ModelContext) -> Theme? {
        let dsId = view.datasetId
        let enabled = Set(view.enabledLayerIds)
        let layers = ((try? context.fetch(FetchDescriptor<Layer>(
            predicate: #Predicate { $0.datasetId == dsId && !$0.deleted }
        ))) ?? []).filter { enabled.contains($0.id) }.sorted { $0.zIndex > $1.zIndex }
        if let tid = layers.compactMap(\.themeId).first, let theme = themeById(tid, in: context) {
            return theme
        }
        let ds = (try? context.fetch(FetchDescriptor<Dataset>(predicate: #Predicate { $0.id == dsId })))?.first
        if let aid = ds?.activeThemeId { return themeById(aid, in: context) }
        return nil
    }

    private static func themeById(_ id: UUID, in context: ModelContext) -> Theme? {
        (try? context.fetch(FetchDescriptor<Theme>(predicate: #Predicate { $0.id == id && !$0.deleted })))?.first
    }

    private static func migrateEntityOverrides(in context: ModelContext) {
        let datasets = (try? context.fetch(FetchDescriptor<Dataset>(
            predicate: #Predicate { !$0.deleted && !$0.stylesMigratedV2 }
        ))) ?? []
        for ds in datasets {
            let dsId = ds.id
            for compound in (try? context.fetch(FetchDescriptor<Compound>(
                predicate: #Predicate { $0.datasetId == dsId }
            ))) ?? [] {
                let o = OverrideStyleCodec.decode(compound.overrideStyleJSON)
                compound.styleShape = o.shape; compound.styleFillHex = o.fillHex
                compound.styleGlyph = o.glyph; compound.styleGlyphHex = o.glyphHex
                compound.styleSize = o.size; compound.styleLabelVisible = o.labelVisible
            }
            for school in (try? context.fetch(FetchDescriptor<School>(
                predicate: #Predicate { $0.datasetId == dsId }
            ))) ?? [] {
                let o = OverrideStyleCodec.decode(school.overrideStyleJSON)
                school.styleShape = o.shape; school.styleFillHex = o.fillHex
                school.styleGlyph = o.glyph; school.styleGlyphHex = o.glyphHex
                school.styleSize = o.size; school.styleLabelVisible = o.labelVisible
            }
            for poi in (try? context.fetch(FetchDescriptor<POI>(
                predicate: #Predicate { $0.datasetId == dsId }
            ))) ?? [] {
                let o = OverrideStyleCodec.decode(poi.overrideStyleJSON)
                poi.styleShape = o.shape; poi.styleFillHex = o.fillHex
                poi.styleGlyph = o.glyph; poi.styleGlyphHex = o.glyphHex
                poi.styleSize = o.size; poi.styleLabelVisible = o.labelVisible
            }
            for area in (try? context.fetch(FetchDescriptor<Area>(
                predicate: #Predicate { $0.datasetId == dsId }
            ))) ?? [] {
                let o = OverrideStyleCodec.decode(area.overrideStyleJSON)
                area.styleFillHex = o.fillHex; area.styleLabelVisible = o.labelVisible
            }
            ds.stylesMigratedV2 = true
        }
    }
}
```

- [ ] **Step 4: 跑测试看通过**

Run: `cd PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "StyleConsolidationMigratorTests|TEST (SUCCEEDED|FAILED)" | tail`
Expected: 3 测试通过

- [ ] **Step 5: 接入启动(`SeedImporter.runIfNeeded` 两条路径都要跑)**

`States/SeedImporter.swift` 的 `runIfNeeded` 有两个退出路径,迁移器须在**两处**都跑(既有库迁移是「不丢数据」的核心):

(a) 既有库早返回分支(`if try !context.fetch(FetchDescriptor<Dataset>()).isEmpty {` 内),在 `try context.save()` **前**加:

```swift
            StyleConsolidationMigrator.run(in: context)
```

(b) 新库 seed 分支,line ~62 `progress(0.95, "保存")` **前**加:

```swift
        StyleConsolidationMigrator.run(in: context)
```

> `StyleConsolidationMigrator.run` 内部自己 `save()`,与外层 `save()` 叠加无害(幂等)。既有库:搬运已有 theme/palette/override;新库:LegacyMigrator 已 seed themes/views/palette,迁移器据此建 ViewEntityStyle + 填 paletteHex。

- [ ] **Step 6: 编译 + 全量测试**

Run: `cd PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)" | tail`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 7: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/DataKit/StyleConsolidationMigrator.swift PropertyAtlas/PropertyAtlasTests/StyleConsolidationMigratorTests.swift <启动调用点文件>
git commit -m "feat(style): StyleConsolidationMigrator (idempotent carry of theme/palette/override)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: 设置页 8→5 tab + 删 3 个样式 tab 文件

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Settings/SettingsSheet.swift`
- Delete: `Studio/Settings/ThemeSettingsTab.swift`、`Studio/Settings/StyleRuleSettingsTab.swift`、`Studio/Settings/PaletteSettingsTab.swift`、`Studio/Settings/Components/StyleConditionRow.swift`、`Studio/Settings/StyleConditionCodec.swift`

- [ ] **Step 1: SettingsSheet enum + switch 改 5 tab**

`SettingsSheet.swift` `enum SettingsTab` 改为:

```swift
enum SettingsTab: String, CaseIterable, Identifiable {
    case view = "视图", layer = "图层", enumOption = "枚举"
    case camera = "相机", customField = "字段"
```

`icon` 计算属性删 `.palette`/`.theme`/`.styleRule` 三 case。`switch tab` 删 `.palette`/`.theme`/`.styleRule` 三分支:

```swift
                    switch tab {
                    case .view: ViewSettingsTab(viewContext: viewContext)
                    case .layer: LayerSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .enumOption: EnumOptionSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .camera: CameraSettingsTab(datasetId: viewContext.datasetIdValue)
                    case .customField: CustomFieldSettingsTab(datasetId: viewContext.datasetIdValue)
                    }
```

- [ ] **Step 2: 删 5 个文件**

```bash
cd PropertyAtlas/PropertyAtlas
rm Studio/Settings/ThemeSettingsTab.swift Studio/Settings/StyleRuleSettingsTab.swift Studio/Settings/PaletteSettingsTab.swift Studio/Settings/Components/StyleConditionRow.swift Studio/Settings/StyleConditionCodec.swift
```

> 这些是 UI 文件。`StyleConditionCodec`/`StyleConditionRow` 仅被 `StyleRuleSettingsTab` 用。若编译报其它引用,说明还有消费点 —— 按报错处理(预期无)。`ConditionEvaluator`/`StyleCondition`(model 层)Stage B 删。

- [ ] **Step 3: 从 Xcode 工程移除文件引用 + 编译**

> SwiftPM 自动纳入目录文件;若是 .xcodeproj,需从 project.pbxproj 移除已删文件引用。先编译看是否报缺文件:

Run: `cd PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|Build input file cannot be found|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`。若报 "Build input file cannot be found",编辑 `PropertyAtlas.xcodeproj/project.pbxproj` 删除对应 5 个文件的 PBXBuildFile/PBXFileReference 条目后重编。

- [ ] **Step 4: 提交**

```bash
git add -A PropertyAtlas
git commit -m "feat(settings): drop theme/style/palette tabs (8->5 tabs)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 10: ViewSettingsTab 加 默认样式 + 调色板 + 图例 三区

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Settings/ViewSettingsTab.swift`
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/Components/EntityDefaultStyleEditor.swift`(默认样式子视图,保持文件 ≤300 行)

> 复用现有控件(`ColorHexField`、`StudioChip`、`StudioDisclosure`、`glassField`)。默认样式编辑 `ViewEntityStyle` 行(按需懒建);调色板编辑 `MapView.paletteHex`;图例 `MapView.showLegend`。改动直接 mutate + `updatedAt`。

- [ ] **Step 1: 默认样式编辑子视图**

`Studio/Settings/Components/EntityDefaultStyleEditor.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 单实体类型的视图默认样式编辑(ViewEntityStyle 一行)。空行 = builtin。
struct EntityDefaultStyleEditor: View {
    let datasetId: UUID
    let viewId: UUID
    let entityType: String
    let title: String
    @Environment(\.modelContext) private var context
    @State private var row: ViewEntityStyle?

    private let shapes = ["circle", "square", "hexagon", "diamond", "triangle", "star"]

    var body: some View {
        StudioDisclosure(title, summary: row?.fillHex ?? "默认", open: false) {
            let bound = ensureRow()
            if entityType != "area" {
                VStack(alignment: .leading, spacing: 6) {
                    Text("形状").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(shapes, id: \.self) { shape in
                                StudioChip(shape, isOn: bound.shape == shape) {
                                    bound.shape = (bound.shape == shape) ? nil : shape
                                    bound.updatedAt = Date()
                                }
                            }
                        }
                    }
                }
            }
            ColorHexField(title: "填充色", hex: hexBinding(bound, \.fillHex))
            ColorHexField(title: "描边色", hex: hexBinding(bound, \.strokeHex))
            Toggle("显示标签", isOn: Binding(
                get: { bound.labelVisible ?? false },
                set: { bound.labelVisible = $0; bound.updatedAt = Date() }
            ))
        }
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
        .onAppear { row = fetchRow() }
    }

    private func hexBinding(_ row: ViewEntityStyle, _ key: ReferenceWritableKeyPath<ViewEntityStyle, String?>) -> Binding<String> {
        Binding(
            get: { row[keyPath: key] ?? "" },
            set: { row[keyPath: key] = $0.isEmpty ? nil : $0; row.updatedAt = Date() }
        )
    }

    private func fetchRow() -> ViewEntityStyle? {
        let vid = viewId, et = entityType
        return (try? context.fetch(FetchDescriptor<ViewEntityStyle>(
            predicate: #Predicate { $0.viewId == vid && $0.entityType == et && !$0.deleted }
        )))?.first
    }

    private func ensureRow() -> ViewEntityStyle {
        if let row { return row }
        let created = ViewEntityStyle(datasetId: datasetId, viewId: viewId, entityType: entityType)
        context.insert(created)
        row = created
        return created
    }
}
#endif
```

- [ ] **Step 2: ViewSettingsTab 接入三区(用现有 `SettingsCard` + `mv`)**

`ViewSettingsTab.swift` body 内 `if let mv = viewContext.activeMapView {` 块中。结构现状:用 `SettingsCard("...") { ... }`,active view 变量名 `mv`。

(a) 在 `SettingsCard("视图")` 之后插入默认样式卡:

```swift
                SettingsCard("默认样式") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([("compound", "小区"), ("school", "学校"), ("poi", "POI"), ("area", "片区")], id: \.0) { type, label in
                            EntityDefaultStyleEditor(
                                datasetId: mv.datasetId, viewId: mv.id, entityType: type, title: label
                            )
                        }
                    }.padding(.horizontal, 13).padding(.bottom, 12)
                }
```

(b) 把 `SettingsCard("引用")` 内的「调色板」`SettingsRow`(现为 `Picker` 设 `mv.paletteId`)整段替换为内联色板编辑 + 图例开关。即把这段:

```swift
                    SettingsRow(title: "调色板") {
                        Picker("", selection: paletteBinding(mv)) {
                            Text("默认高对比").tag(UUID?.none)
                            ForEach(palettes.filter { !$0.deleted }, id: \.id) { Text($0.name).tag($0.id as UUID?) }
                        }.labelsHidden().tint(Studio.cool)
                    }
                    RowDivider()
```

替换为:

```swift
                    SettingsRow(title: "显示图例") {
                        Toggle("", isOn: Binding(
                            get: { mv.showLegend },
                            set: { mv.showLegend = $0; mv.updatedAt = Date() }
                        )).labelsHidden().tint(Studio.cool)
                    }
                    RowDivider()
```

(c) 在「引用」卡之后(或「默认样式」卡之后)加调色板卡:

```swift
                SettingsCard("分组染色调色板") {
                    PaletteHexEditor(view: mv).padding(.horizontal, 13).padding(.bottom, 12)
                }
```

(d) 删除文件顶部不再使用的 `@Query private var palettes: [Palette]` 与 `paletteBinding(_:)` 辅助方法(已无引用)。若编译报 `paletteBinding` 未用而非错误,可保留;以编译通过为准。

- [ ] **Step 3: 调色板编辑子视图(内联或同文件)**

在 `EntityDefaultStyleEditor.swift` 末尾(`#endif` 前)加简单色组编辑:

```swift
struct PaletteHexEditor: View {
    @Bindable var view: MapView

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(view.paletteHex.enumerated()), id: \.offset) { idx, _ in
                HStack {
                    ColorHexField(title: "颜色 \(idx + 1)", hex: Binding(
                        get: { view.paletteHex[idx] },
                        set: { view.paletteHex[idx] = $0; view.updatedAt = Date() }
                    ))
                    Button(role: .destructive) {
                        view.paletteHex.remove(at: idx); view.updatedAt = Date()
                    } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.plain)
                }
            }
            Button {
                view.paletteHex.append("#888888"); view.updatedAt = Date()
            } label: { Label("加颜色", systemImage: "plus") }
            .buttonStyle(.tbtn(.ghost))
        }
    }
}
```

> `@Bindable` 需 iOS 17+(已满足)。`.tbtn(.ghost)` 若不存在,用现有可用样式(读 `PaletteSettingsTab` 删除前的按钮样式确认;此处用 `.ghost`,如无则 `.secondary`)。

- [ ] **Step 4: 编译**

Run: `cd PropertyAtlas && xcodebuild build -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "error:|Build input file cannot be found|BUILD (SUCCEEDED|FAILED)" | head`
Expected: `** BUILD SUCCEEDED **`(新文件若 .xcodeproj 需加入 build phase —— 报 "cannot be found" 时编辑 pbxproj 加引用)

- [ ] **Step 5: 提交**

```bash
git add -A PropertyAtlas
git commit -m "feat(settings): view tab gains default-style + palette + legend editors

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 11: 清库重迁 + 既有库迁移双验证

**Files:** 无（验证任务）

> 验证两条路径:① 全新库(走 LegacyMigrator seed + StyleConsolidationMigrator)② 既有旧库(已有 theme/palette/override 数据)迁移后视觉不变、数据不丢。

- [ ] **Step 1: 全量测试 + lint**

Run: `cd PropertyAtlas && xcodebuild test -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' -derivedDataPath /tmp/pa-build 2>&1 | grep -E "TEST (SUCCEEDED|FAILED)" | tail`
Expected: `** TEST SUCCEEDED **`

Run: `cd /Users/fujie/projects/天津买房 && swiftlint lint --quiet PropertyAtlas/PropertyAtlas/RootView.swift PropertyAtlas/PropertyAtlas/MapRender/StyleResolver.swift PropertyAtlas/PropertyAtlas/DataKit/StyleConsolidationMigrator.swift PropertyAtlas/PropertyAtlas/MapRender/StyleFieldConvert.swift PropertyAtlas/PropertyAtlas/Models/Display/ViewEntityStyle.swift 2>&1 | grep -c error`
Expected: `0`(新增代码零 lint error;预存量另计)

- [ ] **Step 2: 既有库迁移验证(手动跑 app)**

启动 app(沿用 perf 调试方式):
```bash
open /tmp/pa-build/Build/Products/Debug-maccatalyst/PropertyAtlas.app
```
检查:① 各视图 pin/area 渲染与改动前一致(默认走 builtin,因 seed theme defaultStyles 为空 —— 学校 glyph/tier 配色消失属预期);② 设置页 5 tab;③ 视图 tab 能编辑 4 实体默认样式 + 调色板 + 图例开关,改动即时反映到地图;④ 选中实体编辑器「样式覆盖」能改并生效;⑤ 分组过滤(groupBy)时染色正常(paletteHex 已从旧 palette 搬入);⑥ 实体/边/标记/视图过滤数量不变(无数据丢失)。

- [ ] **Step 3: 更新 CLAUDE.md 记录(P10a Stage A)**

在 `CLAUDE.md` 实施计划列表加一行(指向本 plan),并加一段完成纪要:视图持有样式 Stage A —— ViewEntityStyle/typed override/paletteHex/showLegend + StyleConsolidationMigrator 幂等搬运;StyleRule/Theme/Palette @Model 保留待 Stage B。

- [ ] **Step 4: 提交**

```bash
git add CLAUDE.md
git commit -m "docs(claude): record view-owned style Stage A

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## 完成后

全部任务完成 → `superpowers:finishing-a-development-branch`。Stage B(删 StyleRule/Theme/Palette @Model + 旧列 + 死类型 + 迁移器)另开 spec/plan,**待 Stage A 在真机/真库验证无误后**再做。
