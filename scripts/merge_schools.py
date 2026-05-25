#!/usr/bin/env python3
"""Merge primary + middle schools into single schools.json with zone links."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / 'reports' / 'extracted'

middle = json.loads((EXT / 'schools_middle.json').read_text(encoding='utf-8'))['items']
primary = json.loads((EXT / 'schools_primary.json').read_text(encoding='utf-8'))['items']
zones   = json.loads((EXT / 'zones.json').read_text(encoding='utf-8'))['items']

# Build a zone_label -> zone_id map per district
zone_lookup = {}
for z in zones:
    # short label e.g. "和平一片" — primary md uses these short labels; middle rank md uses things like "一片"
    label = z['zone_name']
    # canonical: district + short suffix (一片/二片/三片/第N学区/北片/中片/南片)
    zone_lookup[(z['district'], label)] = z['id']
    # also index by truncated label
    short = label.split('（')[0].split('(')[0]
    zone_lookup[(z['district'], short)] = z['id']

def find_zone_id(district, zone_label):
    if not zone_label or zone_label == '—' or zone_label == '全区招生':
        return None
    # Try district variants — middle uses "和平", primary uses "和平区"
    d_full = district if district.endswith('区') else district + '区'
    candidates = [(d_full, zone_label)]
    # short form match e.g. "一片" → "和平一片"
    if zone_label in ('一片','二片','三片','北片','中片','南片'):
        candidates.append((d_full, d_full[:2] + zone_label))
    if zone_label in ('一片','二片','三片','四片'):
        # map to 第N学区 for 河东
        nums = {'一片':'第一学区','二片':'第二学区','三片':'第三学区','四片':'第四学区'}
        candidates.append((d_full, nums[zone_label]))
    if zone_label in ('一片','二片','三片'):
        # map to 第N学区片 for 河北 + 第N学区 for 红桥
        nums = {'一片':'第一学区片','二片':'第二学区片','三片':'第三学区片'}
        candidates.append((d_full, nums[zone_label]))
        nums2 = {'一片':'第一学区','二片':'第二学区','三片':'第三学区'}
        candidates.append((d_full, nums2[zone_label]))
    for c in candidates:
        if c in zone_lookup: return zone_lookup[c]
        # try substring match
        for k, v in zone_lookup.items():
            if k[0] == c[0] and (k[1].startswith(c[1]) or c[1] in k[1]):
                return v
    return None

# Attach zone_id to middle schools
matched = 0
for s in middle:
    z = find_zone_id(s['district'], s['zone_label'])
    s['zone_id'] = z
    if z: matched += 1

# primary schools already have zone_id from extract_zones.py
all_schools = primary + middle

(EXT / 'schools.json').write_text(json.dumps(
    {'version':'2026.05.25','count':len(all_schools),'items':all_schools},
    ensure_ascii=False, indent=2), encoding='utf-8')

print(f'Total schools: {len(all_schools)} (primary {len(primary)}, middle {len(middle)})')
print(f'Middle schools matched to zone: {matched}/{len(middle)}')
unmatched = [(s['name'], s['district'], s['zone_label']) for s in middle if not s['zone_id']]
print(f'Unmatched ({len(unmatched)}):')
for u in unmatched[:20]:
    print(' ', u)
