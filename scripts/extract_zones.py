#!/usr/bin/env python3
"""Parse 学片划分 md → zones.json + schools_primary.json."""
import re, json, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MD = ROOT / 'reports' / '天津市内六区小学与初中学片划分及实力排名深度研究报告（2024–2026版）.md'
OUT_ZONES = ROOT / 'reports' / 'extracted' / 'zones.json'
OUT_PRIM = ROOT / 'reports' / 'extracted' / 'schools_primary.json'

def sid(name, prefix='sch_'):
    return prefix + hashlib.md5(name.encode()).hexdigest()[:10]

def zid(district, zone):
    return 'zon_' + hashlib.md5(f'{district}|{zone}'.encode()).hexdigest()[:10]

text = MD.read_text(encoding='utf-8')

# District section headers: "## 二、和平区（教育资源天花板）"
# Zone subheaders: "### 和平一片"
DISTRICT_RE = re.compile(r'^## [一二三四五六七八九十]+、(\S+区)（', re.M)
ZONE_RE = re.compile(r'^### (\S.+?)$', re.M)

# Split text into district blocks
sections = []
matches = list(DISTRICT_RE.finditer(text))
for i, m in enumerate(matches):
    district = m.group(1)
    start = m.end()
    end = matches[i+1].start() if i+1 < len(matches) else len(text)
    sections.append((district, text[start:end]))

zones = []
primaries = []
seen_pschools = {}

for district, block in sections:
    # Find subzones via ### lines, skip region-level conclusions
    sub_matches = list(ZONE_RE.finditer(block))
    for j, sm in enumerate(sub_matches):
        zone_name = sm.group(1).strip()
        # Filter out non-zone subheaders like "和平区民办初中" / "和平区学片实力梯队"
        if '民办初中' in zone_name or '实力梯队' in zone_name or '学区片实力梯队' in zone_name:
            continue
        if not (zone_name.startswith(district[:2]) or zone_name.startswith('第') or zone_name.startswith('河西') or zone_name.startswith('河东') or zone_name.startswith('和平') or zone_name.startswith('南开') or zone_name.startswith('河北') or zone_name.startswith('红桥')):
            continue

        start = sm.end()
        end = sub_matches[j+1].start() if j+1 < len(sub_matches) else len(block)
        zbody = block[start:end]

        # Extract 公办初中 / 中学 line
        m_mid = re.search(r'\*\*(?:公办初中|中学)[（(]?(\d+|\d+-\d+)?所?[）)]?\*\*[：:](.+?)(?:\n|$)', zbody)
        mid_schools_raw = m_mid.group(2).strip() if m_mid else ''
        mid_schools = [s.strip() for s in re.split(r'[、，,]', mid_schools_raw) if s.strip()]

        # Extract 对应小学 / 片内小学 / 小学
        m_prim = re.search(r'\*\*(?:对应小学|片内小学|小学)\*\*[：:](.+?)(?:\n|$)', zbody)
        prim_schools_raw = m_prim.group(1).strip() if m_prim else ''
        prim_schools = [s.strip() for s in re.split(r'[、，,；;]', prim_schools_raw) if s.strip()]
        # Strip "民办：" prefixes and parenthetical notes
        prim_clean = []
        for p in prim_schools:
            p = re.sub(r'^民办[：:]', '', p)
            p = re.sub(r'\s*[（(].*?[）)]$', '', p).strip()
            if p: prim_clean.append(p)

        # 亮点 line
        m_hl = re.search(r'\*\*(?:片区亮点|亮点)\*\*[：:](.+?)(?:\n|$)', zbody)
        highlight = m_hl.group(1).strip() if m_hl else ''

        z_id = zid(district, zone_name)
        zones.append({
            'id': z_id,
            'district': district,
            'zone_name': zone_name,
            'middle_school_pool': mid_schools,
            'primary_schools': prim_clean,
            'highlight': highlight,
            'source_doc': '天津市内六区小学与初中学片划分md',
        })

        for ps in prim_clean:
            # dedupe — same name across districts is possible but rare
            key = (district, ps)
            if key in seen_pschools: continue
            seen_pschools[key] = True
            primaries.append({
                'id': sid(f'{district}-{ps}'),
                'name': ps,
                'district': district,
                'zone_id': z_id,
                'zone_label': zone_name,
                'level': 'primary',
                'source_doc': '天津市内六区小学与初中学片划分md',
            })

OUT_ZONES.write_text(json.dumps({'version':'2026.05.25','count':len(zones),'items':zones},
                                ensure_ascii=False, indent=2), encoding='utf-8')
OUT_PRIM.write_text(json.dumps({'version':'2026.05.25','count':len(primaries),'items':primaries},
                               ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Wrote {len(zones)} zones, {len(primaries)} primary schools')
for z in zones:
    print(f"  {z['district']} / {z['zone_name']}: {len(z['middle_school_pool'])} 初中, {len(z['primary_schools'])} 小学")
