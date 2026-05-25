#!/usr/bin/env python3
"""Merge 7 PDF raw JSON files → final public schools.json + zones.json + compound_school_match.json."""
import json, re, hashlib
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / 'reports' / 'extracted' / 'raw'
OUT = ROOT / 'reports' / 'extracted'

def sid(name, prefix='sch_'):
    return prefix + hashlib.md5(name.encode()).hexdigest()[:10]

def zid(district, zone):
    return 'zon_' + hashlib.md5(f'{district}|{zone}'.encode()).hexdigest()[:10]

# Load all 6 city district files
city_files = ['pdf_data_heping.json', 'pdf_data_hexi.json', 'pdf_data_nankai.json',
              'pdf_data_hebei.json', 'pdf_data_hedong.json', 'pdf_data_hongqiao.json']
city_data = []
for f in city_files:
    city_data.append(json.loads((RAW / f).read_text(encoding='utf-8')))

# Build unified zones + schools
zones, schools = [], []
seen_zones, seen_schools = set(), set()

for d in city_data:
    district = d['district']
    for z in d['zones']:
        zone_name = z['zone_name']
        z_id = zid(district, zone_name)
        if z_id in seen_zones: continue
        seen_zones.add(z_id)
        zones.append({
            'id': z_id,
            'district': district,
            'zone_name': zone_name,
            'note': z.get('note'),
            'middle_school_pool': z.get('middle_school_pool', []),
        })
        # primary schools
        for p in z.get('primary_schools', []):
            s_id = sid(f"{district}-{p['name']}")
            if s_id in seen_schools: continue
            seen_schools.add(s_id)
            schools.append({
                'id': s_id,
                'name': p['name'],
                'district': district,
                'zone_id': z_id,
                'zone_name': zone_name,
                'level': 'primary',
                'address': p.get('addr') or p.get('campuses_addr'),
                'phone': p.get('phone'),
                'campuses': p.get('campuses'),
                'is_private': p.get('is_private', False),
                'is_jiunian': p.get('is_jiunian', False),
                'is_market_key': p.get('is_market_key', False),
                'tuition': p.get('tuition'),
                'note': p.get('note'),
                'communities_text': p.get('communities_text') or p.get('community_text') or '',
                'source': 'JM-PDF',
            })
        # middle schools
        for m in z.get('middle_schools_detail', []):
            s_id = sid(f"{district}-{m['name']}")
            if s_id in seen_schools: continue
            seen_schools.add(s_id)
            schools.append({
                'id': s_id,
                'name': m['name'],
                'district': district,
                'zone_id': z_id,
                'zone_name': zone_name,
                'level': 'middle',
                'address': m.get('addr') or m.get('address'),
                'phone': m.get('phone'),
                'is_private': m.get('is_private', False),
                'is_jiunian': m.get('is_jiunian', False),
                'is_12year': m.get('is_12year', False),
                'is_market_five': m.get('is_market_five', False),
                'is_market_key': m.get('is_market_key', False),
                'tuition': m.get('tuition'),
                'note': m.get('note'),
                'source': 'JM-PDF',
            })

# Load non-six districts
non6 = json.loads((RAW / 'pdf_data_non6.json').read_text(encoding='utf-8'))
for district, ddata in non6['districts'].items():
    z_id = zid(district, '行政区域')
    zones.append({
        'id': z_id,
        'district': district,
        'zone_name': '行政区域',
        'structure': ddata['structure'],
        'middle_school_pool': [],
    })
    seen_zones.add(z_id)
    for item in ddata.get('items', []):
        mids = item.get('middle', []) if isinstance(item.get('middle'), list) else [item.get('middle')] if item.get('middle') else []
        prims = item.get('primary', []) if isinstance(item.get('primary'), list) else [item.get('primary')] if item.get('primary') else []
        areas = item.get('areas') or ''
        zone_num = item.get('zone_num') or item.get('zone')
        sub_zone_name = (f"{district}-{zone_num}" if zone_num else None) or '行政区域'
        sub_z_id = zid(district, sub_zone_name) if zone_num else z_id
        if zone_num and sub_z_id not in seen_zones:
            seen_zones.add(sub_z_id)
            zones.append({
                'id': sub_z_id,
                'district': district,
                'zone_name': sub_zone_name,
                'middle_school_pool': mids,
                'areas_text': areas,
            })
        for n in mids:
            if not n: continue
            s_id = sid(f"{district}-{n}")
            if s_id in seen_schools: continue
            seen_schools.add(s_id)
            schools.append({
                'id': s_id, 'name': n, 'district': district,
                'zone_id': sub_z_id, 'zone_name': sub_zone_name,
                'level': 'middle',
                'communities_text': areas,
                'source': 'JM-PDF',
            })
        for n in prims:
            if not n: continue
            s_id = sid(f"{district}-{n}")
            if s_id in seen_schools: continue
            seen_schools.add(s_id)
            schools.append({
                'id': s_id, 'name': n, 'district': district,
                'zone_id': sub_z_id, 'zone_name': sub_zone_name,
                'level': 'primary',
                'communities_text': areas,
                'source': 'JM-PDF',
            })

(OUT / 'schools_public.json').write_text(json.dumps(
    {'version':'2026.05.25','source':'PDF 津门学路通',
     'count': len(schools), 'items': schools},
    ensure_ascii=False, indent=2), encoding='utf-8')

(OUT / 'zones_public.json').write_text(json.dumps(
    {'version':'2026.05.25','source':'PDF 津门学路通',
     'count': len(zones), 'items': zones},
    ensure_ascii=False, indent=2), encoding='utf-8')

print(f'Wrote {len(zones)} zones, {len(schools)} schools')
prim = sum(1 for s in schools if s['level']=='primary')
mid = sum(1 for s in schools if s['level']=='middle')
print(f'  primary={prim}, middle={mid}')
by_dist = defaultdict(lambda: [0,0])
for s in schools:
    by_dist[s['district']][0 if s['level']=='primary' else 1] += 1
for d, (p, m) in sorted(by_dist.items()):
    print(f'  {d}: {p}p + {m}m')

# ============ Match 174 compounds → schools/zones ============
comps = json.loads((OUT / 'compounds.json').read_text(encoding='utf-8'))['items']

# Build per-district index: school → community keywords
def tokenize_communities(text):
    if not text: return []
    text = re.sub(r'[\d\-、，,\s号楼栋单双双号〕\)\(\[\]【】（）]+', ' ', text)
    tokens = [t.strip() for t in text.split() if len(t.strip()) >= 2]
    return [t for t in tokens if not re.match(r'^[一二三四五六七八九十0-9]+$', t)]

# index[district] = list of (school_id, school_name, level, tokens_set)
index = defaultdict(list)
for s in schools:
    if s['level'] not in ('primary','middle'): continue
    text = s.get('communities_text','') or ''
    tokens = set(tokenize_communities(text))
    if not tokens: continue
    index[s['district']].append({
        'id': s['id'], 'name': s['name'], 'level': s['level'],
        'zone_id': s['zone_id'], 'zone_name': s['zone_name'],
        'tokens': tokens,
    })

# Normalize compound district to match school district
DIST_MAP = {
    '和平区':'和平区','南开区':'南开区','河东区':'河东区','河西区':'河西区','河北区':'河北区','红桥区':'红桥区',
    '北辰区':'北辰区','西青区':'西青区','津南区':'津南区','东丽区':'东丽区',
    '武清区':'武清区','宝坻区':'宝坻区','静海区':'静海区','宁河区':'宁河区','蓟州区':'蓟州区',
    '塘沽区':'滨海新区','大港区':'滨海新区',
}
# Also build index of school NAMES per district for pros/cons hint extraction
all_schools_by_dist = defaultdict(list)
for s in schools:
    all_schools_by_dist[s['district']].append(s)

def extract_school_hints(text, district):
    """Find school names mentioned in pros/cons text."""
    if not text: return []
    hits = []
    for s in all_schools_by_dist.get(district, []):
        nm = s['name']
        # Remove parenthetical / variants
        base = re.sub(r'[（(].*?[）)]', '', nm).strip()
        # Try matching by base name OR common short form
        candidates = [base]
        # 昆纬路第一小学 → 昆一; 第四十二中学 → 42中; 第七中学 → 七中
        m = re.match(r'^(\D+?)(第)?([一二三四五六七八九十百0-9]+)\D*?(小学|中学|学校)$', base)
        if m:
            prefix, _, num, suffix = m.groups()
            sn = {'第一':'一','第二':'二','第三':'三','第四':'四','第五':'五','第六':'六','第七':'七','第八':'八','第九':'九','第十':'十'}.get(num, num)
            candidates.append(f'{prefix}{sn}{suffix[0]}')  # e.g. 昆一小
            candidates.append(f'{sn}{suffix[0]}')  # e.g. 七中, 一中
        for c in candidates:
            if c and len(c) >= 2 and c in text:
                hits.append({'school_id': s['id'], 'school_name': s['name'],
                             'zone_id': s['zone_id'], 'zone_name': s['zone_name'],
                             'level': s['level'], 'matched_via': f'hint:{c}'})
                break
    return hits

matches = []
for c in comps:
    cdist = DIST_MAP.get(c['district'], c['district'])
    name = c['name']
    pros_cons = (c.get('pros','') or '') + ' ' + (c.get('cons','') or '')
    matched_prim, matched_mid = [], []

    # 1. Match via community_text token in compound name
    for school in index.get(cdist, []):
        for tk in school['tokens']:
            if len(tk) >= 2 and (tk in name):
                ent = {'school_id': school['id'], 'school_name': school['name'],
                       'zone_id': school['zone_id'], 'zone_name': school['zone_name'],
                       'matched_via': f'community:{tk}'}
                if school['level'] == 'primary':
                    matched_prim.append(ent)
                else:
                    matched_mid.append(ent)
                break

    # 2. Match via school-name hints in pros/cons text
    hints = extract_school_hints(pros_cons, cdist)
    for h in hints:
        if h['level'] == 'primary':
            if not any(p['school_id']==h['school_id'] for p in matched_prim):
                matched_prim.append(h)
        else:
            if not any(p['school_id']==h['school_id'] for p in matched_mid):
                matched_mid.append(h)

    matches.append({
        'compound_id': c['id'], 'compound_name': name,
        'district': c['district'], 'mapped_district': cdist,
        'primary_matches': matched_prim,
        'middle_matches': matched_mid,
        'needs_manual_review': not (matched_prim or matched_mid),
    })

(OUT / 'compound_school_match.json').write_text(json.dumps(
    {'version':'2026.05.25','count': len(matches), 'items': matches},
    ensure_ascii=False, indent=2), encoding='utf-8')

matched_p = sum(1 for m in matches if m['primary_matches'])
matched_m = sum(1 for m in matches if m['middle_matches'])
print(f'\nCompound matches: {matched_p}/{len(matches)} primary, {matched_m}/{len(matches)} middle')
print('Sample matches:')
for m in matches[:30]:
    if m['primary_matches'] or m['middle_matches']:
        ps = ','.join(p['school_name'] for p in m['primary_matches'][:2])
        ms = ','.join(p['school_name'] for p in m['middle_matches'][:2])
        print(f"  {m['district']:<6} {m['compound_name']:<20} → P:{ps[:30]:<30} M:{ms[:30]}")
