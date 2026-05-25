#!/usr/bin/env python3
"""
Restore sensitive fields into `sensitive` subobject on public JSON files.
- compounds.json: pros/cons → sensitive (YH-XLSX) + is_new_house=true
- schools.json: rank/top%/tier/comment → sensitive (MD-RANK)
- zones.json: highlight → sensitive (MD-ZONE)

Source codes:
- YH-XLSX = 永辉房产 2026 新房 xlsx
- MD-RANK = 中考排名md
- MD-ZONE = 学片划分md
- YH-PPTX = 永辉 落户上学买房 pptx
- JM-PDF  = 津门学路通 PDF
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / 'reports' / 'extracted'
PRIV = EXT / 'private'

# === 1. compounds.json: restore pros/cons + mark is_new_house ===
import pandas as pd
df = pd.read_excel(ROOT / 'reports' / '2026年永辉选房全天津项目优缺点(2).xlsx', header=None)
df = df.iloc[3:].copy()
df.columns = ['seq','district_group','district','project_name','available_units',
              'area_seg','price_seg','finish_type','delivery_time','pros','cons']
df = df[df['project_name'].notna() & df['seq'].notna()].copy()

# Build {name: (pros, cons)}
src_map = {}
for _, row in df.iterrows():
    name = str(row['project_name']).strip()
    pros = None if pd.isna(row['pros']) else str(row['pros']).strip()
    cons = None if pd.isna(row['cons']) else str(row['cons']).strip()
    src_map[name] = (pros, cons)

comps = json.loads((EXT / 'compounds.json').read_text(encoding='utf-8'))
for c in comps['items']:
    c['is_new_house'] = True
    c['source'] = 'YH-XLSX'
    pros, cons = src_map.get(c['name'], (None, None))
    c['sensitive'] = {
        'pros': pros,
        'cons': cons,
        'source': 'YH-XLSX',
        'note': '永辉房产主观点评, 仅作参考'
    }
comps['source_codes'] = {
    'YH-XLSX': '永辉房产 2026 新房 xlsx (2026年永辉选房全天津项目优缺点)',
}
(EXT / 'compounds.json').write_text(
    json.dumps(comps, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'compounds.json: restored sensitive (pros/cons) + is_new_house=true on {len(comps["items"])} items')

# === 2. schools.json: restore tier/rank from private/schools_middle.json ===
schools_public = json.loads((EXT / 'schools.json').read_text(encoding='utf-8'))
schools_priv = json.loads((PRIV / 'schools_middle.json').read_text(encoding='utf-8'))['items']

# Build {(district, name): sensitive_dict} from md-rank data
priv_map = {}
for s in schools_priv:
    # district in priv is like "河东" (no 区), public is "河东区"
    dist_full = s['district'] + '区' if not s['district'].endswith('区') else s['district']
    key = (dist_full, s['name'])
    priv_map[key] = {
        'rank_overall': s.get('rank_overall'),
        'top_percentile': s.get('top_percentile'),
        'tier_letter': s.get('tier_letter'),
        'tier_label': s.get('tier_label'),
        'tier_rank': s.get('tier_rank'),
        'comment': s.get('comment'),
        'data_origin': s.get('data_source'),
        'source': 'MD-RANK',
        'note': '基于家长群+教育自媒体整理, 误差±2-3名次, 仅反映梯队差异非精确数字'
    }

# Also try name-only match (cross-district variants)
priv_by_name = {}
for s in schools_priv:
    nm = s['name']
    priv_by_name.setdefault(nm, []).append(s)

import re
def norm(name, district):
    """Strip 天津市/天津/区前缀, 括号, （初中部）suffix → comparable base."""
    n = re.sub(r'^(天津市|天津)', '', name)
    n = re.sub(rf'^{district[:-1]}区?', '', n)  # strip district prefix
    n = re.sub(r'[（(].*?[）)]', '', n).strip()
    return n

def find_sensitive(school):
    dist = school['district']
    name = school['name']
    nb = norm(name, dist)
    # 1. exact district+name
    if (dist, name) in priv_map: return priv_map[(dist, name)]
    # 2. normalized match
    for (d, pname), v in priv_map.items():
        if d != dist: continue
        if norm(pname, d) == nb:
            return v
    return None

restored_schools = 0
for s in schools_public['items']:
    sens = find_sensitive(s)
    if sens:
        s['sensitive'] = sens
        restored_schools += 1
schools_public['source_codes'] = {
    'JM-PDF': '津门学路通 PDF (天津学校情况(4).pdf) — 学校信息(地址/电话/学费/学片/communities_text)',
    'MD-RANK': '中考排名md (天津市内六区初中中考成绩综合排名与Top百分位定位 2022-2025) — 评级/Top%/comment',
}
(EXT / 'schools.json').write_text(
    json.dumps(schools_public, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'schools.json: restored sensitive (rank/tier/Top%) on {restored_schools}/{len(schools_public["items"])} schools')

# === 3. zones.json: restore highlight from private/zones.json ===
zones_public = json.loads((EXT / 'zones.json').read_text(encoding='utf-8'))
zones_priv = json.loads((PRIV / 'zones.json').read_text(encoding='utf-8'))['items']
priv_zone_map = {(z['district'], z['zone_name']): z.get('highlight') for z in zones_priv}

restored_zones = 0
for z in zones_public['items']:
    # Private uses "和平一片", "和平二片", public uses "第一学片","第二学片"
    # Need fuzzy match
    cands = [
        (z['district'], z['zone_name']),
    ]
    # Try direct match
    hl = None
    for k in cands:
        if k in priv_zone_map and priv_zone_map[k]:
            hl = priv_zone_map[k]
            break
    # Try name fragment match by order number
    if not hl:
        def order_token(s):
            if '第一' in s or '一片' in s or '北片' in s or '一学区' in s: return 1
            if '第二' in s or '二片' in s or '中片' in s or '二学区' in s: return 2
            if '第三' in s or '三片' in s or '南片' in s or '三学区' in s: return 3
            if '第四' in s or '四片' in s or '四学区' in s: return 4
            if '第五' in s or '五学区' in s: return 5
            return 0
        pub_ord = order_token(z['zone_name'])
        if pub_ord:
            for (d, zn), text in priv_zone_map.items():
                if d == z['district'] and text and order_token(zn) == pub_ord:
                    hl = text
                    break
    if hl:
        z['sensitive'] = {
            'highlight': hl,
            'source': 'MD-ZONE',
            'note': '基于学片划分研究报告整理'
        }
        restored_zones += 1
zones_public['source_codes'] = {
    'JM-PDF': '津门学路通 PDF — 学片/学校 公开数据',
    'MD-ZONE': '学片划分md (天津市内六区小学与初中学片划分及实力排名深度研究报告 2024-2026版)',
}
(EXT / 'zones.json').write_text(
    json.dumps(zones_public, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'zones.json: restored sensitive (highlight) on {restored_zones}/{len(zones_public["items"])} zones')

print('\nDone. Sensitive data restored into `sensitive` subobjects.')
print('Source codes documented at top-level `source_codes` field.')
