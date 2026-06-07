# Studio Settings 抽屉化 + 实体子tab + 玻璃质感 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Studio 设置从固定模态 `.sheet` 改为右侧浮动玻璃抽屉(宽=屏×0.382、上下占满、`.glassSurface()` 还原暗玻璃质感),并把含四大实体的配置改成实体子tab。

**Architecture:** 纯 UI/布局重构,零 schema/数据模型变更。三处改动:① `SettingsSheet` 去固定 frame + 手写 background,改用设计系统 `.glassSurface()` 充满容器;② `RootView` 删 `.sheet`,在主 `ZStack` 末尾挂带 scrim 的右侧抽屉层(`zIndex 40` + 滑入动画);③ `ViewSettingsTab` 的「默认样式 ×4 + 条件样式 ×4」八段堆叠抽成新 `ViewStyleSection`(`GlassSegmented` 实体子tab + 每实体 `.id` 重挂),`CustomFieldSettingsTab` 子tab 标签改中文。

**Tech Stack:** SwiftUI · SwiftData · Mac Catalyst (`#if targetEnvironment(macCatalyst)`)。视觉参考唯一 `design/Studio Mode (standalone).html`(暗玻璃语言,已由 `StudioTokens.swift`/`glassSurface()` 移植)。

**测试说明:** 本计划全为 SwiftUI 视图层重构,无新增可单测的纯逻辑(无 codec/算法)。沿用本仓 Settings UI 任务惯例:验证 = `xcodebuild` BUILD SUCCEEDED + `swiftlint lint` 0 error + 手动验收清单。不写无意义的视图快照测试。

**全局构建/校验命令(每个 Task 末尾用):**

```bash
cd /Users/fujie/projects/天津买房
xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' build 2>&1 | tail -5
# 期望末尾出现:** BUILD SUCCEEDED **
swiftlint lint --quiet <改动的文件路径...>
# 期望:无输出(0 violation)
```

---

### Task 1: SettingsSheet —— 玻璃外壳 + 充满容器

把设置面板自身从「固定 460×820 + 手写扁平 background」改为「填满父容器 + `.glassSurface()` 统一玻璃」。宽高由调用方(Task 2 的抽屉容器)决定。

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Settings/SettingsSheet.swift:28-52`

- [ ] **Step 1: 替换 body 的 frame + 背景修饰**

把当前 `body`(`SettingsSheet.swift:28-52`)中从 `.padding(.top, 16)` 起到 `.tint(Studio.cool)` 的尾部修饰整段替换。

原(待删):

```swift
        .padding(.top, 16)
        .frame(width: 460, height: 820)
        .background(Studio.glassStrong)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Studio.rSheet, style: .continuous))
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
```

新:

```swift
        .padding(.top, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .glassSurface(Studio.glassStrong, radius: Studio.rSheet, elevation: .pop)
        .environment(\.colorScheme, .dark)
        .tint(Studio.cool)
```

要点:`.glassSurface(...)` 内部已含 `.ultraThinMaterial` + 暗色 tint + 顶部 rim 高光 + 外缘 0.5px 暗边 + `.pop` 级阴影(radius 26 / y 18),并自带 `RoundedRectangle(cornerRadius: radius)` 裁剪形状 —— 故删掉原 `.background(...).background(...).clipShape(...)` 三连。`.frame(maxWidth/Height: .infinity)` 让面板撑满 Task 2 的抽屉框。

- [ ] **Step 2: 构建 + 校验**

```bash
cd /Users/fujie/projects/天津买房
xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' build 2>&1 | tail -5
swiftlint lint --quiet PropertyAtlas/PropertyAtlas/Studio/Settings/SettingsSheet.swift
```

期望:`** BUILD SUCCEEDED **`;swiftlint 无输出。
(此时设置仍由旧 `.sheet` 弹出,但已撑满 sheet 容器并带玻璃壳——Task 2 才改成抽屉。)

- [ ] **Step 3: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/SettingsSheet.swift
git commit -m "$(cat <<'EOF'
refactor(settings): SettingsSheet fill container + unified glassSurface shell

Drop fixed 460x820 frame and hand-rolled background/clipShape; use the
shared .glassSurface(.pop) so the panel matches every other Studio
surface (rim highlight + dark edge + elevation). Fills parent container
(drawer frame supplied by RootView next).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: RootView —— 设置改右侧浮动抽屉(去 .sheet)

删掉 `.sheet(isPresented:$showSettings)`,在 `StudioRootView` 主 `ZStack` 末尾加「scrim + 右侧抽屉」层,宽 = 屏宽 × 0.382,上下占满,`zIndex(40)` 浮于一切之上,滑入/淡入动画,点 scrim 或「完成」关闭。

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/RootView.swift:233-271`(主 ZStack 收尾 + 删 `.sheet`)

- [ ] **Step 1: 删除旧 `.sheet(isPresented:$showSettings)` 块**

删 `RootView.swift:267-271`:

```swift
        .sheet(isPresented: $showSettings) {
            if let ctx = viewContext {
                SettingsSheet(viewContext: ctx, onClose: { showSettings = false })
            }
        }
```

整段删除(连同前导换行)。

- [ ] **Step 2: 在主 ZStack 内、左抽屉块之后插入设置抽屉层**

定位 `RootView.swift:218-232` 的左抽屉块(`if !exportMode { HStack { LeftDrawerView(...) ... } }`),在其**闭合 `}` 之后、ZStack 的 `}` 之前**插入:

```swift
            // 设置抽屉:右侧浮层,宽=屏×0.382,上下占满,浮于一切之上。
            // 点 scrim / 完成 关闭。出图模式下隐藏(与其它 chrome 一致)。
            if !exportMode, showSettings, let ctx = viewContext {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { showSettings = false }
                    .transition(.opacity)
                    .zIndex(39)

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        SettingsSheet(viewContext: ctx, onClose: { showSettings = false })
                            .frame(width: geo.size.width * 0.382)
                            .padding(.top, 40)
                            .padding(.bottom, 16)
                            .padding(.trailing, 16)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(40)
            }
```

要点:scrim 与抽屉是 `if` 下两个并列子视图,各自带 `.transition`(scrim 淡入、抽屉右滑入);`GeometryReader` 取屏宽算 0.382;`SettingsSheet` 已在 Task 1 撑满,这里给定宽 + 三向 padding 决定其位置与高度(上 40 / 下 16,即"上下基本占满")。

- [ ] **Step 3: 给主 ZStack 加 showSettings 动画**

定位主 ZStack 现有的 `.animation(.easeInOut(duration: 0.22), value: exportMode)`(`RootView.swift:234`),在其**下一行**追加:

```swift
        .animation(.easeInOut(duration: 0.25), value: showSettings)
```

这样工具栏 ⚙️ 把 `showSettings` 置 true/false 时,上面 `if` 子树的插入/移除按声明的 transition 平滑过渡,无需改 `StudioToolbar`。

- [ ] **Step 4: 构建 + 校验**

```bash
cd /Users/fujie/projects/天津买房
xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' build 2>&1 | tail -5
swiftlint lint --quiet PropertyAtlas/PropertyAtlas/RootView.swift
```

期望:`** BUILD SUCCEEDED **`;swiftlint 无输出。

- [ ] **Step 5: 手动验收(Catalyst 运行)**

运行 app → 点工具栏 ⚙️。预期:抽屉从右滑入,宽≈屏 38.2%,顶到顶部 40pt、底到 16pt;面板有 material 模糊透出地图 + 顶部高光 + 外缘暗边 + 阴影层次(与左抽屉/EntityCard 并排观感一致);地图仍可见可操作;点面板外半透明区域或「完成」→ 滑出关闭。

- [ ] **Step 6: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/RootView.swift
git commit -m "$(cat <<'EOF'
feat(settings): present Settings as right-side glass drawer, drop .sheet

Settings now floats as a 38.2%-width right drawer (top 40 / bottom 16),
zIndex 40 above all chrome, with a tap-scrim and slide+fade transition
driven by an animation keyed to showSettings. Map stays visible so style
edits reflect live. Removes the old fixed modal sheet.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: ViewStyleSection —— 视图 tab 底部样式区(实体子tab)

新建 `ViewStyleSection`:`GlassSegmented` 四实体子tab(小区/学校/POI/片区),选中实体下并列展示「默认样式」(`EntityDefaultStyleEditor`)+「条件样式」(`ViewStyleRulesSection`)。每实体内容 `.id("\(mv.id)#\(styleEntity)")` 重挂,以触发两子组件的 `.onAppear` 重取(二者均只在 onAppear 取数,切换 param 不会自动刷新)。

**Files:**
- Create: `PropertyAtlas/PropertyAtlas/Studio/Settings/Components/ViewStyleSection.swift`
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Settings/ViewSettingsTab.swift:23-49`(删两张旧样式卡,改调 `ViewStyleSection`)

- [ ] **Step 1: 新建 ViewStyleSection.swift**

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

/// 视图 tab 底部「样式」区:实体子tab(小区/学校/POI/片区),
/// 选中实体下并列「默认样式」+「条件样式」。
/// 两子组件仅在 onAppear 取数,故内容按 view×entity 加 .id 重挂以刷新。
struct ViewStyleSection: View {
    let mv: MapView
    @State private var styleEntity: String = "compound"

    private let entities: [(value: String, label: String)] = [
        (value: "compound", label: "小区"),
        (value: "school", label: "学校"),
        (value: "poi", label: "POI"),
        (value: "area", label: "片区")
    ]

    var body: some View {
        SettingsCard("样式") {
            VStack(alignment: .leading, spacing: 12) {
                GlassSegmented(options: entities, selection: $styleEntity)
                styleBody
                    .id("\(mv.id.uuidString)#\(styleEntity)")
            }
            .padding(.horizontal, 13).padding(.bottom, 12)
        }
    }

    private var label: String {
        entities.first { $0.value == styleEntity }?.label ?? ""
    }

    @ViewBuilder private var styleBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "默认样式")
                EntityDefaultStyleEditor(
                    datasetId: mv.datasetId, viewId: mv.id,
                    entityType: styleEntity, title: label
                )
            }
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "条件样式")
                ViewStyleRulesSection(
                    datasetId: mv.datasetId, viewId: mv.id, entityType: styleEntity
                )
            }
        }
    }
}
#endif
```

要点:`GlassSegmented(options:selection:)` 签名见 `StudioControls.swift:68`(`options: [(value:T,label:String)]`)。`.id("\(mv.id)#\(styleEntity)")` 同时覆盖「切视图」与「切实体」两种刷新需求(原代码用 `.id(mv.id)` 仅覆盖切视图)。`EntityDefaultStyleEditor`/`ViewStyleRulesSection` 签名见各自文件,参数原样。

- [ ] **Step 2: 在 ViewSettingsTab 用 ViewStyleSection 替换两张旧样式卡**

把 `ViewSettingsTab.swift:23-49` 这两张卡整段删除:

```swift
                SettingsCard("默认样式") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(
                            [("compound", "小区"), ("school", "学校"), ("poi", "POI"), ("area", "片区")],
                            id: \.0
                        ) { entityType, label in
                            EntityDefaultStyleEditor(
                                datasetId: mv.datasetId, viewId: mv.id, entityType: entityType, title: label
                            )
                        }
                    }.padding(.horizontal, 13).padding(.bottom, 12)
                }
                .id(mv.id)
                SettingsCard("条件样式") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(
                            [("compound", "小区"), ("school", "学校"), ("poi", "POI"), ("area", "片区")],
                            id: \.0
                        ) { type, label in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(label).font(Studio.sans(12, .semibold)).foregroundStyle(Studio.on)
                                ViewStyleRulesSection(datasetId: mv.datasetId, viewId: mv.id, entityType: type)
                            }
                        }
                    }.padding(.horizontal, 13).padding(.bottom, 12)
                }
                .id(mv.id)
```

替换为单行:

```swift
                ViewStyleSection(mv: mv)
```

放置位置不变(仍在 `SettingsCard("视图")` 之后、`SettingsCard("分组染色调色板")` 之前),保持"视图级卡在上、样式区在中下"。

- [ ] **Step 3: 构建 + 校验(含行数检查)**

```bash
cd /Users/fujie/projects/天津买房
xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' build 2>&1 | tail -5
swiftlint lint --quiet \
  PropertyAtlas/PropertyAtlas/Studio/Settings/Components/ViewStyleSection.swift \
  PropertyAtlas/PropertyAtlas/Studio/Settings/ViewSettingsTab.swift
wc -l PropertyAtlas/PropertyAtlas/Studio/Settings/ViewSettingsTab.swift
```

期望:`** BUILD SUCCEEDED **`;swiftlint 无输出;`ViewSettingsTab.swift` 行数较原 282 明显下降(约 245),稳在 300 以内。

- [ ] **Step 4: 手动验收**

视图 tab → 滚到「样式」卡:顶部四实体分段;切「学校」应看到默认样式 disclosure + 条件样式规则列表(含已迁移的 重/区/普 规则);切到「小区/POI/片区」内容随之刷新(不残留上一个实体的行);改填充色即时反映到地图(抽屉不挡)。切换视图(顶部视图切换器)后样式区重置为对应视图数据。

- [ ] **Step 5: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/Components/ViewStyleSection.swift \
        PropertyAtlas/PropertyAtlas/Studio/Settings/ViewSettingsTab.swift
git commit -m "$(cat <<'EOF'
feat(settings): entity sub-tabs for view style (default + conditional)

Collapse the 8 stacked style cards (default x4 + conditional x4) into a
single 样式 region with a GlassSegmented entity sub-tab. Per-entity
content is re-mounted via .id(view#entity) so the onAppear-only fetches
in EntityDefaultStyleEditor / ViewStyleRulesSection refresh on switch.
Trims ViewSettingsTab back under the 300-line cap.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: CustomField tab —— 实体子tab 标签中文化

字段 tab 已是 `GlassSegmented` + `@State entityType` 实体子tab,仅标签是英文 value。改成与样式子tab 一致的中文标签(小区/学校/POI/片区),逻辑不动。

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas/Studio/Settings/CustomFieldSettingsTab.swift:22-25`

- [ ] **Step 1: 中文标签**

把 `CustomFieldSettingsTab.swift:22-25` 的:

```swift
            GlassSegmented(
                options: entityTypes.map { (value: $0, label: $0) },
                selection: $entityType
            )
```

替换为:

```swift
            GlassSegmented(
                options: entityTypes.map { (value: $0, label: Self.entityLabel($0)) },
                selection: $entityType
            )
```

并在 `CustomFieldSettingsTab` 内(`entityTypes` 常量声明之后)加一个静态映射:

```swift
    private static func entityLabel(_ type: String) -> String {
        switch type {
        case "compound": "小区"
        case "school": "学校"
        case "poi": "POI"
        case "area": "片区"
        default: type
        }
    }
```

要点:`entityTypes = ["compound","school","poi","area"]`(已存在,`CustomFieldSettingsTab.swift:12`),映射顺序与之一致,与样式子tab 标签统一。

- [ ] **Step 2: 构建 + 校验**

```bash
cd /Users/fujie/projects/天津买房
xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' build 2>&1 | tail -5
swiftlint lint --quiet PropertyAtlas/PropertyAtlas/Studio/Settings/CustomFieldSettingsTab.swift
```

期望:`** BUILD SUCCEEDED **`;swiftlint 无输出。

- [ ] **Step 3: 手动验收**

字段 tab → 子tab 显示「小区/学校/POI/片区」中文;切换正常列出对应实体自定义字段,增删字段照常。

- [ ] **Step 4: 提交**

```bash
git add PropertyAtlas/PropertyAtlas/Studio/Settings/CustomFieldSettingsTab.swift
git commit -m "$(cat <<'EOF'
feat(settings): Chinese labels for customField entity sub-tabs

Match the view style sub-tab labels (小区/学校/POI/片区) instead of raw
English entity-type values. Logic unchanged.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 终检 —— 全量构建 + 全 tab 回归 + 玻璃并排核对

**Files:** 无(仅验证)。

- [ ] **Step 1: 全量构建 + 单元测试(确认未破坏现有)**

```bash
cd /Users/fujie/projects/天津买房
xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -only-testing:PropertyAtlasTests test 2>&1 | tail -15
```

期望:`** TEST SUCCEEDED **`(仅跑 `PropertyAtlasTests` 单测,避开 UITest 的环境性失败)。

- [ ] **Step 2: 手动回归清单(Catalyst 运行)**

- 抽屉:⚙️ 右滑入,宽≈38.2%,上下占满;玻璃壳与左抽屉/EntityCard 观感一致(模糊/高光/暗边/阴影);scrim + 完成 关闭。
- 视图 tab:视图级卡在上;样式区四实体子tab 切换刷新;改色即时上图。
- 字段 tab:中文子tab,增删正常。
- 图层 / 枚举 / 相机 tab:照常显示与编辑,无折行(picker 仍单行)。
- 切换视图:样式区/过滤随视图刷新。

- [ ] **Step 3: 无新提交(全部已在 Task 1–4 提交)**

若手动验收发现问题,回到对应 Task 修复后再提交;否则本计划完成。

---

## Self-Review

- **Spec 覆盖**:① 抽屉化 → Task 2;② 玻璃质感(硬要求)→ Task 1 + Task 5 并排核对;③ 实体子tab(视图样式)→ Task 3;④ 字段 tab 子tab → Task 4;⑤ 拆分降行数 → Task 3(新 `ViewStyleSection`);⑥ 图层/枚举/相机不动 → 未触碰,Task 5 回归确认。全覆盖。
- **占位扫描**:无 TBD/TODO;每步含完整代码或精确命令 + 期望输出。
- **类型一致**:`ViewStyleSection(mv:)`、`GlassSegmented(options:selection:)`、`EntityDefaultStyleEditor(datasetId:viewId:entityType:title:)`、`ViewStyleRulesSection(datasetId:viewId:entityType:)`、`SettingsSheet(viewContext:onClose:)`、`.glassSurface(_:radius:elevation:)` 均与现有签名一致。
