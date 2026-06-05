# Studio 搜索入口 设计

**日期**: 2026-06-05
**范围**: 仅 Studio Mode (Mac Catalyst)。纯 additive,无 schema 变更。

## 目标

Studio 内加一个搜索入口,快速定位地点。两块、分开、都要:

1. **库内搜索** — 找当前数据集已有实体(小区/学校/POI/片区),选中 → 地图飞到该点 + 选中显 EntityCard。
2. **外部搜索** — Apple `MKLocalSearch` 找现实世界任意地点,选中 → 飞相机 + 临时标记,可一键在该点建实体(默认 POI)。

## 与既定设计的关系

当前方向 spec `2026-05-28-generic-map-tool-design.md`:
- §6.4 (line 599/834/933): 规定了「外部 POI 搜索创建」走 top toolbar + `MKLocalSearch`(高德先不引入,Apple 覆盖大陆主流地点),结果选中自动填 name/lat/lon、默认类型 POI。本设计的**外部块**即落地此项。
- line 105: 实体有 `aliases: [String]`「搜索辅助」字段(已在 4 个 @Model 落地)→ 库内匹配纳入 aliases。

本设计在 spec 的「外部 POI 搜索」之上**叠加库内实体搜索**(additive,不冲突)。属 P3.5 延后项「POI 外部搜索」的兑现 + 扩展。

## 入口形态

方案 A:`StudioToolbar` 加放大镜按钮(🔍,⌘F)→ 弹出玻璃搜索面板。贴合现有 floating chrome + dock 范式;出图模式(exportMode)随 dock 一并隐藏,不占常驻空间。

面板视觉复用现有 `EditorRelationsTab` 玻璃 picker 范式:`glassSurface(Studio.glassStrong, radius: rPanel, elevation: .pop)`,`width ~360`,`environment(\.colorScheme, .dark)`,`tint(Studio.cool)`。

面板结构(上→下):
1. 标题行「搜索」+ 关闭按钮(`.tbtn(.ghost)`)。
2. `GlassSegmented`「库内 / 外部」分段(`@State searchScope`)。
3. `TextField`(`glassField`),`@State query`,实时驱动结果。
4. 结果 `ScrollView`(固定高 ~240),每行一个结果。

## ① 库内搜索

### 纯逻辑 `EntitySearch`(新,有单测)

```swift
struct EntitySearch {
    struct Searchable {
        let ref: EntityRef
        let name: String
        let aliases: [String]
        let address: String?
        let category: String?
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
    }
    struct Hit: Identifiable {
        let ref: EntityRef
        let name: String
        let subtitle: String        // 命中来源(类型 · 地址/分类),供行副标题
        let coordinate: CLLocationCoordinate2D
        let hasCoordinate: Bool
        var id: UUID { ref.id }
    }
    /// 大小写无关子串匹配 name/aliases/address/category。
    /// 排序:name 前缀命中 > name 子串命中 > 其它字段命中;同级按 name 升序。空 query → []。
    static func search(_ query: String, in items: [Searchable], limit: Int = 50) -> [Hit]
}
```

匹配规则:
- 去首尾空白;空 → 返回 `[]`(不列全部,避免噪声)。
- 命中判定:`name` / 任一 `alias` / `address` / `category` 经 `localizedCaseInsensitiveContains(q)`。
- 排序权重:`name` 前缀(`localizedStandardRange ... lowerBound == start`)=0;`name` 含=1;别名含=2;address/category 含=3。同权按 `name` 本地化升序。
- `limit` 截断(默认 50),超出不显(列表底显「仅显示前 N 条,输入更精确」)。
- `subtitle` = `"<类型中文> · <address 或 category 或 别名命中词>"`,无附加信息时仅类型。

### 数据源

`StudioSearchPanel` 内 `@Query` 四类型 + active datasetId + `!deleted` 构建 `[Searchable]`(name/aliases/address/category/coordinate 直接读属性,不经 styleEntity)。逐键实时 `EntitySearch.search`。~1100 子串匹配,毫秒级,主线程可接受。

各类型字段映射:
- Compound: name, aliases, address, finishType→不计;category 取 `nil`(小区无 category)。
- School: name, aliases, address, category。
- POI: name, aliases, address, category。
- Area: name, aliases, category(无 address;coordinate 用 `CLLocationCoordinate2D()`,`hasCoordinate=false`)。

Area 无点坐标 → 命中可列出,但「飞相机」对 area 用其几何中心(若 `EntityReader` 能给中心)或退化为不飞、仅选中。MVP:area 命中仅选中(显 EntityCard),不飞相机(无可靠点)。

### 选中动作

行点击 → 回调 `onPickEntity(ref, coordinate, hasCoordinate)`:
- RootView 设 `appState.select(ref)` → EntityCard 弹出。
- `hasCoordinate` 为真 → 设 `camera = MKMapCamera(lookingAtCenter: coord, fromDistance: 2000, pitch: 0, heading: 0)`,复用现有 preset 机制(`updateUIView` 检测 `cameraEquals` 变化 → `setCamera(animated:)`)。
- 关闭面板(`showSearch = false`)。

## ② 外部搜索

### `ExternalPlaceSearch`(新)

```swift
struct ExternalPlaceSearch {
    struct PlaceHit: Identifiable {
        let id = UUID()
        let name: String
        let subtitle: String        // placemark 简短地址
        let coordinate: CLLocationCoordinate2D
    }
    /// MKLocalSearch.Request:naturalLanguageQuery = query,region = 当前视口(偏置结果)。
    /// async;失败/无网 → 抛错或返回 []。
    static func search(_ query: String, region: MKCoordinateRegion?) async throws -> [PlaceHit]
}
```

- `MKLocalSearch.Request().naturalLanguageQuery = query`;`request.region = region ?? 天津默认 region`。
- `name` = `mapItem.name`;`subtitle` = `placemark` 拼地址(`thoroughfare`/`locality` 等);`coordinate` = `placemark.coordinate`。
- 防抖:query 变化后 ~0.3s 再发请求(避免逐键打 API + 速率限制);面板存 `@State externalHits` + `@State searching`。
- 无网/失败:列表区显「外部搜索需联网,或稍后重试」。

### 选中动作

行点击 → 回调 `onPickExternal(placeHit)`:
- RootView 设 `camera` 飞到 `coordinate`(同上)。
- 设 `@State searchMarker: SearchMarker?`(coordinate + name)→ 注入地图作临时标记。
- 不自动关面板(便于继续看结果/建实体);提供面板内关闭。

### 临时标记

`SearchMarker`(轻量,非 @Model):`{ coordinate, name }`。RootView body 里把它转成一个区别于实体 pin 的 annotation,拼到传给 `MapContainerView` 的 annotations:`cache.pins + markerAnnotations`。

- 复用 `PinAnnotation` 但用一个固定的醒目 `PinStyle`(如 amber 大圆点 + label = name),`entityType = "__searchMarker"`,`entityId` = 固定占位 UUID。
- `annotationSignature` 自然涵盖(含坐标/style/name)。
- `onSchoolSelect`(点 pin)对 `__searchMarker` 跳过 select(idKind 不识别该类型 → 现有逻辑 else 分支会 clearSelection;需特判:点 searchMarker 不清选中,而是无操作或触发「建」)。MVP:点 searchMarker 无 select 行为;建实体走面板行内「＋建」按钮。
- `searchMarker = nil` 时移除(切视图/关搜索/建完实体后清)。

### 建实体

外部结果行右侧「＋建」按钮 → 回调 `onCreateAtExternal(placeHit)`:
- 设 `pendingCoordinate = placeHit.coordinate`,打开 `showCreateMenu`(现有 `CreateEntitySheet`)。
- `CreateEntitySheet` 增强:可选 `prefillName: String?`(= placeHit.name)、`defaultKind: EntityKind = .poi`(spec §6.4 默认 POI)。建实体时 name 预填、类型默选 POI、图层走现有选择。
- 建完 → 清 `searchMarker`,选中新实体(现有 createPin 已 `appState.select`)。

## 文件

新建(全 `#if targetEnvironment(macCatalyst)` 除纯逻辑可不限,但依赖 EntityRef/CLLocation,统一 Catalyst):
- `Studio/Search/StudioSearchPanel.swift` — 面板 UI(分段/输入/结果/防抖)。
- `MapRender/EntitySearch.swift` — 库内匹配纯逻辑(单测)。
- `Studio/Search/ExternalPlaceSearch.swift` — MKLocalSearch 包装。
- `Studio/Search/SearchMarker.swift` — 临时标记模型 + annotation 工厂(或并入 panel 文件,视行数)。

修改:
- `Studio/StudioToolbar.swift` — 加 🔍 按钮(`showSearch` binding,⌘F)。
- `RootView.swift` — `@State showSearch`、`@State searchMarker`;面板 sheet/popover;回调(飞相机/select/建);临时标记注入 annotations;`idKind`/`onSchoolSelect` 对 `__searchMarker` 特判。
- `Studio/CreateEntitySheet.swift` — 加 `prefillName`/`defaultKind` 可选参数(默认行为不变)。
- `Studio/StudioOverlay.swift`(若搜索面板由 overlay 承载)— 视实现挂载点。

## 测试

- `EntitySearch`:Swift Testing 单测 —— 空 query 返回空、name 前缀优先于子串、alias 命中、address/category 命中、大小写无关、limit 截断、排序稳定。
- `ExternalPlaceSearch`:网络层不单测(MKLocalSearch 真请求),手动验。可选:抽 `region` 构造为纯函数测默认 region 回退。
- 手动:库内搜中文名飞相机 + 显卡;外部搜地点飞 + 标记 + 建 POI 预填;离线外部提示;出图模式隐藏入口。

## 错误/边界

| 情况 | 处理 |
|---|---|
| 库内空 query | 结果空,提示「输入关键词」 |
| 库内无匹配 | 「未找到」 |
| 库内命中 area(无坐标) | 仅选中显卡,不飞相机 |
| 外部无网/失败 | 「外部搜索需联网或稍后重试」 |
| 外部空结果 | 「未找到地点」 |
| 重复发请求 | 0.3s 防抖 + 取消前一次(`Task` 取消) |
| 切视图/数据集 | 清 `searchMarker` + 关面板 |

## 明确不做(YAGNI / 延后)

- 高德 POI SDK(Apple 已覆盖,spec line 933 同)。
- 搜索历史 / 历史 chips(旧 iOS spec 有,本次不做)。
- `EditorRelationsTab` 内联搜索重构走 `EntitySearch`(可选 follow-up,避免 scope creep)。
- 拼音检索(本次按 name/aliases/address/category;拼音延后)。
- Explore (iPad) 模式搜索入口(仅 Studio)。
