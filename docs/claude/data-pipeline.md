# Data Extraction Pipeline

Seed JSON for the app is built from 5 source documents in `reports/`. Outputs live in `reports/extracted/`. Always run `scripts/validate.py` after editing any JSON or schema.

## Source documents

| File | Code | Used for |
|---|---|---|
| `天津学校情况(4).pdf` | **JM-PDF** | 822 学校 (地址/电话/学费/学片/communities) + 101 学区 + 32 集团 (公开) |
| `2026年永辉选房全天津项目优缺点(2).xlsx` | **YH-XLSX** | 174 新房楼盘. 优缺点是永辉主观点评 — sensitive |
| `2026在天津怎样买房落户上学（宠粉）(1).pptx` | **YH-PPTX** | 25 政策 + 19 区中考录取率 (公开) |
| `天津市内六区初中中考成绩综合排名…2022–2025.md` | **MD-RANK** | 108 初中 rank/Top%/tier/comment — **敏感** |
| `天津市内六区小学与初中学片划分…2024–2026.md` | **MD-ZONE** | 19 学片 highlight 解读 — **敏感** |

PDF 提取用 Claude vision (不用 tesseract — 中文 OCR 不可靠). 详见 `reports/extracted/EXTRACTION_REPORT.md`.

## Public JSON outputs (`reports/extracted/`)

| 文件 | 条目 | Schema | 主键 / 状态 |
|---|---|---|---|
| `schools.json` | 822 | `schools.schema.json` | `sch_<md5[:10]>` |
| `zones.json` | 101 | `zones.schema.json` | `zon_<md5[:10]>` |
| `groups.json` | 32 | `groups.schema.json` | `grp_<md5[:10]>` + reverse index `school_to_groups` |
| `policies.json` | 25 | `policies.schema.json` | `pol_<slug>` |
| `compound_school_match.json` | 174 | `compound_school_match.schema.json` | 楼盘→学校匹配 (7自动命中, 余 `needs_manual_review:true`) |
| `compounds.json` | 174 | `compounds.schema.json` | `cmp_<md5[:10]>` · **顶层 `sensitive: true`** · 全 `is_new_house: true` |
| `admission_rates.json` | 19 | `admission_rates.schema.json` | district-level · **顶层 `sensitive: true`** |

ID 格式: `<prefix>_<md5(district+name) 前10位>`. Schema 强制 `^<prefix>_[a-f0-9]{10}$`.

**敏感性两级**:
- **顶层 `sensitive: true`** — 整个数据集敏感 (compounds + admission_rates). 公开导出时**整体剔除**.
- **`item.sensitive` 子对象** — 单条记录的部分字段敏感 (schools 评级 + zones 解读 + compounds 优缺点). 公开时剔除该子对象保留主体.

## Schema 扩展 (2026-05-28 改动)
- `tier_label` enum 加 `"区重点"`
- `source_code` enum 加 `"WebResearch"` (web 多源核实)
- `SchoolSensitive` 加 `source_url: string|null`
- `School` 加 `lat/lon` (Tianjin bounds 38.5-40.3 / 116.7-118.0) + `geocode_source` (含 `mklocalsearch`/`auto-bbox`/`nominatim`/`manual`/`WebResearch`/...) + `geocode_confidence` (`name`/`address`/`manual`/`failed`/`approximate`)

## Sensitive subobject

每条记录的敏感数据放在 `sensitive` 子对象, 标注 `source`:

```jsonc
// compounds[*].sensitive (YH-XLSX) — 永辉主观点评
{"pros": "...", "cons": "...", "source": "YH-XLSX", "note": "..."}

// schools[*].sensitive (MD-RANK) — 中考梯队/Top%
{"rank_overall": 21, "top_percentile": 16, "tier_letter": "A", "tier_label": "优质",
 "tier_rank": 3, "comment": "...", "data_origin": "...", "source": "MD-RANK", "note": "..."}

// zones[*].sensitive (MD-ZONE) — 学片描述
{"highlight": "...", "source": "MD-ZONE", "note": "..."}
```

**仓库私有 → `raw/` 和 `private/` 都 commit**. 公开发布前 (如另开 OSS repo) 才剥离 `sensitive` 子对象 + 不导出 `raw/private/`. 当前 repo 不 gitignore 这两目录.

## 公开 MD 输出 (`天津学区房数据库.md`)

由 `scripts/build_public_md.py` 从 JSON 自动生成. 仓库根目录. 66KB / ~1923 行. 全列表/缩进, **不用表格** (按要求).

**章节**:
1. 一、市内六区学片划分 — 和平/河西/南开/河东/河北/红桥 学片 → 公办初中池 + 小学 + 初中详情
2. 二、环城+远郊+滨海学校分布 — 中学 → 对口小学 / 学片区号 / 地理片区
3. 三、各小学招生范围 (居委会/小区 → 小学) — 市内六区 100+ 小学的居委会+楼号清单
4. 四、集团化办学关系 — 32 集团, 牵头校 + 成员校
5. 五、入学落户中考政策摘要 — 25 政策按 落户/入学/转学/小升初/中考/高考 分组

**剔除** (含敏感数据, 不写入 MD):
- ❌ 楼盘清单 (compounds.json 顶层 `sensitive: true`)
- ❌ 中考录取率 (admission_rates.json 顶层 `sensitive: true`)
- ❌ 数据来源章节 (不暴露源文件名)
- ❌ 所有 `item.sensitive` 子对象内容 (rank/Top%/tier/pros/cons/highlight)

**生成器防御**:
```python
assert compounds['sensitive'] is True, 'compounds.json must be marked sensitive'
assert admission['sensitive'] is True, 'admission_rates.json must be marked sensitive'
```
若 sensitive 标记丢失则 assert 抛错, 避免误公开.

**触发重生成**:
```bash
python3 scripts/build_public_md.py
```
任何 JSON 改后需重跑.

## Schema validation

```bash
python3 scripts/validate.py    # exit 0 = pass
```

`reports/extracted/schemas/` 含 7 个 schema (Draft 2020-12) + `_common.schema.json` (共用 $defs). 关键约束:
- `additionalProperties: false` 阻断脏数据
- `source` 枚举 5 个信源缩写 (JM-PDF / YH-XLSX / YH-PPTX / MD-RANK / MD-ZONE)
- `district` 限定 18 个区/板块
- `is_new_house: const true`

任何 JSON 修改后必跑 `validate.py`. CI/pre-commit 应集成.

## Scripts (`scripts/`)

| 脚本 | 用途 |
|---|---|
| `build_from_pdf.py` | 合并 6 区 + 非6区 raw → schools/zones (输出 `*_public.json`); 自动 compound→school 匹配. 注意: 和平 raw 用 `community_text` 字段 (单数), 其他用 `communities_text`, 已加 fallback |
| `build_policies.py` | 从 pptx 文本构建 policies/admission_rates; 标注小学梯队 |
| `build_groups.py` | 从 PDF P30 集团关系图构建 groups.json + 反向索引 |
| `restore_sensitive.py` | 从 `private/` md 数据合并 `sensitive` 子对象 |
| `extract_schools.py` / `extract_zones.py` / `merge_schools.py` | 早期 md→JSON 抽取 (现 `private/`) |
| `ocr_pdf.py` | 旧 tesseract OCR (已弃用, 中文不准, 留作参考) |
| `validate.py` | JSON Schema 校验 (CI) |
| `fix_for_schema.py` | 历史数据迁移 (老 source 字符串 → 信源缩写) |
| `build_public_md.py` | 生成 `天津学区房数据库.md` (公开版). 剥离全部 sensitive + 跳过 compounds/admission/sources 章节 |
| `finalize.py` | 旧脚本: 重命名 `*_public.json` → 主文件 + 移老 schools 到 `private/` |
| `fill_primary_tier.py` | 小学 tier 填充 (4 源 cross-check, 市内6区, ~44 校 标 重点/区重点) |
| `add_school.py` | 单校新增/更新 (skill `add-school` 调用). 自动 id, fuzzy 去重 (bigram Jaccard ≥0.5), 同区疑似重复 exit 2 |
| `geocode_mklocal/` (Swift SPM) | NSApplication + `MKLocalSearch` 地理编码 (Pass 0 全 address verbatim + 全市 region / Pass 1 name + district region / Pass 2 district-prefixed addr). `needsRedo = src==nil || src==auto-bbox || conf==failed`. |

**完整数据重建流水线** (任何 raw 改动后):
```bash
python3 scripts/build_from_pdf.py        # raw → schools_public.json + zones_public.json + compound_school_match.json
cp reports/extracted/schools_public.json reports/extracted/schools.json
cp reports/extracted/zones_public.json reports/extracted/zones.json
rm reports/extracted/{schools,zones}_public.json
python3 scripts/build_policies.py         # → policies.json + admission_rates.json
python3 scripts/build_groups.py           # → groups.json
python3 scripts/restore_sensitive.py      # → 合并 sensitive 子对象
python3 scripts/fix_for_schema.py         # → 迁移老 source 值
python3 scripts/validate.py               # → 校验 7 schema
python3 scripts/build_public_md.py        # → 生成公开 MD
```

每个脚本独立 idempotent. Python venv: `.venv/` (含 pandas/openpyxl/pdfplumber/jsonschema/shapely/pytest).

## `raw/` 和 `private/` 目录 (仓库私有, 全部 commit)

- `reports/extracted/raw/` — PDF/PPTX 原始文本 + 6 区 PDF raw JSON (pdf_data_*.json)
- `reports/extracted/private/` — 含 MD-RANK / MD-ZONE 评级原始数据

仓库私有, 这两目录纳入版本控制. 若未来公开 (另开 OSS repo), 需:
1. 在导出脚本剥离 `sensitive` 子对象
2. 不 copy `raw/` 和 `private/` 到公开 repo
3. 公开版只含 7 个顶层 JSON + schemas/
