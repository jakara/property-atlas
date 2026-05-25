#!/usr/bin/env python3
"""Normalize old source values + add level to MatchEntry schema."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / 'reports' / 'extracted'

# Map legacy source strings → new codes
SRC_MAP = {
    'pdf:天津学校情况(4).pdf': 'JM-PDF',
    'xlsx:2026年永辉选房全天津项目优缺点': 'YH-XLSX',
}

# Fix schools.json
schools = json.loads((EXT / 'schools.json').read_text(encoding='utf-8'))
fixed = 0
for s in schools['items']:
    if s.get('source') in SRC_MAP:
        s['source'] = SRC_MAP[s['source']]
        fixed += 1
(EXT / 'schools.json').write_text(json.dumps(schools, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'schools.json: migrated source on {fixed} items')

# Fix compounds.json (was already 'YH-XLSX' but old top-level source field uses long string)
comps = json.loads((EXT / 'compounds.json').read_text(encoding='utf-8'))
fixed = 0
for c in comps['items']:
    if c.get('source') in SRC_MAP:
        c['source'] = SRC_MAP[c['source']]
        fixed += 1
(EXT / 'compounds.json').write_text(json.dumps(comps, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'compounds.json: migrated source on {fixed} items')
