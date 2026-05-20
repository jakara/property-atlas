# 北漂天津置业地图 — 设计文档

**日期**：2026-05-19（UI 脑暴完成更新：2026-05-20）
**版本**：v4（iOS SwiftUI 单平台 MVP，含 UI 交互设计）
**关联背景**：`docs/idea.md`

---

## 0. 摘要

为自用看房决策构建一款 iPad 优先的原生 App。MVP 阶段满足"个人地图笔记 + 学区数据库"两大核心痛点，并预留公共/私有数据分层结构，为未来扩展到 Android 端、开放公共学区库做铺垫。

- **平台**：iPad/iPhone（iOS 17+），SwiftUI + MapKit
- **存储**：SwiftData 本地 + CloudKit Private Database 自动跨设备同步
- **数据来源**：`pub_*` 公共数据通过离线 Seed Pipeline 打包进 App Bundle；普通用户只读公共数据
- **后续路径**：Phase 2 扩 Android（Compose + 服务器化公共库），Phase 3 开放公共贡献+商业化

---

## 1. 项目目标与范围

### 1.1 用户与场景

**首要用户**：项目发起者本人，长期北漂、为子女教育考虑在天津买房。
- 看房现场（中介陪同、需快速记录）
- 桌面分析（多个候选小区对比、学区研究）
- 跨设备访问（iPad 主用，iPhone 应急）

### 1.2 当前最痛点（已确认优先级）

| 痛点 | 优先级 | MVP 是否覆盖 |
|------|-------|-------------|
| A. 信息散乱（备注/照片/价格/学区散在多处） | 最高 | ✅ |
| B. 学区对应不清（小区↔学校↔落户年限↔学位预警） | 最高 | ✅ |
| D. 政策追踪 | 次要 | Phase 2 |
| E. 多维决策矩阵对比 | 次要 | Phase 2 |
| C. 通勤评估 | 跳过 | 不做 |

### 1.3 天津学区大逻辑

> **学区** = 地理区域概念（一个学区覆盖若干小区和学校）
>
> - **小学**：买某小区的房子 → 单校划片 → 对口一所固定小学（`compound.primarySchoolId`）
> - **初中**：买某学区的房子 → 在该学区内所有初中摇号（`school.zoneId` + `compound.zoneId`）
>
> 因此 polygon 按**学区**划分，而非按单所学校划分。

### 1.4 非目标

- ❌ MVP 阶段不考虑外部用户、付费转化、商业化
- ❌ 不爬取房源交易信息
- ❌ 不内嵌房源市场（合规风险）
- ❌ Android 端不在 MVP 范围
- ❌ 多用户社区/UGC 评价不在 MVP 范围

---

## 2. 技术栈选型

| 层 | 选择 | 理由 |
|----|------|------|
| 平台 | iPadOS 17+，iPhone 兼容 | 用户自身设备，iPad 主战场 |
| UI 框架 | SwiftUI | AI 训练语料最丰富，错误率最低 |
| 地图 | MapKit | 中国大陆 POI 由 Apple 与高德合作提供，免费 |
| 本地存储 | SwiftData（@Model + SQLite） | iOS 17+ 现代 ORM，编译期类型安全 |
| 跨设备同步 | CloudKit Private Database | 零运维、自动加密、免费 1GB+、SwiftData 原生集成 |
| 照片 | CKAsset / SwiftData Data | CloudKit 自动同步，无需手写上传队列 |
| 状态管理 | `@Observable` + `@Environment` | SwiftUI 内置，无第三方 |
| 路由 | NavigationStack | SwiftUI 内置 |

### 2.1 选型决策理由

**为何放弃 Flutter 双端**：AI 编码视角下，Flutter 国内插件（amap_flutter_map、webdav_client、微信 SDK 桥接）训练语料稀少，AI 易幻觉 API 名；SwiftUI/MapKit 训练数据海量，错误率最低。

**为何先 iOS 单平台**：MVP 求快验证产品形态，AI 写 SwiftUI 最稳。Phase 2 扩 Android 时，业务逻辑直译到 Compose，UI 重写，时间可控（4-6 周）。

**为何 CloudKit 不 WebDAV**：单平台 + 自用场景下，CloudKit 自动同步省掉手写同步引擎、冲突解决 UI、照片上传队列共约 40% 复杂度。Phase 2 扩 Android 时再切自建后端。

---

## 3. 模块结构

```
TianjinHouse/
├─ Models/                  ← @Model 实体定义（公私分命名空间）
│  ├─ Public/                       (pub_* 表，Seed Pipeline 写入)
│  │  ├─ Compound.swift             ★ 含 zoneId + primarySchoolId
│  │  ├─ School.swift               ★ 含 zoneId
│  │  ├─ SchoolScore.swift
│  │  ├─ SchoolZone.swift           ★ 学区多边形（取代 SchoolDistrict）
│  │  ├─ AdmissionDoc.swift
│  │  └─ BuiltinTag.swift
│  ├─ User/                         (usr_* 表，用户读写)
│  │  ├─ PropertyMark.swift
│  │  ├─ Visit.swift
│  │  ├─ Photo.swift
│  │  ├─ TagExtension.swift
│  │  ├─ VisitTag.swift
│  │  ├─ UserArea.swift             ★ 用户绘制区域
│  │  └─ ShareSubmission.swift
│  └─ Local/                        (loc_* 不入 CloudKit)
│     └─ Settings.swift
│
├─ Map/                     ← 地图主战场
│  ├─ MapView.swift
│  ├─ SchoolZoneOverlay.swift       (学区 polygon 染色 by tier)
│  ├─ UserAreaOverlay.swift
│  ├─ CompoundAnnotations.swift
│  ├─ MapFilters.swift
│  └─ PolygonEditor.swift           (用户绘制 UserArea polygon)
│
├─ Property/                ← 小区详情
│  ├─ CompoundDetailView.swift
│  ├─ VisitFormView.swift           (评分/标签/笔记/照片；占右侧抽屉)
│  └─ TagPicker.swift
│
├─ School/
│  ├─ SchoolListView.swift
│  └─ SchoolDetailView.swift
│
├─ Drawer/                  ← 右侧抽屉（38.2%）
│  ├─ DrawerContainerView.swift     (Tab 切换容器)
│  ├─ SchoolTabView.swift
│  ├─ VisitTabView.swift
│  ├─ ZoneTabView.swift
│  └─ SearchResultsView.swift       (抽屉内搜索结果)
│
├─ Compare/                 ← Phase 2-E 多小区对比矩阵
├─ Policy/                  ← Phase 2-D 政策追踪
│
├─ Seed/
│  ├─ SeedImporter.swift            (首启动导入，带进度)
│  └─ SeedData/*.json
│
├─ Scripts/SeedExtractor/   ← 离线 Mac 工具（不进 App Bundle）
│  ├─ Package.swift
│  └─ Sources/SeedExtractor/main.swift
│
└─ App/
   ├─ TianjinHouseApp.swift         (ModelContainer + iCloud entitlements)
   └─ RootView.swift
```

### 3.1 关键设计原则

1. **公私分层**：所有 `Public/*` 实体未来可整体迁移到服务器 PostgreSQL，DAO 接口不动只换实现。
2. **无运营权限概念**：`pub_*` 更新通过离线 Seed Pipeline 打包发版，不存在 in-app 写公共表的路径。
3. **模块边界**：Map 只负责显示/交互，不知道学区评级算法；School 只管学校数据，不知道小区如何关联；通过 Service 层组合。
4. **文件控制**：单文件不超过 ~300 行，超过强制拆分。

---

## 4. 数据模型

### 4.1 命名空间与分层

- `pub_*` — **公共数据**（Seed Pipeline 写入，用户只读）。v1 寄宿用户 iCloud Private DB；v2 迁服务器 PostgreSQL。
- `usr_*` — **私有数据**（用户读写）。永远私有，CloudKit Private DB。
- `loc_*` — **本地独有**（不进 CloudKit）。UserDefaults 或独立非-CloudKit ModelContainer。

### 4.2 公共库 `pub_*`

#### SchoolZone（学区 — 对应一个 polygon 区域）★
```
id              UUID PK
name            String              -- 如"南开区第一学区"
tier            String              -- 顶尖/优质/普通/薄弱（按区内初中整体水平）
primaryDistrict String              -- 行政区（南开/和平/…）
geometry        String              -- GeoJSON Polygon/MultiPolygon（学区边界）
geometrySimplified String?          -- Douglas-Peucker 简化版，远景缩放用
residencyYears  Int?                -- 落户年限要求（有些学区严）
strokeColor     String?             -- 覆盖 tier 默认色
fillOpacity     Double = 0.2
textDescription String?             -- 原文"珠江道以北…"
evidenceDoc     AdmissionDoc?
+ 标准元数据（createdAt/updatedAt/deleted/version）
UNIQUE(name, primaryDistrict)
```

#### Compound（小区客观属性）
```
id              UUID PK
amapPoiId       String?   UNIQUE    -- 高德 POI 引用，去重
name            String
aliases         [String]             -- 别名
district        String               -- 行政区
streetBlock     String?              -- 街道
address         String
latitude        Double
longitude       Double
zoneId          UUID? FK→SchoolZone  ★ 所属学区
primarySchoolId UUID? FK→School      ★ 对口小学（单校划片）
buildYear       Int?
developer       String?
propertyMgmt    String?
totalBuildings  Int?
greeningRatio   Double?
parkingRatio    Double?
propertyFeeCents Int?                -- 分/㎡/月（避免浮点）
landYears       Int?                 -- 70/50/40
sourceUrl       String?
contributedBy   String?              -- v1: deviceId  v2: userId
verifiedAt      Date?
version         Int = 1
createdAt/updatedAt/deleted
```

#### School（学校）
```
id              UUID PK
name            String
type            String              -- 小学/初中
zoneId          UUID? FK→SchoolZone ★ 所属学区（用于初中摇号范围查询）
district        String
tier            String              -- 顶尖/优质/普通/薄弱
motto           String?
websiteUrl      String?
foundedYear     Int?
isPublicSchool  Bool = true
notes           String?
sourceUrl       String?
contributedBy   String?
verifiedAt      Date?
version         Int = 1
createdAt/updatedAt/deleted
UNIQUE(name, type, district)
```

#### SchoolScore（中考排名，按年）
```
id, school FK, year, rankCity, topPercentile, rawJson,
+ 标准元数据
UNIQUE(school, year)
```

#### AdmissionDoc（招生简章/政策原文件）
```
id, title, district, schoolLevel?, year, docType (招生简章/学区图/政策文件),
sourceUrl, localPath, remotePath, ocrText,
+ 标准元数据
```

#### BuiltinTag（内置标签库）
```
id, category (采光/噪音/气味/物业/邻里/装修/朝向),
label, polarity (正/负/中), sortOrder, version
```

### 4.3 学区逻辑查询

```swift
// 查询某小区对口小学
func primarySchool(for compound: Compound) -> School? {
    guard let id = compound.primarySchoolId else { return nil }
    return context.fetch(School.self).first { $0.id == id }
}

// 查询某学区内所有初中（摇号池）
func middleSchools(in zone: SchoolZone) -> [School] {
    context.fetch(School.self).filter { $0.zoneId == zone.id && $0.type == "初中" }
}

// 查询某学区的落户年限要求
func residencyRequirement(for compound: Compound) -> Int? {
    guard let zoneId = compound.zoneId else { return nil }
    return context.fetch(SchoolZone.self).first { $0.id == zoneId }?.residencyYears
}
```

### 4.4 个人库 `usr_*`

#### PropertyMark（小区私有标记）
```
id, compound FK→Compound,
status (想看/看过/排除/已购),
priority Int? (1-5),
privateNotes String?,
askPriceMinWan Int?, askPriceMaxWan Int?,
firstSeenAt Date,
+ createdAt/updatedAt
UNIQUE(compound)
```

#### Visit（看房记录）
```
id, compound FK,
visitDate Date,
ratingOverall/Light/Noise/Layout/Property Int? (1-5, Noise: 5=最静),
floorNumber Int?, totalFloors Int?,
areaM2 Double?,
askPriceWan Int?,
layout String?,
agentName String?, agentPhone String?,
freeText String?,
+ createdAt/updatedAt
```

#### Photo
```
id, visit FK?, compound FK?,
kind (visit/compound/document),
data Data?                             -- CKAsset 或内嵌
caption String?,
takenAt Date?, width/height Int?,
+ createdAt
```

#### TagExtension（用户扩展标签）
```
id, category, label, polarity, createdAt
```

#### VisitTag（看房 × 标签关联）
```
visit FK, tagId UUID, tagSource (builtin/extension)
PRIMARY KEY (visit, tagId)
```
(tagId 不强制 FK：可能引用 BuiltinTag 或 TagExtension)

#### UserArea（用户私有绘制区域）★
```
id, name, kind (custom/school_zone_alt/commute/exclusion),
geometry String,                       -- GeoJSON
strokeColor/fillColor/fillOpacity,
referenceZone FK→SchoolZone?,          -- 若基于某学区画的私版
description, isVisible,
+ createdAt/updatedAt
```

#### ShareSubmission（用户主动共享提交）
```
id, sourceTable, sourceId,
targetPubTable,                        -- 希望合入哪个公共表
payloadJson, userNote, evidencePhotoIds,
status (draft/submitted/reviewing/accepted/rejected/withdrawn),
reviewNotes, submittedAt?, resolvedAt?,
+ createdAt/updatedAt
```
v1 状态停留在 draft，仅本地积累；v2 上线服务器加"提交"按钮。

### 4.5 本地独有 `loc_*`

#### Settings（不进 CloudKit）
```
defaultMapStyle, defaultZoneTierFilter, defaultMapRegion, ...其他偏好
```

### 4.6 CloudKit 集成

```swift
let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.x.tianjinhouse"))
let container = try ModelContainer(for:
    Compound.self, School.self, SchoolScore.self,
    SchoolZone.self, AdmissionDoc.self, BuiltinTag.self,
    PropertyMark.self, Visit.self, Photo.self,
    TagExtension.self, VisitTag.self, UserArea.self, ShareSubmission.self,
    configurations: config)
```

`Settings` 用独立非-CloudKit ModelContainer（或 UserDefaults）。

CloudKit 要求所有属性带默认值或为可选。

---

## 5. 关键模块设计

### 5.1 iPad 主屏布局（黄金分割）

```
┌──────────────────────────────────────────────────────────────┐
│ ░░░░░░░░░░░░░ 地图（全屏底层，MapKit ignoresSafeArea）░░░░░░ │
│ ╔══════════════════════════════════════════════════════════╗ │
│ ║ 浮动 Toolbar（毛玻璃卡片，top:40 h:52 inset:16 r:16）  ║ │
│ ║ [图层 ▼]  [筛选 ▼]                     [搜索] [设置]  ║ │
│ ╚══════════════════════════════════════════════════════════╝ │
│                      ╔══════════════════════════════════════╗ │
│  MapKit polygon 渲染  ║ 浮动 Drawer（38.2%-16pt，r:20）    ║ │
│  + 小区 annotation    ║ ├─ 学校 │ 看房 │ 区域             ║ │
│  + 学区 overlay       ║ ├─ [搜索框]                        ║ │
│                       ║ └─ 卡片列表                        ║ │
│                       ╚══════════════════════════════════════╝ │
└──────────────────────────────────────────────────────────────┘
```

**关键：chrome 是浮动叠加，不是刚性 HStack 分栏**

SwiftUI 结构：`ZStack` 全屏地图 + `.overlay(alignment: .top)` toolbar + `.overlay(alignment: .topTrailing)` drawer，地图 `.ignoresSafeArea()`。

**浮动 chrome 尺寸规格**（来自 hi-fi 原型 `styles.css`）：
```
Toolbar:  position absolute, top 40pt, inset H 16pt, height 52pt
          background rgba(250,248,244, 0.78), blur 24pt, radius 16pt
          shadow: 0 6pt 22pt rgba(28,27,25,0.10)
          z-index: 30

Drawer:   position absolute, top 108pt, bottom 16pt, trailing 16pt
          width = parentWidth × 0.382 − 16pt
          background rgba(250,248,244, 0.92), blur 22pt, radius 20pt
          shadow: 0 12pt 36pt rgba(28,27,25,0.12)
          z-index: 5

Wizard:   same frame as Drawer（top 108, bottom 16, trailing 16）
          background rgba(250,248,244, 0.96), blur 22pt, radius 20pt
          z-index: 12（高于 Drawer 的 5，低于 Toolbar 的 30）
          无全屏遮罩（wizard-shade 已在设计迭代中删除）
```

**比例**：Drawer 宽 = parentWidth × 38.2% − 16pt（右 inset）

**地图 → 抽屉联动**：
- 点地图 pin → 右侧高亮对应卡片并滚动到
- 点右侧卡片 → 地图 `setRegion` 居中到对应小区
- 点地图 pin → 抽屉展示该 POI 详情（比卡片信息更多）

**搜索**：搜索框在右侧抽屉顶部，结果在抽屉内列出；地图联动高亮匹配 pin（不全屏覆盖）

**图层菜单**（左上角）：
```
☑ 学区 polygon   ☐ 我的区域   ☐ 通勤圈
──────────────────────────
学区等级：☑ 顶尖  ☑ 优质  ☐ 普通  ☐ 薄弱
──────────────────────────
学年：[2024 ▼]
```

**缩放层级策略**：

| zoom | 显示 | 数据 |
|------|------|------|
| < 12 | 各区轮廓 + 顶尖学校簇点 | 不渲染 polygon |
| 12-15 | 简化 polygon | `geometrySimplified` |
| 15+ | 完整 polygon + 小区 annotation | `geometry` 完整 |

**设计 token**（来自 hi-fi 原型 `colors_and_type.css`）：
```
--accent-500: #B5703A      // 品牌暖橙（按钮、选中态）
--ink-900: #1C1B19         // 主文字
--ink-700: #4A4742         // 次要文字
--ink-500: #8A8580         // 提示文字
--bg-base: #FAF8F4         // 纸白背景
--border: rgba(28,27,25,0.10)
```

**学区 tier 颜色**（来自 hi-fi 原型 `map.jsx`）：
| tier | 颜色 |
|------|------|
| 顶尖 | 暖金 #C99B2C |
| 优质 | 钢蓝 #5B7C9C |
| 普通 | 暖灰 #9C968B |
| 薄弱 | 砖红 #B8736B |

**小区 pin 状态颜色**（来自 hi-fi 原型 `map.jsx`）：
| 状态 | 颜色 |
|------|------|
| 未看（默认） | 暖灰 #9C968B |
| 想看 | 钢蓝 #5B7C9C |
| 看过 | 绿 #7A9A7E |
| 排除 | 砖红 #A85040 |

### 5.2 抽屉 Tab 交互

**三个 Tab**：学校 / 看房 / 区域

**学校 Tab**：
- 学校卡片（Notion 风格，含学校名/tier/类型/学区/中考排名）
- 点击 → 地图居中到学区 polygon + 侧边展示学校详情
- 搜索框过滤学校列表 + 地图高亮

**看房 Tab**：
- 按看房状态分组（想看 / 已看 / 排除）
- 小区卡片含：小区名/最近看房日期/总评星级/照片缩略图/标签 chips
- 点击卡片 → 地图居中 + 展示完整看房详情
- 「+ 新建」按钮 → 打开看房 Wizard（占右侧抽屉，背景换成照片拼图）

**区域 Tab**：
- 用户自己画的 UserArea 列表
- 点击 → 地图高亮该区域
- 「+ 绘制新区域」→ 进入 PolygonEditor（用户模式）

### 5.3 看房 Wizard（右侧抽屉 + 照片拼图背景）

**触发**：
1. 地图 pin 长按 → 浮现「开始看房」按钮
2. 看房 Tab 右上角「+ 新建」按钮

**布局**：右侧抽屉区域展示表单 Wizard，地图区域变为已拍照片的马赛克拼图背景（半透明遮罩）

**Wizard 步骤**：
```
步骤 1/4：基本信息
  小区（从地图选中或搜索）
  日期（默认今天）
  楼层 [chips: 低/中/高] + 总层数
  面积 [滑块 60-200㎡]
  报价 [步进器 万元]

步骤 2/4：评分
  总评 ★★★★☆
  分项：采光 / 噪音 / 户型 / 物业（各 5 星）

步骤 3/4：快速标签（全选择，无文字输入）
  按 category 分组胶囊

步骤 4/4：拍照 + 自由文本
  📷 多张拍照（已拍张数实时更新背景拼图）
  💬 自由文本（可空，支持语音输入）
```

**规则**：最少日期+小区可保存；数字字段用 chips/滑块/步进器，不用键盘数字输入

### 5.4 PolygonEditor（用户绘制私有区域）

**范围**：仅写 `UserArea`（私有），不涉及 `pub_*`

**交互**：
```
点击地图 → 打点（创建 vertex）
点击 vertex → 拖拽调整
长按 vertex → 删除
edge 中点 + 号 → 插入新点
Apple Pencil → 自由手绘模式（描边转折线顶点）
[撤销] [清空] [闭合] [完成]
完成 → 命名 + 选择类型（自定义/通勤圈/排除区域）
保存 → 写 SwiftData，生成 geometrySimplified
```

**道路辅助（分阶段）**：

| 阶段 | 能力 | 实现 |
|------|------|------|
| Phase 1 | 手工点击 + Apple Pencil 自由绘 | 纯 MapKit GestureRecognizer |
| Phase 1.5 | 点击吸附最近道路顶点 | 内嵌离线 OSM 数据集（SQLite pbf 解析） |
| Phase 2 | 选中一组道路 → 自动围合 polygon | Overpass API，按路段查询 linestring |

**简化算法**：Douglas-Peucker，tolerance 50m。推荐 `turf-swift` Swift Package。

**注**：学区 `SchoolZone` 的 polygon 由离线 Seed Pipeline 或手工 GeoJSON 文件维护，不通过 App 内编辑。

### 5.5 Seed 数据导入

**源**：`reports/` 两份 Markdown + 手工维护 GeoJSON
- 天津市内六区小学与初中学片划分及实力排名深度研究报告.md
- 天津市内六区初中中考成绩综合排名.md
- `SeedData/school_zones.geojson`（手工画 polygon，分批完成）

**离线工具**（不在 App 内）：
```
Scripts/SeedExtractor/
├─ Package.swift
├─ Sources/SeedExtractor/main.swift
└─ Output/
   ├─ schools.json
   ├─ school_scores.json
   ├─ school_zones.json      ★（含 geometry GeoJSON 字符串）
   └─ compounds.json
```

**JSON 格式（统一）**：
```json
[
  {
    "id": "uuid",
    "name": "万全道小学",
    "type": "小学",
    "zoneId": "zone-uuid",
    "district": "和平区",
    "tier": "顶尖",
    "sourceUrl": "reports/...md",
    "version": 1
  }
]
```

**App 端 SeedImporter（带进度，全屏展示）**：
```swift
class SeedImporter {
    func importIfNeeded(context: ModelContext, progress: (String, Double) -> Void) async throws {
        guard !UserDefaults.standard.bool(forKey: "seedImported.v1") else { return }
        let zones: [SchoolZoneDTO] = try loadJSON("school_zones.json")
        progress("学区边界", 0.1)
        for dto in zones { context.insert(SchoolZone(from: dto)) }

        let schools: [SchoolDTO] = try loadJSON("schools.json")
        progress("学校数据", 0.3)
        for dto in schools { context.insert(School(from: dto)) }

        // ... 其他表，每步更新 progress
        try context.save()
        UserDefaults.standard.set(true, forKey: "seedImported.v1")
    }
}
```

首次启动显示全屏进度界面（深色背景），完成后自动进入主界面，无需用户操作。

**SchoolZone polygon 进度**：原文是文字描述，需手工在 geojson.io/QGIS 绘制。
预估：六区学区约 20-30 个，每个 30-60 分钟，总计 10-25 小时，可分批发版更新。

### 5.6 标签录入 UX（看房现场 30 秒勾完）

**内置标签库示例**：
```
采光: 南北通透(+) 全朝南(+) 西晒(-) 北向(-) 楼层遮挡(-)
噪音: 安静(+) 临街主干道(-) 楼上熊孩子(-) 高架旁(-)
气味: 无异味(中) 电梯异味(-) 潮湿霉味(-) 烟味(-)
装修: 新装精装(+) 次新整洁(+) 陈旧(-) 毛坯(中)
物业: 物业积极(+) 物业散漫(-) 电梯老旧(-) 安保严格(+)
邻里: 楼道整洁(+) 杂物堆积(-) 邻居有狗(-) 老人多(中)
```

**UX 规则**：
- 标签按 category 横向展开，胶囊式
- 用户勾过的标签下次置顶
- 拍照按钮醒目（50% 时间用）
- 所有字段可空，最少日期+小区可保存
- 楼层 chips 预设："低层(1-3) / 中层(4-9) / 高层(10+)"
- 数字键盘自动浮 `.numberPad`
- 自由文本支持系统语音输入

### 5.7 CloudKit 配额监控

**预估**（自用 1-2 年）：
- 小区/学校元数据：< 5 MB
- 看房记录：< 10 MB
- 看房照片：每次 5-10 张 × 2-3 MB ≈ 20 MB/次
- 看 50 次 ≈ 1 GB → 接近免费上限

**节流**：
1. 照片上传前 `ImageRenderer` 压缩到 1280px 长边 + HEIC，质量 0.8 → 单张 200-500 KB
2. AdmissionDoc PDF 不进 CloudKit，本地缓存
3. 设置页显示当前用量（从 `CKContainer.accountStatus` + 配额 API 查询）

---

## 6. 错误与空状态处理

### 6.1 首次启动 — Seed 导入

全屏深色背景，显示分步进度（学区边界 / 学校数据 / 小区数据 / 地铁线路），带百分比进度条。完成后无动画切入主界面。若失败：提示 + "重试" / "清空重装"。

### 6.2 空状态

| 场景 | 处理 | 位置 |
|------|------|------|
| 看房 Tab 无记录 | 图文空态 + "+ 新建看房记录" CTA | 右侧抽屉 |
| 搜索无结果 | 「未找到 X」+ 历史搜索 chips + "添加自定义地点" | 右侧抽屉 |
| 筛选无结果 | 「条件过于严格」+ 智能建议（移除哪个条件）+ 重置按钮 | 右侧抽屉 |

地图始终显示公共小区 POI（灰色 pin），空态仅作用于右侧抽屉对应 Tab。

### 6.3 错误状态

| 场景 | 处理 | 用户操作 |
|------|------|---------|
| 未登录 iCloud | Gate 覆盖右侧抽屉（地图仍可浏览）；显示「前往设置」+ 「仅本地使用」 | 选择其一 |
| iCloud 容量满 | 内联 warning banner（不打断操作）+ 卡片「未同步」badge；底部 sheet 提示升级或仅本地 | 可忽略继续用 |
| 网络断开（离线） | 地图顶部胶囊 badge「离线 · 缓存地图 · 同步暂停」；抽屉内 info banner | 本地读写正常，恢复网络自动同步 |
| 地图无法定位 | 默认天津市中心，手动搜索 | — |
| 学区 polygon 缺失 | 占位提示（polygon 区域为空），用户可自绘 UserArea 补充 | 可选操作 |

**不变量**：
- Compound 被 PropertyMark 引用时，禁止硬删除（软删除标记）
- Visit 创建后 compound 不可解绑

---

## 7. 测试策略

**单元测试**（Swift Testing）：
- GeoJSON 序列化/反序列化
- Polygon 简化算法
- Seed 导入幂等
- 学区查询逻辑（primarySchool / middleSchools / residencyYears）
- 标签状态切换

**集成测试**：
- SwiftData @Model 持久化 + CloudKit mock
- ModelContainer 启动 + 数据加载
- SchoolZone polygon 渲染（MKPolygon coordinates 正确性）

**UI 测试**（XCUITest 选择性）：
- 看房 Wizard 4步流程
- PolygonEditor 打点保存
- 搜索在抽屉内正常过滤

**手动测试矩阵**：
- iPad mini 6/7、Air、Pro
- iPhone 15/16 兼容
- iOS 17 / 18
- 飞行模式 → 本地读写正常；恢复网络后同步
- 多设备同步：iPad 改 → iPhone 几秒后看到

---

## 8. 演进路径

### Phase 1 (MVP, 4-8 周)

含：
- Models 全套（pub_* + usr_* + loc_*）
- Map + SchoolZoneOverlay + UserAreaOverlay + CompoundAnnotations + MapFilters
- PolygonEditor（用户模式）
- VisitFormView（Wizard，占右侧抽屉）+ TagPicker
- CompoundDetailView + SchoolListView + SchoolDetailView
- DrawerContainerView（学校/看房/区域 三 Tab）
- SearchResultsView（抽屉内）
- SeedImporter（带进度全屏）
- CloudKit 同步
- 所有空态 + 错误态

不含：Compare / Policy / ShareSubmission UI / PolygonEditor OSM 道路辅助

### Phase 2 (Android 扩展，4-6 周)

- 搭服务器 PostgreSQL + PostGIS，导入 `pub_*` 数据
- iOS app 配置开关：`pub_*` 从 CloudKit Private 切到服务器 REST，`usr_*` 仍 CloudKit Private
- Android Compose 端：`pub_*` 调服务器 REST，`usr_*` 用 Room + WebDAV（或 Firebase）
- PolygonEditor 加 Phase 1.5 OSM 道路吸附
- 加 Compare 决策矩阵
- 加 Policy 政策追踪（独立爬虫服务，输出 JSON 推送）

### Phase 3 (开放公共贡献 + 商业化)

- 部署运营审核后台
- ShareSubmission UI 上线，用户提交流程
- 订阅付费档（基于 idea.md 的"内容引流 + 工具承接"）
- 邀请奖励机制
- ICP 备案/许可证按 idea.md 八节合规框架推进

### v1 → v2 迁移路径细节

1. 服务器搭 PostgreSQL + PostGIS
2. 导出 CloudKit Private DB 中的 `pub_*` 数据 → 导入 PG（GeoJSON 字段 `ST_GeomFromGeoJSON()` 转 PostGIS geometry）
3. iOS app DAO `pub_*` 的实现从 SwiftData 读切到 REST 调用，接口不变
4. `usr_*` 和 `loc_*` 不动
5. AdmissionDoc PDF 迁对象存储 (S3/MinIO)

---

## 9. 风险与缓解

| 风险 | 级别 | 缓解 |
|------|------|------|
| 学区 polygon 工作量大（10-25 小时手绘） | 中 | 分批做，优先关注候选学区；先发布"无 polygon"版本渐进补 |
| CloudKit 配额超 1 GB | 低 | 照片压缩；用量监控；超额按 iCloud 套餐升级 |
| Apple 政策变更（CloudKit 限制） | 低 | 公私分层 schema 已为迁服务器铺路 |
| MapKit 中国 POI 数据不完整 | 中 | 允许手工录入小区；amapPoiId 字段冗余便于将来切高德 |
| AI 编码错误 | 中 | 选 SwiftUI/SwiftData 因为 AI 训练语料最丰富；每模块 ≤300 行便于复核 |
| 公共数据维护人手不足（你一人） | 高 | MVP 阶段你=用户=运营三重角色，仅维护你关心的片区；Phase 3 开放贡献分散工作量 |

---

## 10. 待决事项

无（所有关键决策已闭环）。

下一步：进入实现计划（`writing-plans` skill）。
