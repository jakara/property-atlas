---
name: add-school
description: 用户提学校名 → 我查 schools.json → 缺则 web 多源核实后新增, 缺 lat/lon 则 geocode 补; 全自动跑 pipeline 后提示 app 热更新.
---

# Add School Skill

触发: 用户说 `/add-school <校名> [区]` 或自然语 "添加 XX 小学 / 加上 YY 中学". 区可省略, 缺时我从 web 推断.

## 决策树

```
1. 查 schools.json (严格 + Fuzzy)
   ├─ 完全匹配 (name + district)
   │   ├─ 有 lat/lon → 报"已存在, 完整", 结束
   │   └─ 缺 lat/lon → 跳 step 4 (geocode 补)
   ├─ Fuzzy 匹配 (同区 bigram Jaccard ≥ 0.5, add_school.py 自动)
   │   → 列候选 (score + id + name), 询问用户:
   │      a) "用现有 id, update 此 record" → add_school.py 用准确 name 重跑
   │      b) "确实是新校" → 加 `--force` 跳 fuzzy 检查
   └─ 无匹配 → step 2 (web 核实新增)

2. Web 多源核实 (≥2 独立源)
   - WebSearch "<校名> <区> 地址 电话"
   - WebSearch "<校名> 天津 学校 介绍"
   - 至少 2 源都确认: 存在 + 地址 + 区
   - 不够 2 源 → 报"信源不足, 跳过", 让用户提供 url 或确认手动

3. 构造新条目
   - 必填: name, district (18 区 enum), level (primary/middle), source = "WebResearch"
   - 可选: address, phone, is_private, sensitive.tier_label (如 web 明确标"重小")
   - source_url: 列出所有用到的 url (写 sensitive.note)
   - id: scripts/add_school.py 自动 sch_<md5[:10]>

4. Geocode 补 lat/lon
   - 优先 MKLocalSearch: cd scripts/geocode_mklocal && swift run GeocodeMK
     (只 redo failed/missing 条目, 已存在的不动)
   - 若 fail → 从 step 2 web 结果提取地址 + 手 fallback (或留 nil + 提示)

5. Pipeline (全自动, 无确认)
   ```bash
   source .venv/bin/activate
   python3 scripts/validate.py                # 必须 exit 0
   python3 scripts/build_zone_hulls.py        # 影响 zone 时
   python3 scripts/build_public_md.py
   cp reports/extracted/schools.json PropertyAtlas/PropertyAtlas/Resources/Seeds/
   cp reports/extracted/zones.json PropertyAtlas/PropertyAtlas/Resources/Seeds/
   ```

6. 通知 app
   - 报: "数据已更新. 点 app toolbar 的 ↻ 重载 按钮刷新; 或 ⌘R 重启 app."

## 工具调用

- 新增 / 更新条目: `python3 scripts/add_school.py --name <X> --district <Y> [--address <A>] [--phone <P>] [--level primary|middle] [--is-private] [--tier 重点|区重点|普通] [--source-url <U1> <U2>]`
- 脚本职责: 生成 id, merge 现有 sensitive, 写回 JSON (不跑 validate, skill 显式调用)

## 信源规则

- WebSearch 每次都加 `天津` 关键词避免歧义
- 至少 2 个独立域 (bendibao.com / jixiao100.com / qq.com / zhihu.com / zhihuishan.com / 学校官网)
- 不接受单源 (CAVEMAN: 单源 ≠ 核实)
- 用户口头确认存在 → source=`Manual`, source_url=`user-confirmation`, note 写明用户确认时间
- 全部 url 写 `sensitive.note` 字段, 主 url 写 `sensitive.source_url`

## Schema 约束

- `district` ∈ {和平区, 河西区, 南开区, 河东区, 河北区, 红桥区, 北辰区, 西青区, 津南区, 东丽区, 武清区, 宝坻区, 静海区, 宁河区, 蓟州区, 滨海新区, 塘沽区, 大港区}
- `level` ∈ {primary, middle}
- `tier_label` ∈ {重点, 区重点, 普通, ...} (见 `_common.schema.json`)
- `lat` ∈ [38.5, 40.3], `lon` ∈ [116.7, 118.0]
- 任何修改后必跑 `validate.py`, exit 非 0 → 不 cp seed

## 失败处理

- validate fail → 不 cp seed, 报错误 + 回滚 JSON (git checkout)
- geocode fail → 留 lat/lon=null, 报失败 (用户可手填)
- web 信源不足 → 列已找的源, 让用户确认或补 url

## 报告格式 (skill 结束输出)

```
✓ 添加 <校名> (<区>) — <new|updated>
  - lat/lon: 39.xxx, 117.xxx (mklocalsearch)
  - tier: 区重点 (2 源 cross-check)
  - 源: <url1>, <url2>
  - validate: pass
  - seed 已 cp, MD 已 rebuild
→ 点 app ↻ 重载 或 ⌘R 重启
```
