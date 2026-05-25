#!/usr/bin/env python3
"""Parse 中考排名 md → schools.json (middle schools with tier + Top%)."""
import re, json, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RANK_MD = ROOT / 'reports' / '天津市内六区初中中考成绩综合排名与 Top 百分位定位（2022–2025 综合）.md'
OUT = ROOT / 'reports' / 'extracted' / 'schools_middle.json'

def sid(name):
    return 'sch_' + hashlib.md5(name.encode()).hexdigest()[:10]

def parse_top(s):
    s = s.strip()
    m = re.match(r'Top\s*(\d+)%', s)
    if m: return int(m.group(1))
    m = re.match(r'Top\s*(\d+)[–-](\d+)%', s)
    if m: return (int(m.group(1)) + int(m.group(2))) // 2
    return None

TIER_MAP = {
    'A++': {'label':'顶尖','rank':1},
    'A+':  {'label':'强校','rank':2},
    'A':   {'label':'优质','rank':3},
    'B+':  {'label':'中上','rank':4},
    'B':   {'label':'中档','rank':5},
    'C+':  {'label':'中下','rank':6},
    'C':   {'label':'偏弱','rank':7},
    'D-':  {'label':'垫底','rank':8},
    'D':   {'label':'垫底','rank':8},
    '新办': {'label':'新办','rank':99},
    '新办/合作': {'label':'新办','rank':99},
}

text = RANK_MD.read_text(encoding='utf-8')
# match data rows in ranking tables
# format: | 排名 | 学校全称 | 区 | 学片 | Top% | 梯队 | 中考实力简评 | 数据依据 |
schools = []
seen_names = set()
for line in text.split('\n'):
    line = line.strip()
    if not line.startswith('|'): continue
    cells = [c.strip() for c in line.split('|')[1:-1]]
    if len(cells) != 8: continue
    rank, name, district, zone, top_str, tier, comment, source = cells
    if rank in ('排名','---') or not rank: continue
    if name in seen_names or name == '—' or name == '学校全称': continue
    if name.startswith('天津市第二十中学（南开校区'): continue  # dup note
    if '重复列出' in name or '（重复' in name: continue  # dedupe
    if district == '—' and zone == '—': continue  # skip junk rows
    try:
        rank_n = int(rank)
    except ValueError:
        continue
    seen_names.add(name)
    top = parse_top(top_str)
    tier_info = TIER_MAP.get(tier, {'label':'未知','rank':0})
    # 市五所/市九所 — exact name match (full school name, well-known)
    MARKET_FIVE_EXACT = {
        '南开中学（公办）',
        '天津新华中学（初中部）',
        '天津市实验中学（初中部）',
        '耀华中学（初中部）',
        '天津一中（初中部）',
    }
    MARKET_NINE_EXACT = MARKET_FIVE_EXACT | {
        '第二南开学校（初中部）',
        '天津市第二十中学（初中部）',
        '天津中学（初中部）',
        '天津市第七中学（初中部）',
        '天津市第四中学（初中部）',
        '天津市第四十二中学（初中部）',
        '天津市第一〇二中学（初中部）',
    }
    is_m5 = name in MARKET_FIVE_EXACT
    is_m9 = name in MARKET_NINE_EXACT
    is_private = '民办' in comment or '九年一贯' in comment and '日新' in name
    schools.append({
        'id': sid(name),
        'name': name,
        'district': district,
        'zone_label': zone,
        'level': 'middle',
        'rank_overall': rank_n,
        'top_percentile': top,
        'tier_letter': tier,
        'tier_label': tier_info['label'],
        'tier_rank': tier_info['rank'],
        'is_market_five': is_m5,
        'is_market_nine': is_m9,
        'is_public_inferred': '公办' in comment or (not '民办' in comment and '翔宇' not in name and '益中' not in name and '双菱' not in name and '日新' not in name and '建华' not in name and '嘉诚' not in name and '美达菲' not in name and '华星' not in name and '海河博爱' not in name and '津英' not in name and '育贤' not in name and '弘德' not in name),
        'comment': comment,
        'data_source': source,
        'source_doc': '天津市内六区初中中考成绩综合排名md',
    })

OUT.write_text(json.dumps({'version':'2026.05.25','count':len(schools),'items':schools},
                          ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Wrote {len(schools)} middle schools to {OUT.name}')

# Districts and zones summary
from collections import Counter
print('Districts:', Counter(s['district'] for s in schools))
print('Tiers:', Counter(s['tier_letter'] for s in schools))
print('市五所:', [s['name'] for s in schools if s['is_market_five']])
