# 天津学区数据 (开源版)

公开发布的天津市学区/学校/楼盘结构化数据.

**数据源**: 天津市教育局公开发布的学区划分手册《津门学路通》(2023版) + 永辉房产楼盘清单. **截止: 2026-05-25**.

## 公开数据集

| 文件 | 条目 | 内容 |
|---|---|---|
| `schools.json` | 822 | 全市学校 (490小学 + 332中学), 含地址/电话/学片归属/民办标记/学费 |
| `zones.json` | 101 | 学区/学片 (市内六区19片 + 非市六区82) + 对应中学池 |
| `compounds.json` | 174 | 在售楼盘 (区域/行政区/面积/价格/交付/可售) |
| `compound_school_match.json` | 174 | 楼盘→学校自动匹配 (7/174 自动命中, 余需手工补全) |
| `admission_rates.json` | 19 | 各区中考普高+职高录取率 (2023) |
| `policies.json` | 25 | 落户/转学/中考/小升初/六年一学位/五证 政策条款 |
| `groups.json` | 32 | 集团化办学关系 (牵头校+成员校), 含反向索引 `school_to_groups` |

## 信源缩写

每个文件 top-level `source_codes` 字段含定义. 全集:

| 缩写 | 全称 | 公开度 |
|---|---|---|
| JM-PDF | 津门学路通 PDF (天津学校情况(4).pdf) | 公开 (官方学区) |
| YH-XLSX | 永辉房产 2026 新房 xlsx | 部分敏感 (优缺点) |
| YH-PPTX | 永辉 落户上学买房 pptx | 公开 (政策) |

## Schema 校验

`schemas/` 目录含 JSON Schema (draft 2020-12), 一份对应一个数据文件:

```
schemas/
├── _common.schema.json          # 共用 $defs (ID格式/区/level/source_code/tier等)
├── schools.schema.json
├── zones.schema.json
├── compounds.schema.json
├── groups.schema.json
├── compound_school_match.schema.json
├── policies.schema.json
└── admission_rates.schema.json
```

校验命令:
```bash
python3 scripts/validate.py
```

输出 `0 errors` 即通过. CI 可集成此命令防止数据结构破坏.

**Schema 关键约束**:
- 所有 `id` 字段必须匹配 `^{prefix}_[a-f0-9]{10}$` (e.g. `sch_*`, `zon_*`, `cmp_*`, `grp_*`)
- `source` 字段限定为 5 个信源缩写 (JM-PDF / YH-XLSX / YH-PPTX / MD-RANK / MD-ZONE)
- `district` 限定为天津 18 个区/板块
- `compounds[*].is_new_house` 必须为 `true` (174 全新房)
- `sensitive` 子对象的 `source` 必填
- `additionalProperties: false` — 不允许多余字段, 防止脏数据混入
| MD-RANK | 中考排名md (Top%/梯队) | **敏感** (家长群整理) |
| MD-ZONE | 学片划分md (片区描述) | **敏感** (个人解读) |

**敏感数据** (rank/Top%/tier/comment/highlight/pros/cons) 进入每条记录的 `sensitive` 子对象, 不要公开散播. 字段 `source` 标注来源缩写.

**当前仓库私有**, `raw/` 和 `private/` 目录纳入 git. 若另开公开 OSS repo, 需先剥离 `sensitive` + 排除 `raw/private/`.

## Schema

### `schools.json` item
```json
{
  "id": "sch_xxxxxxxxxx",
  "name": "天津市第七中学（初中部）",
  "district": "河东区",
  "zone_id": "zon_xxxxxxxxxx",
  "zone_name": "第三学区",
  "level": "middle",
  "address": "成林路23号",
  "phone": "24316337",
  "is_market_key": true,
  "communities_text": "...",
  "source": "JM-PDF",
  "sensitive": {
    "rank_overall": 21,
    "top_percentile": 16,
    "tier_letter": "A",
    "tier_label": "优质",
    "tier_rank": 3,
    "comment": "河东区一哥，市九所之一...",
    "data_origin": "本地宝 + 河东盘点",
    "source": "MD-RANK",
    "note": "基于家长群+教育自媒体整理, 误差±2-3名次, 仅反映梯队差异非精确数字"
  }
}
```

86/822 学校含 `sensitive` (来自MD-RANK, 主要为市内六区 初中). 其余无 sensitive 字段或字段值为空.

### `zones.json` item
```json
{
  "id": "zon_xxxxxxxxxx",
  "district": "和平区",
  "zone_name": "第一学片",
  "middle_school_pool": ["耀华中学", "第二南开学校", "汇文中学", "第十九中学"],
  "note": "含模范小学",
  "sensitive": {
    "highlight": "含市五所之一的耀华中学初中部, 第二南开有自主直升小学部, 鞍山道小学被称为\"数学摇篮\".",
    "source": "MD-ZONE",
    "note": "基于学片划分研究报告整理"
  }
}
```

13/101 zones 含 `sensitive` (仅市内六区 河东/河北/红桥/和平 有highlight; 河西/南开 priv md 中 highlight 为空字段).

### `compounds.json` item
```json
{
  "id": "cmp_xxxxxxxxxx",
  "name": "中国铁建西派国印",
  "district_group": "市内六区",
  "district": "河北区",
  "is_new_house": true,
  "source": "YH-XLSX",
  "available_units": {"bucket": "10-50", "raw": "10-50套"},
  "area_segments": "高层,105,125,洋房133停售",
  "price_segments": "...",
  "finish_type": "毛坯/精装",
  "delivery_time": "现房",
  "sensitive": {
    "pros": "现房，即买即住即落户，河北区昆一学校，书包房",
    "cons": "价格高，可选性低，噪音问题。地铁远",
    "source": "YH-XLSX",
    "note": "永辉房产主观点评, 仅作参考"
  }
}
```

**174 条全部 `is_new_house: true`** (来自永辉 2026 新房在售清单).

### `groups.json` item
```json
{
  "id": "grp_xxxxxxxxxx",
  "district": "南开区",
  "name": "南开共同体",
  "leads": [{"name": "南开中学", "school_id": "sch_xxx", "matched_school": "南开中学"}],
  "members": [
    {"name": "翔宇中学", "school_id": "sch_xxx", "matched_school": "翔宇学校", "stopped": false},
    {"name": "崇化中学(停招)", "school_id": "sch_xxx", "matched_school": "崇化中学(北马路)", "stopped": true}
  ],
  "note": null
}
```
反向索引: `groups.school_to_groups[<school_id>] = [{group_id, group_name, role, stopped}, ...]`

分布: 南开10 + 河西8 + 红桥6 + 和平/河东 3 + 河北 2. **非市六区暂无集团化数据** (PDF P30 只覆盖市内六区).

### `compound_school_match.json` item
```json
{
  "compound_id": "cmp_xxxxxxxxxx",
  "compound_name": "中国铁建西派国印",
  "district": "河北区",
  "mapped_district": "河北区",
  "primary_matches": [
    {"school_id": "...", "school_name": "昆纬路第一小学", "zone_id": "...", "zone_name": "第一学区", "matched_via": "hint:昆一"}
  ],
  "middle_matches": [],
  "needs_manual_review": false
}
```

## 数据完整性

| 区 | 学片 | 小学 | 中学 | 完整度 |
|---|---|---|---|---|
| 和平 | 3+全区招生 | 19 | 17 | ✅ 含居委会→小学全表 |
| 河西 | 3+全区招生 | 43 | 22 | ✅ 含居委会→小学全表 |
| 南开 | 3+民办全区 | 32 | 22 | ✅ 含居委会→小学全表 |
| 河东 | 5 | 29 | 16 | ✅ 含居委会→小学全表 |
| 河北 | 3 | 28 | 12 | ✅ 含居委会→小学全表 |
| 红桥 | 3 | 19 | 11 | ✅ 含居委会→小学全表 |
| 北辰 | 1 | 40 | 17 | ✅ 中学→对口小学 |
| 西青 | 1 | 26 | 11 | ✅ 中学→对口小学 |
| 津南 | 8 | 30 | 14 | ✅ 学片→中学+小学 |
| 东丽 | 1 | 38 | 13 | ✅ 中学→对口小学 |
| 宝坻 | 1 | 86 | 37 | ✅ 中学→对口小学 |
| 武清 | — | 0 | 9 | ⚠️ 仅中学+地理片区 |
| 静海 | — | 0 | 40 | ⚠️ 仅中学+地理片区 |
| 宁河 | — | 0 | 6 | ⚠️ 仅中学+地理片区 |
| 蓟州 | — | 0 | 7 | ⚠️ 仅中学+地理片区 |
| 滨海新区 | 50+ 区域序号 | 100 | 78 | ✅ 区域→学校 |

非市内六区"地理片区"指 PDF 用文字描述边界(街道+村), 未提取为结构化字段, 见 `schools.communities_text`.

## 命名约定

- `sch_*` 学校 = md5(district + name) 前10位
- `zon_*` 学区 = md5(district + zone_name) 前10位
- `cmp_*` 楼盘 = md5(name) 前10位

## 数据源 & 版权

- **天津学校情况(4).pdf** — 来自 *津门学路通(2023年最新版)*, 整理者: 永辉房产(微信号 yonghui66898). PDF 内容为天津市教育局公开发布的学区招生方案汇编, 部分编辑由永辉房产添加.
- **2026年永辉选房全天津项目优缺点.xlsx** — 永辉房产 2026 新房在售清单. 主观评价已剥离.
- **政策条款** — 2024-2025 各区教育局公告(河东/南开/河西/和平/生态城等).

## 已知限制

1. **楼盘→学校映射 (7/174)** — 自动匹配率低. 原因: PDF 学区表用 *居委会/老小区名*, 而 174 楼盘多为 *新建商品楼盘品牌名* (如"中国铁建西派国印"). 二者命名不重合. 补全需:
   - 人工地理标注 (推荐), 或
   - 安居客/链家爬虫 (注意版权), 或
   - 公开 LBS API 配 GeoJSON 学区 polygon (天津市暂无开源 polygon)
2. **中考升学率** 为 2023 估算值, 反映各区相对水平, 非精确数字
3. **`communities_text`** 是 PDF 复杂文本的视觉识别转录, 含数字/楼号细节, 可能有少量字符误读. 用于关键词匹配可用, 不可作为最终入学依据
4. **政策时效**: 2024-11 后陆续出台二手房3年限制 (河东/南开/河西/和平), 数据已纳入. 具体年度以当年教育局正式发布为准.

## 法律与免责

- 本数据仅为公开整理, 不作为升学/购房决策依据
- 入学/落户/中考最终以各区教育局/公安局当年正式发布为准
- 2021 起天津教委禁止学校公开宣传中考成绩/状元/升学率, 因此本数据集**不含**校际排名/Top%/梯队评级

## 想贡献?

P0 待补全:
- 174 楼盘 → 学校映射 (经纬度标注 / 校验自动匹配)
- 天津市学区 polygon GeoJSON

P1:
- 民办校学费 (从 PDF 人工校对)
- 各区教育局联系电话 (PDF P51)

P2:
- 历年小升初摇号一志愿满 / 二志愿满数据

详见 `EXTRACTION_REPORT.md`.
