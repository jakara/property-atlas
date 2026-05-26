# PropertyAtlas Studio Mode — 设计文档

**日期**：2026-05-26
**版本**：v1（产品方向转向："内容生产工具" 叠加在原私人看房 App 上）
**关联背景**：
- 原始 spec：`docs/superpowers/specs/2026-05-19-tianjin-house-design.md`
- 数据管线：`CLAUDE.md` Data Extraction Pipeline 章节
- 参考视觉：`reports/天津学校情况(4).pdf` P3 起的"和平区学片分布图"等

---

## 0. 摘要

PropertyAtlas 增加 **Studio Mode**，把现有 iPad 私人看房 App 扩展为可在 Mac 上生产**高专业度学区地图截图**的内容工具，配合发起者本人的公众号文章生产。

- **新增平台**：Mac Catalyst（macOS 14+），iPad/iPhone 不受影响
- **核心交互**：⌘⇧S 切换 explore/studio 模式；studio 模式下地图全屏 + 浮动标题/图例/水印/工具条
- **输出物**：4K PNG 截屏（6 种公众号常用画布比例）；录屏由外部 CleanShot / ScreenStudio 完成
- **几何渲染三段走**：Stage A 手描 raster overlay（18 区一次性校准）→ Stage B 学校点位凸包 → Stage C 街道/居委会 GeoJSON（长期）

不动 CloudKit、不动 usr_*/loc_*、不为非 Mac 平台编译 Studio 代码。

---

## 1. 项目目标与范围

### 1.1 用户与场景

**唯一用户**：项目发起者本人（内容创作者）。

**新增场景（本期）**：
- 在 Mac 上以 Studio 模式打开 PropertyAtlas
- 用预设镜头跳到目标区/学片
- 调整图层 / 学校粒度
- 编辑标题副标题
- 截屏（PNG 4K）或外部录屏
- 拖入公众号编辑器作图

**继承场景（不变）**：
- iPad 现场看房记录、跨设备同步（CloudKit 私有库）

### 1.2 当前最痛点

| 痛点 | 优先级 | MVP 是否覆盖 |
|------|-------|-------------|
| F. 内容生产时缺少高专业度学区地图模板 | 最高（本期新增） | ✅ |
| A. 信息散乱 | 高（已覆盖） | ✅（继承）|
| B. 学区对应不清 | 高（已覆盖） | ✅（继承）|
| D. 政策追踪 | 次要 | Phase 2 |
| E. 多维决策矩阵对比 | 次要 | Phase 2 |
| C. 通勤评估 | 跳过 | 不做 |

### 1.3 非目标

- ❌ 不做静态批量出图（所有图都通过交互+截屏方式产出）
- ❌ 不做应用内录屏（外部工具）
- ❌ 不做内容上传/发布到公众号（人工 drag-drop）
- ❌ 不做敏感数据图层的对外公开
- ❌ iPad 不加 Studio Mode（触控演示工具链不成熟，不值得）

---

## 2. 技术栈选型

继承原 spec，新增：

| 层 | 选择 | 理由 |
|----|------|------|
| 桌面平台 | Mac Catalyst（macOS 14+） | 现 SwiftUI 代码复用 ~95%；MapKit Mac 端可用；录屏工具链成熟 |
| 录屏 | 外部（CleanShot X / ScreenStudio） | Apple API 不如成熟工具；自做工作量大 |
| 地理编码 | Apple `CLGeocoder`（macOS） | 免第三方依赖；天津 POI 由 Apple+高德合作提供；批量离线脚本可控配额 |
| 凸包/alpha-shape | Python `shapely` + `alphashape` | 已有 venv，结果落 GeoJSON 走 App 端 `MKPolygon` |
| 截屏导出 | `MKMapSnapshotter` + SwiftUI `ImageRenderer` | 地图本体走系统 snapshotter，overlay 层走 SwiftUI 渲染再叠加 |

**为何 Mac Catalyst 而非 AppKit/Web**：见 brainstorming Q2 — 单人维护，复用现有 SwiftUI 代码价值最高。

---

## 3. 架构总览

### 3.1 应用形态
PropertyAtlas 增加 macOS Mac Catalyst target，与 iPadOS/iOS target 共用 SwiftUI 代码库。
- iPad / iPhone：Explore 模式唯一
- Mac：Explore + Studio 双模式
- CloudKit 仅 iPad 端启用（Mac 端 entitlement 不配，避免重复同步）

### 3.2 Studio Mode 全局开关
全局 `@Observable AppMode { case explore, studio }` 注入 `Environment`。
- 触发：菜单栏 `View → Studio Mode` / 快捷键 `⌘⇧S`
- `RootView` 根据 mode 走两套 ZStack 装配：
  - `.explore`：现 toolbar + drawer + wizard（不变）
  - `.studio`：地图全屏 + StudioOverlay（标题/图例/水印/工具条）

### 3.3 新增模块清单

```
PropertyAtlas/Studio/
  StudioMode.swift              # @Observable 全局状态
  StudioOverlay.swift           # 标题 + 图例 + 水印 + 工具条容器
  StudioToolbar.swift           # 底中浮条: 选区/选图层/截屏/画布比例
  StudioTitleCard.swift         # 左上 标题/副标题 TextField
  StudioLegend.swift            # 右上 学片 tier 4 色图例
  StudioWatermark.swift         # 右下 公众号水印
  CameraPresets.swift           # 18 区 + 101 学片 预设镜头位
  RasterAlignment/
    CalibratedImageOverlay.swift          # MKOverlay 子类
    CalibratedImageOverlayRenderer.swift  # MKOverlayRenderer 子类
  Layers/
    ZoneOverlayLayer.swift      # 学片几何渲染（stage 切换）
    ZoneCentroidAnnotation.swift# 学片名 tag
    SchoolPinLayer.swift        # 学校 pin
    SchoolAnnotationView.swift  # 自定义 pin view (形状/描金边/label)
  Snapshot/
    SnapshotExporter.swift      # 4K PNG 输出, 6 种画布比例
    CanvasAspect.swift          # 比例枚举: 16:9, 1:1, 4:5, 9:16, 3:4, 2:1
```

整体 ~15 个 swift 文件，每个文件目标 < 200 行，单 swift 文件 hard cap 300 行（CLAUDE.md 已有约束）。

Studio 代码全包 `#if targetEnvironment(macCatalyst)`：iPad/iPhone 编译时不参与，App 体积不变。

### 3.4 数据层 增量

新加字段（不破现 schema）：

```jsonc
// schools.json items 加:
{ "lat": 39.1234, "lon": 117.1234,
  "geocode_source": "CLGeocoder",
  "geocode_confidence": "address|name|manual|failed" }

// zones.json items 加:
{ "geometry_stage": "raster|hull|geojson",
  "geometry": {
    // stage=raster:
    "image": "和平区学片.png",
    "corners": [[lat,lon],[lat,lon],[lat,lon],[lat,lon]]
    // stage=hull|geojson:
    // GeoJSON Polygon "coordinates" 标准形式
  } }
```

`reports/extracted/schemas/schools.schema.json` 与 `zones.schema.json` 同步更新，enum 严格化，`scripts/validate.py` 校验 stage 与 geometry 形状匹配（oneOf 分支）。

Raster 资源不进 SwiftData，走 Bundle：
`PropertyAtlas/Resources/StudioRasters/和平区学片.png` ...（18 张，预估 PDF 切图各 1-2 MB，总计 ~30 MB 进 bundle，可接受）。

### 3.5 不做（架构层硬约束）

- ❌ Studio 不写 `pub_*`（只读消费）
- ❌ Studio 不写 `usr_*`（本期不引入看房标记的内容用法）
- ✅ Studio 可写 `loc_*`（仅相机预设覆盖项，本地 SwiftData，不同步 CloudKit）
- ❌ Studio 不与 CloudKit 交互（Mac 端不开 entitlement）
- ❌ 不为 Studio 加新 ModelContainer（复用现有 local container）
- ❌ 不动 `usr_*` 模型 schema（只是 Mac 端这层无数据）
- ❌ 不为非 Mac 平台编译 Studio 代码（`#if targetEnvironment(macCatalyst)`）

---

## 4. 数据流 & seed pipeline

### 4.1 新增脚本

```
scripts/
  geocode_schools.swift         # CLGeocoder 批量 822 学校地址 → lat/lon，写回 schools.json
  geocode_compounds.swift       # 同上, 174 楼盘（本期暂缓，留接口）
  build_zone_hulls.py           # Stage B: 按 zone_id 聚合 schools 算 convex/alpha hull → GeoJSON Polygon 写入 zones.json
  calibrate_raster.swift        # Stage A: 弹 MapKit + 半透明 raster + 4 个可拖红点；保存写入 zones.json
```

CLGeocoder 走 Swift 而非 Python：Apple 官方 API，无第三方依赖，配额走系统。失败地址落 `reports/extracted/geocode_failed.json` 供人工修。

### 4.2 完整数据重建流水线

在 CLAUDE.md 已有那串后追加：

```bash
# 已有的 7 步...
python3 scripts/build_public_md.py

# 新增（Studio 模式数据）:
swift scripts/geocode_schools.swift       # → schools.json + lat/lon (idempotent, 仅补 lat=nil 的)
swift scripts/calibrate_raster.swift 和平区  # 弹窗校准, 写一个区
# (18 区分别跑, 或一次跑全部)
python3 scripts/build_zone_hulls.py       # → zones.json (Stage B 升级, 覆盖 Stage A 之上的字段)
python3 scripts/validate.py
```

每脚本独立 idempotent。Stage 升级只覆盖那一区的 `geometry` 与 `geometry_stage` 字段。

### 4.3 App 端读取

`SeedImporter` 入口不变，新增 `ZoneGeometryImporter` 子模块：
- 读 zones.json `geometry_stage` 字段
- 按 stage 构造 `MKOverlay`：
  - `raster` → `CalibratedImageOverlay`（包 PNG bundle url + 4 角）
  - `hull` / `geojson` → `MKPolygon(coordinates:count:)`
- `School.lat/lon` 进 SwiftData（随 seed import）

### 4.4 Raster 校准工作流（Stage A 一次性人工）

1. 把 18 张区图（PDF 提取 PNG）扔 `Resources/StudioRasters/raw/`
2. 跑 `swift scripts/calibrate_raster.swift 和平区`
3. 脚本本身是独立的 macOS Swift Package（不走 Mac Catalyst），用 SwiftUI for macOS + MapKit 弹窗，叠半透明 raster + 4 个可拖红点
4. 调到对齐后按保存 → 写入 zones.json 该区 4 角经纬度
5. 18 区估计 1.5 天（每区 5 分钟左右）

---

## 5. 渲染管线

### 5.1 图层叠序（MKMapView, 底→顶）

```
0. Basemap         (自定义样式: POI 过滤, 路网淡化)
1. ZoneOverlay     (学片色块, alpha=0.35)
2. ZoneLabel       (学片名 tag, MKAnnotation)
3. SchoolPin       (学校 pin, MKAnnotationView)
4. SchoolLabel     (学校名, 与 pin 同 view 包)
```

`MKOverlayLevel.aboveRoads` 强制色块压在路网上。

### 5.2 底图样式（图层 G）

```swift
mapView.pointOfInterestFilter = .excludingAll
mapView.mapType = .mutedStandard
mapView.showsBuildings = false  // 减少视觉噪音
mapView.showsCompass = false
mapView.showsScale = false  // Studio 模式; Explore 模式保留
```

如 mutedStandard 仍不够安静，加一层 `MKTileOverlay` 子类返回淡灰 raster 覆盖默认底图（70% 透明），保留路网河流可识别。

### 5.3 Stage A — Raster overlay

```swift
class CalibratedImageOverlay: NSObject, MKOverlay {
    let image: UIImage
    let coordinate: CLLocationCoordinate2D
    let boundingMapRect: MKMapRect
    let corners: [CLLocationCoordinate2D]  // 4 角，仿射变换源
}

class CalibratedImageOverlayRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        // 4 个 corner 经纬度 → MKMapPoint → CGPoint
        // 计算仿射矩阵把 image 4 角映射到这 4 个 CGPoint
        // CGContextConcatCTM + CGContextDrawImage
    }
}
```

**精度约束**：zoom > 15 raster 糊。Studio 限定 zoom 范围 [11, 15]。超出 zoom 时 alpha 渐变到 0.1，浮"矢量边界尚未生成"提示。

### 5.4 Stage B — Convex hull

`scripts/build_zone_hulls.py`：

```python
from shapely.geometry import MultiPoint
import alphashape

for zone in zones:
    pts = [(s['lon'], s['lat']) for s in schools if s['zone_id'] == zone['id'] and s.get('lat')]
    if len(pts) < 3: continue
    hull = alphashape.alphashape(pts, alpha=0.5)  # 失败回退 MultiPoint(pts).convex_hull
    zone['geometry'] = {'type': 'Polygon', 'coordinates': [list(hull.exterior.coords)]}
    zone['geometry_stage'] = 'hull'
```

App 端 `MKPolygon(coordinates:count:)` + `MKPolygonRenderer`：
- fillColor: `tierTop/Good/Normal/Weak` alpha 0.35
- strokeColor: 同色 alpha 1.0, lineWidth 1.5

### 5.5 Stage C — 街道 GeoJSON（占位）

架构上同 Stage B（GeoJSON Polygon），只是顶点更精确。数据源待找（OpenStreetMap / 天地图 / 高德），本期不实现。

### 5.6 Pin 渲染（图层 B）

`SchoolAnnotation: MKAnnotation` + 自定义 `SchoolAnnotationView`：

| 属性 | 来源 | 表现 |
|---|---|---|
| 形状 | `level: primary/middle/jiunian` | ● / ▲ / ◆ |
| 填色 | 所属 zone 的 tier | `accent500` / tierTop/Good/Normal/Weak |
| 描边 | `is_market_key == true` | 2pt 金色 |
| label | `name` | pin 右侧, 11→13pt(studio), 白色 2pt 描边压底图 |
| priority | studio 模式 | `.required`（不裁切） |
| clustering | studio 模式 | 不聚合 |

### 5.7 ZoneCentroid (学片名 tag)

`ZoneCentroidAnnotation` 算 polygon 质心 → MKAnnotation：
- view: 圆角 4pt 实色 tier 背景 + 白字 12pt
- 质心被 pin 遮挡时手动微调 offset，CameraPresets 表里记一次每个 zone 的 labelOffset

### 5.8 Snapshot 渲染（图层 H）

```swift
let snapshotter = MKMapSnapshotter(options: ...)
snapshotter.start { snapshot in
    let base = snapshot.image  // 含 basemap + overlays
    let overlayImage = ImageRenderer(content: StudioOverlayForExport()).cgImage
    // CoreGraphics 叠加 overlay 到 base, 输出 PNG 4K
}
```

文件名：`和平区学片图_20260526_1530.png`
输出目录：`~/Pictures/PropertyAtlas/`

### 5.9 录屏

不做。Studio 模式优化 cursor / 字号 / 防抖即可：
- 关闭 hover 动画
- 字体加粗 1 档
- pin 大 1.15×
- 工具条带 hover hint 但 hint 不闪烁

---

## 6. Studio UI 细节

### 6.1 布局

```
┌─────────────────────────────────────────┐
│ [TitleCard]                             │  ← 左上 16pt
│  和平区学片分布图                       │
│  2026 招生季 · 更新于 2026-05-26        │
│                                         │
│         (地图)                          │
│                                  ┌─────┐│
│                                  │图例 ││  ← 右上 16pt
│                                  │顶尖 ││
│                                  │优质 ││
│                                  │普通 ││
│                                  │薄弱 ││
│                                  └─────┘│
│                                         │
│              ┌──────────────────────┐  ← 底中浮条
│              │ 🎯区 🗺️图层 📸 📐 ⚙️│
│              └──────────────────────┘  │
│ @公众号名 · PropertyAtlas               │  ← 右下 16pt
└─────────────────────────────────────────┘
```

### 6.2 StudioToolbar 按钮

| 按钮 | 行为 |
|---|---|
| 🎯 预设镜头 | 下拉 18 区 + 101 学片 → MKMapView setCamera 动画 0.8s |
| 🗺️ 图层 | 多选 toggle：学片色块 / 学校 pin / 学校名 / 集团连线（后期） / 楼盘（后期） |
| 🎚️ 学校粒度 | 全部 / 仅市重点 / 仅中学 / 仅小学 |
| 📸 截屏 | SnapshotExporter 输出 4K PNG |
| 📐 画布比例 | 16:9 / 1:1 / 4:5 / 9:16 / 3:4 / 2:1 |
| ⚙️ 设置 | 字号 / pin 大小 / 透明度 微调 |

工具条不进截屏（导出时 `StudioOverlayForExport` 不含 toolbar）。

### 6.3 标题 / 副标题 / 水印

- TitleCard：TextField，1 行主标题 + 1 行副标题
- 字体：SF Pro Display Bold（主）/ Regular（副），暖橘色 `accent500`
- 水印：默认 `@公众号名 · PropertyAtlas`；设置里可改；4pt 半透明黑（亮底）或白（暗底）

### 6.4 图例

固定 4 色 tier（顶尖/优质/普通/薄弱），下方滚动列出当前可见学片名。可关。

### 6.5 快捷键（Mac Catalyst）

| 键 | 行为 |
|---|---|
| `⌘⇧S` | 切 Studio / Explore |
| `⌘1..⌘6` | 跳市内六区（和平/河西/南开/河东/河北/红桥） |
| `⌘E` | 截屏 |
| `⌘L` | 切图层 panel |
| `⌘=` / `⌘-` | 缩放 |
| `空格 + 拖` | 平移 |

### 6.6 相机预设

```swift
struct CameraPreset: Identifiable, Codable {
    let id: String
    let name: String
    let center: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let pitch: CGFloat
    let heading: CLLocationDirection
    let labelOffset: CGSize?  // 学片名 tag 的微调
}
```

种子：18 区 + 101 学片预设，中心 = 该区/学片所有学校 lat/lon 均值，distance 按 bbox 自动算。
存 `loc_*` SwiftData 表（本地，不同步 CloudKit），用户可"保存当前镜头位"覆盖默认。

### 6.7 Studio 模式下隐藏

- DrawerContainerView
- WizardView
- ExploreToolbar
- Apple POI / 蓝点定位 / 罗盘

注：`usr_*` 标记 pin 在 Mac 端因不开 CloudKit 本就无数据，无需特殊隐藏；图层不为它预留 toggle。

### 6.8 字体 & 度量调整（内容生产态）

进入 Studio 时统一放大 1.15×：
- pin 直径 28 → 32pt
- 学校名字号 11 → 13pt
- 图例标题 14 → 16pt
- 主标题 24 → 28pt

截屏目标分辨率 3840×2160，这个尺度刚好不糊。

---

## 7. 错误处理

| 故障 | 处理 |
|---|---|
| 地理编码失败（地址脏） | 写 `geocode_failed.json`，App 该 pin 跳过；Studio 工具条显示 "3 所未定位 [详情]" 按钮 |
| Raster 4 角校准未完成的区 | Studio 不画色块，只画 pin，标题区显示 "⚠ 学片边界缺" |
| Stage 切换数据缺失（hull 算失败） | 回退上一 stage，log warning 不抛 |
| MapKit 截屏失败（系统拒绝/资源耗尽） | 弹窗给出系统级 `⇧⌘5` 手动截屏指引，不重试 |
| Stage A raster zoom > 15 糊 | overlay alpha 渐变到 0.1，浮 "矢量边界尚未生成" 提示 |
| schools.json 缺 lat/lon | SeedImporter import 不抛，该 School `lat=nil`，不渲染 pin |
| Mac Catalyst 不可用平台（iPad 编译） | `#if targetEnvironment(macCatalyst)` 包住 Studio，iPad 编译时 StudioMode 永远 `.explore` |

**不做防御**：
- ❌ raster 文件签名/篡改校验
- ❌ geocoder 结果地理范围二次验证（信任 Apple API）
- ❌ 用户输入标题 XSS（本地工具，无远端输出）

---

## 8. 测试

### 8.1 Swift Testing 单元测试

```
PropertyAtlasTests/Studio/
  CalibratedImageOverlayTests.swift   # 4 角→MapRect 仿射变换数值正确性
  ZoneGeometryImporterTests.swift     # stage=raster/hull/geojson 三种结构解析
  CameraPresetsTests.swift            # 18 区预设镜头 bbox 在天津范围内 (38.5-40.3°N, 116.7-118.0°E)
  SnapshotExporterTests.swift         # 4K 输出尺寸 / 文件名格式 / 6 种画布比例像素正确
  StudioModeToggleTests.swift         # 切换不动 ModelContainer / 不触发 CloudKit
```

### 8.2 Python 脚本测试

```
scripts/tests/
  test_build_zone_hulls.py            # 5 个固定 zone 算 hull → 顶点数 + 面积 sanity
  test_calibrate_raster_output.py     # JSON 4 角格式校验, lat/lon 在天津范围
```

### 8.3 手测清单（写进 spec）

进入 Studio 模式后：
- [ ] 按 ⌘1..⌘6 跳市内六区各一遍，色块对位
- [ ] 截屏 16:9 / 1:1 / 9:16 各一张，对比 PDF 参考图
- [ ] 关闭学校名 / 关闭色块 / 关闭水印 toggle 都生效
- [ ] iPad target 编译不报 Studio 相关错误（`#if` 隔离生效）
- [ ] 录 30s 屏，cursor 表现 OK

---

## 9. 范围

| ✅ MVP 做 | ❌ 不做（本期） |
|---|---|
| Mac Catalyst target + Studio Mode 开关 | iPad Studio 触控模式 |
| 学片色块 Stage A（18 区手描 raster） | 街道 GeoJSON（Stage C） |
| 学校 pin + 名 | 楼盘 pin（图层 E） |
| 安静底图 + 图例 + 水印 + 标题 | 集团连线（图层 C） |
| 4K PNG 截屏 + 6 画布比例 | 内置录屏（用 CleanShot） |
| 18 区 + 101 学片 镜头预设 | 中考 rank 热力（图层 D） |
| Stage A raster + Stage B hull 数据脚本 | 居委会 polygon（图层 F） |
| 地理编码 822 学校（Swift CLGeocoder） | 地理编码 174 楼盘（并行/后续） |

---

## 10. 时间分块预估

| 块 | 估时 |
|---|---|
| 数据脚本（geocode + calibrate + hull）| 2 天 |
| 18 区手描 raster | 1.5 天 |
| Mac Catalyst target + StudioMode 开关 + UI 浮层 | 2 天 |
| 渲染层（overlay + pin + label）| 2 天 |
| 截屏导出 + 画布比例 | 1 天 |
| 测试 + 修 | 1.5 天 |
| **合计** | **~10 工作日** |

---

## 11. 文件清单（待动）

### 新增
```
PropertyAtlas/Studio/                        # 见 §3.3 全部新模块
PropertyAtlas/Resources/StudioRasters/       # 18 张区图 PNG
scripts/geocode_schools.swift
scripts/build_zone_hulls.py
scripts/calibrate_raster.swift
PropertyAtlasTests/Studio/                   # 见 §8.1
scripts/tests/test_build_zone_hulls.py
scripts/tests/test_calibrate_raster_output.py
```

### 改
```
PropertyAtlas.xcodeproj                      # 加 macOS (Catalyst) target
PropertyAtlas/RootView.swift                 # 根据 AppMode 切布局
PropertyAtlas/PropertyAtlasApp.swift         # 注入 AppMode @Observable
PropertyAtlas/Map/MapContainerView.swift     # 接 ZoneOverlayLayer / SchoolPinLayer
PropertyAtlas/Models/Public/School.swift     # 加 lat/lon/geocode_*
PropertyAtlas/Models/Public/SchoolZone.swift # 加 geometryStage/geometry
reports/extracted/schemas/schools.schema.json
reports/extracted/schemas/zones.schema.json
scripts/validate.py                          # 校验新字段
CLAUDE.md                                    # 流水线 + 模型字段说明追加
```

### 不动
```
所有 usr_* / loc_* 模型
SeedImporter 入口
CloudKit 集成
existing pub_* 模型（除 School / SchoolZone）
docs/superpowers/specs/2026-05-19-tianjin-house-design.md  # 原 spec 保留为历史
```
