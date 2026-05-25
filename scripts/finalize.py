#!/usr/bin/env python3
"""Finalize public open-source data:
- Replace old sensitive-data schools.json/zones.json with PDF-sourced public versions
- Strip pros/cons from compounds.json (subjective vendor opinions)
- Strip sensitive tier from any school records
- Generate index README
"""
import json, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / 'reports' / 'extracted'
SENS = EXT / 'private'
SENS.mkdir(exist_ok=True)

# Move sensitive files (md-sourced rank/tier/comment) to private/
for fn in ['schools.json','schools_middle.json','schools_primary.json','zones.json']:
    src = EXT / fn
    if src.exists():
        shutil.move(str(src), str(SENS / fn))
        print(f'Moved {fn} → private/')

# Rename public ones
(EXT / 'schools_public.json').rename(EXT / 'schools.json')
(EXT / 'zones_public.json').rename(EXT / 'zones.json')
print('Renamed schools_public.json → schools.json')
print('Renamed zones_public.json → zones.json')

# Strip subjective pros/cons from compounds.json
comps = json.loads((EXT / 'compounds.json').read_text(encoding='utf-8'))
for c in comps['items']:
    for k in ('pros','cons'):
        if k in c:
            del c[k]
(EXT / 'compounds.json').write_text(
    json.dumps(comps, ensure_ascii=False, indent=2), encoding='utf-8')
print('Stripped pros/cons from compounds.json')

# Add .gitignore in reports/extracted to exclude raw/ and private/
gi = EXT / '.gitignore'
gi.write_text("raw/\nprivate/\n", encoding='utf-8')
print('Wrote .gitignore (raw/ + private/)')

# Print final
print('\n--- Final public dataset ---')
for fn in sorted(EXT.glob('*.json')):
    d = json.loads(fn.read_text(encoding='utf-8'))
    n = d.get('count', len(d.get('items', [])))
    print(f'  {fn.name}: {n} entries')
