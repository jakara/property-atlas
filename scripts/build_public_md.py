#!/usr/bin/env python3
"""Generate 天津学区房数据库.md from public JSON files.

Strips `sensitive` subobjects. Uses plain text (lists, indents) instead of tables.
Output: 天津学区房数据库.md at repo root.
"""
import json, re
from pathlib import Path
from collections import defaultdict
from datetime import date

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / 'reports' / 'extracted'
OUT = ROOT / '天津学区房数据库.md'

def load(name):
    return json.loads((EXT / name).read_text(encoding='utf-8'))

# Non-six raw data has authentic mid→primary mapping per item; merged zones lose it
non6_raw = json.loads((EXT / 'raw' / 'pdf_data_non6.json').read_text(encoding='utf-8'))

schools = load('schools.json')
zones = load('zones.json')
groups = load('groups.json')
policies = load('policies.json')

# Sensitive datasets — skipped from public MD output
compounds = load('compounds.json')
admission = load('admission_rates.json')
assert compounds.get('sensitive') is True, 'compounds.json must be marked sensitive'
assert admission.get('sensitive') is True, 'admission_rates.json must be marked sensitive'

# Indexes
schools_by_id = {s['id']: s for s in schools['items']}
schools_by_zone = defaultdict(list)
for s in schools['items']:
    if s.get('zone_id'):
        schools_by_zone[s['zone_id']].append(s)
zones_by_id = {z['id']: z for z in zones['items']}

# Order of city districts
CITY6 = ['和平区', '河西区', '南开区', '河东区', '河北区', '红桥区']
RING = ['北辰区', '西青区', '津南区', '东丽区']
FAR = ['武清区', '宝坻区', '静海区', '宁河区', '蓟州区']
BINHAI = ['滨海新区']
DISTRICT_ORDER = CITY6 + RING + FAR + BINHAI

def fmt_school_brief(s):
    """单行: 校名 (地址简, 电话). 民办校加标记."""
    bits = [s['name']]
    addr = (s.get('address') or '').strip()
    if addr:
        # Truncate long address
        if len(addr) > 50:
            addr = addr[:50] + '...'
        bits.append(addr)
    if s.get('phone'):
        bits.append(f"电话 {s['phone']}")
    tags = []
    if s.get('is_private'): tags.append('民办')
    if s.get('is_jiunian'): tags.append('九年一贯')
    if s.get('is_12year'): tags.append('十二年一贯')
    if s.get('is_market_five'): tags.append('市五所')
    elif s.get('is_market_key'): tags.append('市重点')
    if s.get('tuition'):
        tags.append(f"学费 {s['tuition']}")
    line = bits[0]
    if len(bits) > 1:
        line += " (" + ", ".join(bits[1:]) + ")"
    if tags:
        line += " [" + " · ".join(tags) + "]"
    return line

def fmt_school_inline(name_or_obj):
    """学校名简短引用."""
    if isinstance(name_or_obj, dict):
        return name_or_obj['name']
    return name_or_obj

lines = []
W = lines.append

# ============ 头部 ============
W("# 天津学区房数据库")
W("")
W(f"> 公开版本 · 生成日期 {date.today().isoformat()}")
W("> 整合 18 个区/板块的学区划分、学校信息、集团办学、入学政策.")
W("")
W("---")
W("")

# ============ 概览 ============
W("## 数据概览")
W("")
W(f"涵盖天津市 18 个行政区/板块, 共收录:")
W("")
prim = sum(1 for s in schools['items'] if s['level']=='primary')
mid = sum(1 for s in schools['items'] if s['level']=='middle')
W(f"- 学校 **{schools['count']}** 所 ({prim} 所小学, {mid} 所中学)")
W(f"- 学区/学片 **{zones['count']}** 个")
W(f"- 教育集团 **{groups['count']}** 个 (市内六区)")
W(f"- 入学/落户/中考 政策条款 **{policies['count']}** 条")
prim_with_comm = sum(1 for s in schools['items'] if s['level']=='primary' and (s.get('communities_text') or '').strip())
W(f"- 小学招生范围 (居委会/小区清单) **{prim_with_comm}** 所")
W("")
W("数据组织为以下章节:")
W("")
W("- 一、市内六区学片划分 — 和平、河西、南开、河东、河北、红桥")
W("- 二、环城+远郊+滨海 学校分布")
W("- 三、各小学招生范围 (居委会/小区 → 小学)")
W("- 四、集团化办学关系")
W("- 五、入学落户中考政策摘要")
W("")
W("---")
W("")

# ============ 一、市内六区学片划分 ============
W("## 一、市内六区学片划分")
W("")
W("市内六区 (和平、河西、南开、河东、河北、红桥) 实行 **小升初多校划片+随机派位** (即\"摇号\"). 同一学片内的小学应届毕业生统一摇号录取该片内的公办初中. 各小学按其招生范围 (居委会/小区/街道) 划片.")
W("")

CITY6_NOTE = {
    '和平区': '面积约 9.98 平方公里, 划分 3 学片, 各片每年 8 个志愿 (4 所片内公办 + 1 所全区招生第二耀华 + 3 所民办).',
    '河西区': '划分 3 学片, 各片需填满公办志愿 + 河西 3 所民办可选.',
    '南开区': '独特分为 北片/中片/南片 (以长江道和复康路为界). 最多选报 6 所志愿, 片内公办不少于 4 所.',
    '河东区': '划分 4 学区 (第五学区为河北涉县飞地, 对应天铁系学校). 民办校 2022 起停招.',
    '河北区': '划分 3 学区片, 公办为主, 含河北外国语中学 (区重点).',
    '红桥区': '划分 3 学区, 民办校全部停招.',
}

for d in CITY6:
    W(f"### {d}")
    W("")
    if d in CITY6_NOTE:
        W(CITY6_NOTE[d])
        W("")
    d_zones = [z for z in zones['items'] if z['district']==d and z['zone_name'] != '行政区域']
    for z in d_zones:
        title = z['zone_name']
        if z.get('note'):
            note = z['note']
            # Strip leading 含/( to avoid double-prefix
            note = re.sub(r'^[（(]?含?', '', note).rstrip('）)').strip()
            if note:
                title += f" (含{note})"
        W(f"#### {title}")
        W("")
        # Middle school pool
        mid_pool = z.get('middle_school_pool') or []
        if mid_pool:
            W(f"对应公办初中 {len(mid_pool)} 所: {'、'.join(mid_pool)}.")
            W("")
        # Primary schools in this zone
        prims = [s for s in schools_by_zone.get(z['id'], []) if s['level']=='primary']
        if prims:
            W(f"对应小学 ({len(prims)} 所):")
            W("")
            for s in prims:
                W(f"- {fmt_school_brief(s)}")
            W("")
        # Middle schools detail in zone
        mids = [s for s in schools_by_zone.get(z['id'], []) if s['level']=='middle']
        if mids:
            W("各初中详情:")
            W("")
            for s in mids:
                W(f"- {fmt_school_brief(s)}")
            W("")
    W("---")
    W("")

# ============ 二、非市内六区 ============
W("## 二、环城四区、远郊五区、滨海新区学校分布")
W("")
W("非市内六区采用 **单校划片** (中学与小学一一或一对多对口) 或 **学片区号** 制度 (津南/滨海). 部分远郊用地理边界描述对口区域 (静海/蓟州/宁河/武清).")
W("")

for d in RING + FAR + BINHAI:
    W(f"### {d}")
    W("")
    def zsort(zn):
        # "<district>-<prefix><num>": group by prefix, then numeric. e.g. 塘沽1 < 塘沽2 < ... < 塘沽21 < 汉沽1 ...
        m = re.search(r'^([^\d-]+(?:-[^\d-]+)?)(\d+)?$', zn.replace(d+'-',''))
        if m:
            prefix, num = m.group(1), m.group(2)
            return (0, prefix, int(num) if num else 0)
        return (1, zn, 0)
    d_zones = sorted([z for z in zones['items'] if z['district']==d],
                     key=lambda x: (x['zone_name']=='行政区域', zsort(x['zone_name'])))
    schools_d = [s for s in schools['items'] if s['district']==d]
    prim_d = [s for s in schools_d if s['level']=='primary']
    mid_d = [s for s in schools_d if s['level']=='middle']
    W(f"辖区共 {len(mid_d)} 所中学, {len(prim_d)} 所小学.")
    W("")
    # For each non-"行政区域" zone show mid→prim mapping if exists
    sub_zones = [z for z in d_zones if z['zone_name'] != '行政区域']
    if sub_zones:
        W("分学片对应关系:")
        W("")
        for z in sub_zones:
            zn = z['zone_name']
            mids_in_z = [s for s in schools_by_zone.get(z['id'], []) if s['level']=='middle']
            prims_in_z = [s for s in schools_by_zone.get(z['id'], []) if s['level']=='primary']
            if not (mids_in_z or prims_in_z): continue
            line = f"- **{zn}**"
            if mids_in_z:
                line += f": 中学 {'、'.join(s['name'] for s in mids_in_z)}"
            if prims_in_z:
                line += f"; 小学 {'、'.join(s['name'] for s in prims_in_z)}"
            line += "."
            W(line)
        W("")
    else:
        # Use non6 raw for authentic mid→primary mapping per item
        raw_d = non6_raw.get('districts', {}).get(d, {})
        items = raw_d.get('items', [])
        if items:
            structure = raw_d.get('structure', '')
            W(f"对应结构 ({structure}):")
            W("")
            for it in items:
                mids = it.get('middle')
                if isinstance(mids, list):
                    mid_names = mids
                elif mids:
                    mid_names = [mids]
                else:
                    mid_names = []
                prim_names = it.get('primary') or []
                if not isinstance(prim_names, list):
                    prim_names = [prim_names]
                areas = it.get('areas') or ''
                zone_num = it.get('zone_num') or it.get('zone')
                mid_str = '、'.join(mid_names) if mid_names else '(无)'
                if prim_names:
                    detail = f"对口小学: {'、'.join(prim_names)}"
                elif areas:
                    snippet = areas[:120] + ('...' if len(areas) > 120 else '')
                    detail = f"片区范围: {snippet}"
                else:
                    detail = ''
                prefix = f"**{zone_num}** " if zone_num else ''
                W(f"- {prefix}{mid_str}" + (f" — {detail}" if detail else ''))
            W("")
    W("---")
    W("")

# ============ 三、各小学招生范围 ============
W("## 三、各小学招生范围 (居委会 / 小区 → 小学)")
W("")
W("以下列出市内六区各小学的招生范围 (居委会、小区、楼号区间). 当户籍 / 房产位于某社区时, 适龄儿童默认对口该社区所在的小学.")
W("")
W("> 数据来自天津市教育局公开发布的学区招生方案. 个别字段可能含少量字符级误读, 实际入学以当年各区教育局公告为准.")
W("")

for d in CITY6:
    d_zones_3 = [z for z in zones['items'] if z['district']==d and z['zone_name'] != '行政区域']
    if not d_zones_3: continue
    any_text = any(
        (s.get('communities_text') or '').strip()
        for z in d_zones_3 for s in schools_by_zone.get(z['id'], []) if s['level']=='primary'
    )
    if not any_text: continue
    W(f"### {d}")
    W("")
    for z in d_zones_3:
        prims = [s for s in schools_by_zone.get(z['id'], []) if s['level']=='primary'
                 and (s.get('communities_text') or '').strip()]
        if not prims: continue
        W(f"#### {z['zone_name']}")
        W("")
        for s in prims:
            tag = ' (民办)' if s.get('is_private') else ''
            W(f"**{s['name']}**{tag}")
            W("")
            text = s['communities_text'].strip()
            text = re.sub(r'\s+', ' ', text)
            W(text)
            W("")
W("---")
W("")

# ============ 四、集团化办学 ============
W("## 四、集团化办学关系")
W("")
W("市内六区共 32 个教育集团 / 共同体. 集团内 \"牵头校\" 与 \"成员校\" 共享师资、招生方案. 转学/升学常按集团内调配.")
W("")

groups_by_d = defaultdict(list)
for g in groups['items']:
    groups_by_d[g['district']].append(g)

for d in CITY6:
    if d not in groups_by_d: continue
    W(f"### {d}")
    W("")
    for g in groups_by_d[d]:
        leads = '、'.join(L['name'] for L in g['leads'])
        members = [m['name'] for m in g['members'] if m['name'] != '?(图中关系不明)']
        line = f"- **{g['name']}** — 牵头校: {leads}"
        if members:
            line += f"; 成员校: {'、'.join(members)}"
        line += "."
        W(line)
    W("")

if groups.get('warnings'):
    W("> 备注: 部分学校名因 PDF 视觉转录可能存在歧义, 已标 \"?(图中关系不明)\". (停招) 表示该校已停止招生, 但学籍仍在原集团内.")
    W("")
W("---")
W("")

_SKIP_COMPOUNDS = """# ============ 楼盘 (SENSITIVE — SKIPPED) ============
W("## 在售新房楼盘 (2026)")
W("")
W(f"永辉房产 2026 年新房在售清单, 共 {compounds['count']} 个项目. 按区域分组. 主观评价 (优缺点/梯队) 已剥离, 仅公开客观字段 (面积段/价格段/交付标准/可售套数).")
W("")
W("> 楼盘 → 学区/小学 自动匹配命中率较低 (xlsx 新楼盘品牌名与 PDF 老居委会/小区命名不重合). 当前 7/174 自动命中, 余 167 需人工补全或地理标注.")
W("")

DG_ORDER = ['市内六区', '环城四区', '远郊五区', '滨海新区']
comps_by_dg = defaultdict(lambda: defaultdict(list))
for c in compounds['items']:
    comps_by_dg[c.get('district_group') or '其他'][c['district']].append(c)

for dg in DG_ORDER:
    if dg not in comps_by_dg: continue
    W(f"### {dg}")
    W("")
    for d, lst in sorted(comps_by_dg[dg].items()):
        W(f"#### {d} ({len(lst)} 个项目)")
        W("")
        for c in lst:
            bits = [c['name']]
            if c.get('available_units') and c['available_units'].get('raw'):
                bits.append(c['available_units']['raw'])
            if c.get('area_segments'):
                a = c['area_segments'].replace('\n', ' ')[:60]
                bits.append(f"面积 {a}")
            if c.get('price_segments'):
                p = c['price_segments'].replace('\n', '; ')[:80]
                bits.append(f"价格 {p}")
            if c.get('finish_type'):
                bits.append(c['finish_type'])
            if c.get('delivery_time'):
                bits.append(f"交付 {c['delivery_time']}")
            W(f"- **{bits[0]}** — " + " — ".join(bits[1:]))
        W("")
    W("---")
    W("")

"""

# ============ 五、政策摘要 ============
W("## 五、入学落户中考政策摘要")
W("")
W(f"共 {policies['count']} 条政策条款. 按类别分组.")
W("")

CAT_ORDER = ['落户', '入学', '转学', '小升初', '中考', '高考']
pol_by_cat = defaultdict(list)
for p in policies['items']:
    pol_by_cat[p.get('category', '其他')].append(p)

for cat in CAT_ORDER:
    if cat not in pol_by_cat: continue
    W(f"### {cat}")
    W("")
    for p in pol_by_cat[cat]:
        sub = p.get('subcategory', '')
        W(f"#### {p['name']}" + (f" ({sub})" if sub else ''))
        W("")
        if p.get('description'):
            W(p['description'])
            W("")
        if p.get('effective_date'):
            W(f"生效日期: {p['effective_date']}")
            W("")
        if p.get('eligibility'):
            W("适用条件:")
            for e in p['eligibility']:
                W(f"- {e}")
            W("")
        if p.get('rules'):
            W("规则:")
            for r in p['rules']:
                W(f"- {r}")
            W("")
        if p.get('docs'):
            W("所需材料:")
            for d in p['docs']:
                W(f"- {d}")
            W("")
        if p.get('steps'):
            W("办理步骤:")
            for i, s in enumerate(p['steps'], 1):
                W(f"{i}. {s}")
            W("")
        if p.get('caveats'):
            W("注意事项:")
            for c in p['caveats']:
                W(f"- {c}")
            W("")
        if p.get('schools'):
            W("适用学校: " + '、'.join(p['schools']))
            W("")
        if p.get('applicable'):
            W("适用范围:")
            for a in p['applicable']:
                W(f"- {a}")
            W("")
        if p.get('rules_by_district'):
            W("各区规则:")
            for d, r in p['rules_by_district'].items():
                W(f"- {d}: {r}")
            W("")
        if p.get('note'):
            W(f"备注: {p['note']}")
            W("")
        if p.get('source'):
            W(f"_来源: {p['source']}_")
            W("")
W("---")
W("")

_SKIP_ADMISSION = """# ============ 六、中考录取率 (SENSITIVE — SKIPPED) ============
W("## 六、各区中考录取率 (2023 年估算)")
W("")
W("反映各区高中升学概率梯度. 数据来自永辉房产整理, 仅作梯度参考, 非精确数字.")
W("")
for r in admission['items']:
    line = f"- **{r['district']}** — 普高录取率约 {r['gaokao_admit_pct']}%"
    if r.get('vocational_admit_pct') is not None:
        line += f", 职高录取率约 {r['vocational_admit_pct']}%"
    W(line)
W("")
W("> 天津 \"锁区\" 政策: 市内六区 + 海教园 为一个考区统考, 其他区只能考本区高中. 市九所 (一中/南开/耀华/新华/实验/二南开/二十中/天津中学/七中) 面向各区投放少量名额.")
W("")
W("---")
W("")

"""

_SKIP_SOURCES = """# ============ 七、数据来源 (REMOVED) ============
W("## 七、数据来源与版权说明")
W("")
W("### 公开数据源")
W("")
W("- **津门学路通 2023版 PDF** — 整理者: 永辉房产. 内容为天津市教育局公开发布的学区招生方案汇编. 用于本数据集的: 学校信息(地址/电话/民办/学费/学片归属)、学区/学片划分、集团化办学关系、居委会/小区→小学对照.")
W("- **永辉房产 2026 新房清单 (xlsx)** — 永辉房产整理的 2026 年天津新房在售项目客观信息 (项目名/区域/面积段/价格段/交付/可售). 主观评价部分未公开.")
W("- **2026 永辉选房落户上学 pptx** — 落户政策 (海河英才四型/积分落户/子女随迁/父母投靠)、入学转学政策 (六年一学位/五证/公民同摇)、中考报名要求等. 这些是天津各区教育局/公安局陆续发布的公开政策汇编.")
W("- **各区教育局公告** (2024-2025) — 河东/南开/河西/和平/生态城等区关于二手房三年限制、初中外省回户籍升学等政策更新.")
W("")
W("### 不公开的主观评级数据")
W("")
W("以下数据**不包含**在本公开数据集:")
W("")
W("- 各校中考梯队 (A++/A+/A/B+/B/C+/C/D)")
W("- 各校 Top% 排名 (Top 1%-100%)")
W("- 学片实力简评")
W("- 楼盘优缺点 (永辉主观点评)")
W("")
W("原因: 天津市教委自 2021 年起禁止学校公开宣传中考成绩、状元、升学率. 上述数据来自家长群、教育自媒体的内部流出版本, 存在 ±2-3 名次浮动, 仅反映梯队差异而非精确数字.")
W("")
W("### 已知数据质量风险")
W("")
W("- PDF 通过 Claude vision 提取, 居委会/小区→小学映射的文本中嵌入的数字门牌号可能有少量字符级误读 (~5-10%). 用于关键词匹配可用, 不可作正式入学依据.")
W("- 新楼盘品牌名 (如 \"中国铁建西派国印\") 与 PDF 居委会/老小区命名不重合, 自动匹配率受限.")
W("- 政策时效冻结于 2026-05-25, 后续年度以当年教育局正式发布为准.")
W("- 集团化办学 (PDF P30) 部分校名因图标转录存在歧义, 已标注 (停招)/?(图中关系不明).")
W("")
W("### 许可")
W("")
W("本数据集汇编于天津市教育局公开发布的招生方案与开源整理. 学校信息、学区划分、政策原文均为政府公开数据.")
W("")
W("- 允许: 个人查询、学术研究、非商业转载 (需注明数据来源)")
W("- 禁止: 商业销售本数据集 (学校官方信息归各校所有; 楼盘销售信息归开发商所有)")
W("- 不构成: 升学/购房决策依据")
W("")
W("### 反馈与贡献")
W("")
W("欢迎补全:")
W("")
W("- 楼盘 → 学校的地理匹配 (167/174 待补)")
W("- 集团化办学未匹配学校名 (12 条待校对)")
W("- 环城/远郊地理片区的结构化拆分")
W("- 各区民办校年度学费更新")
W("")
W("---")
W("")
"""

W(f"_本文档由 `scripts/build_public_md.py` 自动生成, 数据快照 {date.today().isoformat()}._")

# Write
text = '\n'.join(lines)
OUT.write_text(text, encoding='utf-8')
print(f'Wrote {OUT.name} ({len(text)} chars, {text.count(chr(10))+1} lines)')
