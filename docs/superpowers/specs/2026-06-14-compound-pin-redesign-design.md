# 楼盘 Pin 重设计 — Design Spec

- 日期: 2026-06-14
- 状态: 待实现
- 背景: 楼盘 pin 现为灰色圆点(builtin 默认),无信息量。参考学校 pin(方块 + grade→重/普 字形 + tier 配色 + 名称标签)重设计,用同一套样式机制(图层持有 ViewEntityStyle + ViewStyleRule)。

## 1. 目标 / 范围

让楼盘 pin 携带可一眼读取的信息,通道映射:

| 通道 | 编码 |
|---|---|
| 标签 | 楼盘名(zoom 够大时显示,沿用 `labelMinZoom=13` 门控) |
| 颜色 + 字形 | 交付状态三分: 现房 / 期房 / 二手 |
| 形状 | 圆(区别于学校方块;也比旧灰点精致) |

**不做**: 价格档位(`priceSegments` 多行脏文本,万/㎡混杂,解析不稳)、毛坯/精装(`finishType` 脏)。已与用户确认排除。

## 2. 数据现状(174 楼盘, 来自当前 DB)

| 字段 | 实况 | 用途 |
|---|---|---|
| `isNewHouse` | 全 = true(174/0),无二手 | 二手规则键于此(现匹配 0 条,将来有数据自动生效) |
| `deliveryTime` | "现房" 75 / 其余日期(期房) ~99 | 现房判定: `contains "现房"` |
| `name` | 全有 | 标签 |
| `buildYear`/`developer` | 全空 | 不用 |

`deliveryTime` 含 "现房" 的混合串(如 "高层洋房现房,联排期房")会判为现房 — 可接受的 v1 近似。

## 3. 视觉规格(终版,用户已在 mockup 确认)

形状统一圆形。3 类:

| 类别 | 判定条件 | fill | glyph | glyphHex | 备注 |
|---|---|---|---|---|---|
| 期房(默认) | 无条件(base) | `#0A84FF` 蓝 | 期 | `#FFFFFF` 白 | 大多数新房 |
| 现房 | `deliveryTime contains "现房"` | `#34C759` 绿 | 现 | `#FFFFFF` 白 | 可入住 |
| 二手 | `isNewHouse == false` | `#FFCC00` 黄 | 二 | `#4A3B00` 深 | 现无数据,先建好 |

共有: stroke `#FFFFFF` 白边、size `24`、labelVisible `true`。
与学校(方块 + 红/橙/灰)形状、色系均不撞。glyph 字符(现/期/二)可后续微调。

## 4. 实现机制

### 4.1 样式数据落 DB(楼盘图层),走现有样式链

`StyleResolver.resolvePin` 链: builtin → **ViewEntityStyle(图层默认)** → **ViewStyleRule(条件,priority 升序合并)** → groupFill → entity override。

楼盘图层 `groupBy = null`(已核) → groupFill 不参与 → 规则颜色不被盖。

写三块到楼盘图层(`ZLAYER.ZNAME='楼盘'`, entityType=compound):

1. **ViewEntityStyle(图层默认 = 期房底样式)** — 楼盘图层已存在一行(当前全空),**UPDATE** 它,勿新插:
   - shape=`circle`, fillHex=`#0A84FF`, strokeHex=`#FFFFFF`, glyph=`期`, glyphHex=`#FFFFFF`, size=`24`, labelVisible=`1`
2. **ViewStyleRule — 现房**(priority `10`, enabled): fillHex=`#34C759`, glyph=`现`, glyphHex=`#FFFFFF`
   - + ViewStyleCondition: field=`deliveryTime`, op=`contains`, valueString=`现房`
3. **ViewStyleRule — 二手**(priority `20`, enabled): fillHex=`#FFCC00`, glyph=`二`, glyphHex=`#4A3B00`
   - + ViewStyleCondition: field=`isNewHouse`, op=`equals`, valueString=`false`

规则 priority 升序合并: 期房(默认)→ 现房覆盖 fill+glyph → 二手最高,即便文本含"现房"也以黄覆盖。各规则只设需覆盖的列,其余继承 ViewEntityStyle(形/边/尺寸/标签)。

机制: **直接写 DB**(用户选定)。原因: 学校样式现亦只活于 DB(DB-first,无种子代码);DB 即权威。

写入约束(安全):
- **写前备份** `default.store`(+ `-wal` `-shm`)。
- **app 必须关闭**(`pkill -f PropertyAtlas.app`),避免与 SwiftData 写冲突 / WAL 不一致。
- **幂等**: 先软删/物删楼盘图层现有 ViewStyleRule + 其 ViewStyleCondition(当前 0 条),再插;ViewEntityStyle 走 UPDATE。重跑结果一致。
- Core Data 内部(Z_PK、Z_ENT、`Z_PRIMARYKEY.Z_MAX` 计数、ZID 16-byte UUID blob、ZDATASETID/ZLAYERID FK blob、ZCREATEDAT/ZUPDATEDAT=自 2001 秒、ZVALUELIST 的 NSKeyedArchiver 空数组 blob)**照现有学校行作模板**复制,只改差异列。

### 4.2 代码改动(2 处,均小,均加单测)

**A. `PinAnnotationView` 名称标签字色按底色亮度自适应**
- 现 `nameLabel.textColor = .white` 写死(line 44)→ 黄底白名字不可读。
- 改: 由 `fill` 相对亮度决定 — 亮底(如黄)用深字、暗底用白字。阈值取相对亮度 ~0.6。通用,任何浅色 pin 均受益。
- glyph 字色不动(已由各规则 `glyphHex` 显式给:绿/蓝白、黄深)。

**B. `ViewStyleConditionCodec.styleCondition` 支持 bool 等值**
- 现 bug: `.equals`/`.notEquals` 一律 decode 成 `.string`(line 24);但 `isNewHouse` 字段求值为 `.bool` → `ConditionEvaluator` 严格 `==` 下 `.bool(false) == .string("false")` = false,**bool 字段永不命中**。注: 反向 `columns(from:)` 已把 `.bool` 编码成 "true"/"false"(line 41),即 round-trip 现已破。
- 改: `.equals`/`.notEquals` 时若 valueString 为 "true"/"false" → emit `.bool`,恢复 round-trip,使 bool 字段(isNewHouse)可匹配。
- 影响面: 仅 equals/notEquals 且值恰为 "true"/"false" 的条件;现有规则(学校 grade)无此情况,安全。

## 5. 验证

- 单测: codec bool round-trip(`.bool(false)` → columns → styleCondition → `.bool(false)`);PinAnnotationView 亮度→字色映射(黄→深、蓝/绿→白)。`swiftlint lint` 过。
- DB: 写后查楼盘图层 1 ViewEntityStyle(非空)+ 2 ViewStyleRule + 2 ViewStyleCondition;学校行不动(4 rule/3 cond)。
- 运行(Mac Catalyst): 放大到天津 → 楼盘为圆形,现房绿/期房蓝,名字可读;无 yellow(无二手数据);学校仍方块红/橙/灰不受影响。缩小 → 只剩点,名字隐藏。
- 实体计数不变(174 楼盘)。

## 6. 延后 / 注记

- 二手 yellow 规则现匹配 0 条,等将来录入二手(isNewHouse=false)数据后自动生效。
- glyph 字符(现/期/二)、size(24)、阈值后续可微调。
- 价格/精装染色: 数据清洗后再议。
- DB 写入不进版本库(与全部 DB-first 数据、含学校样式一致);依赖备份。
