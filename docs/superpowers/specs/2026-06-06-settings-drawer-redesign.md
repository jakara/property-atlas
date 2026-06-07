# Studio Settings 抽屉化 + 实体子tab 重设计

> 设计稿。范围:纯 UI/布局重构,无 schema / 数据模型变更。Mac Catalyst only。
>
> **视觉参考(唯一)**:`design/Studio Mode (standalone).html` —— Studio 暗玻璃设计画布(地图 + 浮动 toolbar + 抽屉 + 卡片)。该文件无独立设置屏;它定义的暗玻璃语言已由 `StudioTokens.swift` + `glassSurface()` 一比一移植。本次还原对象 = 此玻璃语言(material 模糊 + rim 高光 + 暗边 + 分级阴影 + amber/cool 双强调 + 收敛圆角/字阶)。不参考 iOS 浅色设置稿(`settings-operator.html`)。

## 背景与问题

当前 `SettingsSheet` 是 `.sheet` 模态(`RootView:267`),固定 460×820。5 段 tab(视图/图层/枚举/相机/字段),每 tab = `ScrollView` 卡片流。痛点:

- **挤**。视图 tab 把「默认样式 ×4 实体」+「条件样式 ×4 实体」共 8 段纵向堆叠,加上视图级 8 张卡,滚动极长。
- 模态遮挡地图,改样式时看不到画布即时效果。
- **玻璃质感缺失**(用户重点反馈)。Studio 全部浮层(`StudioToolbar`/`LeftDrawerView`/`EntityCard`/`EntityEditor`/`StudioSearchPanel`/`ExternalPlaceCard`)统一走 `.glassSurface(...)` —— material 模糊 + 顶部 rim 高光 + 外缘 0.5px 暗边 + 2 级 elevation 阴影。**唯独 `SettingsSheet` 没用**,而是手写 `.background(Studio.glassStrong).background(.ultraThinMaterial)`,缺 rim/edge/shadow,显得扁平、与设计系统不一致,不是 100% 还原。

## 目标

1. 设置由模态 `.sheet` 改为**右侧浮动抽屉**,宽 = `屏宽 × 0.382`,上下基本占满。开着也能看见/操作地图。
2. 保持 5 个一级 tab 不变。
3. tab 内凡含「四大实体(小区/学校/POI/片区)」的配置,改为**实体子tab**(二级 `GlassSegmented`),切实体而非纵向堆 4 份。
4. 顺带把超长的 `ViewSettingsTab`(282 行,逼近 300 上限)按职责拆分。

## 设计

### 1. 抽屉化(RootView + SettingsSheet)

- **RootView**:删 `.sheet(isPresented:$showSettings)`。在 `StudioRootView` 的根 `ZStack` 内,地图等之上加设置层:
  - 半透明点击 scrim(`Color.black.opacity(~0.12)`,`ignoresSafeArea`,点击 = `showSettings=false`),仅 `showSettings` 时插入。
  - 设置抽屉:trailing 贴边,`width = geo.size.width * 0.382`(与右抽屉同宽逻辑;不减 16,贴右边),`padding(.top, 40)`+`padding(.bottom, 16)`,`zIndex(40)`(高于 toolbar 30 / 右抽屉 5)。
  - 用 `.transition(.move(edge: .trailing))` + `withAnimation` 滑入滑出。scrim 用 `.opacity` 过渡。
  - `geo` 取自现有外层 `GeometryReader`(RootView 已有 `geo`);若 `StudioRootView` body 无 GeometryReader 包裹根 ZStack,则新增一层 `GeometryReader` 仅供宽度计算(不改其它布局)。
- **SettingsSheet**:
  - 删固定 `.frame(width:460,height:820)`,改 `.frame(maxWidth:.infinity, maxHeight:.infinity)` 充满抽屉容器。
  - 保留 header(标题「设置」+「完成」)、`segTabs`、内容 `ScrollView`。
  - **玻璃质感修复(本次核心)**:删手写 `.background(Studio.glassStrong).background(.ultraThinMaterial).clipShape(...)`,改用设计系统统一的 `.glassSurface(Studio.glassStrong, radius: Studio.rSheet, elevation: .pop)` —— 与 `ExternalPlaceCard`/`StudioSearchPanel` 一致(material 模糊 + rim 高光 + 外缘暗边 + `.pop` 阴影 radius 26/y 18)。`.environment(\.colorScheme,.dark)` + `.tint(Studio.cool)` 保留。
  - `完成` 按钮 `onClose` 不变(置 `showSettings=false`,由调用方动画包裹)。

> **玻璃质感是本次硬要求**:抽屉外壳必须经 `.glassSurface()`,不得回退手写 background。验收时与 `EntityCard`/搜索面板并排观感一致(同样的边缘高光、暗边、投影层次)。卡片内仍用 `Studio.glassInput` inset well(设计系统 `.card` 本就无 rim,正确)。

> 与现有右抽屉(图例/图层)同宽同位:设置抽屉 `zIndex(40)` 浮其上,开启时覆盖右抽屉区域,`完成`/scrim 关闭后恢复。可接受(设置本就是临时态)。

### 2. 实体子tab 模式(复用 `GlassSegmented`)

`GlassSegmented(options:selection:)` 已存在(`CustomFieldSettingsTab` 在用)。统一用它做二级实体切换,顺序固定 `小区/学校/POI/片区`(value: `compound/school/poi/area`)。

#### 2a. 视图 tab —— 样式区在底部(已选布局)

`ViewSettingsTab` 重排为:**视图级卡(上) + 样式区(下)**。

- **视图级卡(原样保留,顺序略整)**:视图切换器 → 视图(名称)→ 可见类型 → 启用图层 → 分组染色调色板 → 出图文案 → 引用(显示图例/相机/选中聚光)→ 主过滤·分组染色 → 普通过滤。
- **样式区(新)**:一条 `SectionLabel("样式")` + `GlassSegmented` 实体子tab(`@State styleEntity`)。选中实体下展示该实体的:
  - 「默认样式」`EntityDefaultStyleEditor(datasetId:viewId:entityType:title:)`
  - 「条件样式」`ViewStyleRulesSection(datasetId:viewId:entityType:)`
  - 二者套在带标题的子卡里。
- 删除原「默认样式」`ForEach ×4` 与「条件样式」`ForEach ×4` 两张大卡 —— 由子tab 单实体视图取代。
- `styleEntity` 状态在视图切换(`viewContext.activeMapView?.id` 变化)时**保留**当前实体选择即可(无需重置);样式编辑器内部已靠 `.id(mv.id)` 刷新。

**拆分**(降 `ViewSettingsTab` 行数 + 单一职责):
- 新增 `ViewStyleSection.swift`:`struct ViewStyleSection { let mv: MapView }` —— 内含 `@State styleEntity` + `GlassSegmented` + 选中实体的默认/条件样式两子卡。`ViewSettingsTab` 末尾调用 `ViewStyleSection(mv: mv)`。
- 视图级过滤部分(`normalFiltersSection` + primary)已是私有方法,留在 `ViewSettingsTab` 不动。

#### 2b. 字段 tab(customField)

已是实体子tab 形态(`GlassSegmented` + `@State entityType`)。仅把硬编码的 `GlassSegmented(options: entityTypes.map{(value:$0,label:$0)})` 标签由英文 value 改中文(`小区/学校/POI/片区`),与视图 tab 样式子tab 标签一致。逻辑不动。

#### 2c. 图层 / 枚举 / 相机 tab

无四实体维度,**不加实体子tab**。保持现状(抽屉宽度自适应即可)。

### 3. 不变量

- 无 `@Model` / schema / 迁移变更。
- 渲染管线、`StudioRenderCache`、内容签名不受影响(仅设置 UI 容器与编辑器排布变化;编辑器写库逻辑原样)。
- 所有编辑仍 `mutate + updatedAt`,软删 `deleted=true`。
- SwiftLint:无 1–2 字符标识符;每文件 ≤300 行(拆分后 `ViewSettingsTab` 应明显低于)。

## 验证

- 构建 `BUILD SUCCEEDED`;改动文件 `swiftlint lint` 0 error。
- 手验(Catalyst):⚙️ → 抽屉从右滑入,宽≈屏 38.2%,上下占满;地图可见;点 scrim / 完成 关闭。
- **玻璃质感**:抽屉外壳有 material 模糊透出地图、顶部 rim 高光、外缘暗边、`.pop` 投影层次;与左抽屉/EntityCard/搜索面板并排观感一致。
- 视图 tab:视图级卡在上,底部样式区切 4 实体,默认+条件样式随实体切换;改色即时反映到地图(抽屉不挡)。
- 字段 tab:实体子tab 中文标签,增删字段正常。
- 图层/枚举/相机:照常。
- 全 tab 滚动顺畅,无折行(picker 仍 `lineLimit(1).fixedSize`)。

## 后续(不在本次)

- Stage B 删旧 @Model 等(独立 plan)。
