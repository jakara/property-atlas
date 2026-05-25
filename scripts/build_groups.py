#!/usr/bin/env python3
"""Build groups.json from raw pdf_data_groups.json + reverse index school→groups."""
import json, hashlib, re
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / 'reports' / 'extracted'

raw = json.loads((EXT / 'raw' / 'pdf_data_groups.json').read_text(encoding='utf-8'))
schools = json.loads((EXT / 'schools.json').read_text(encoding='utf-8'))['items']

def gid(district, name):
    return 'grp_' + hashlib.md5(f'{district}|{name}'.encode()).hexdigest()[:10]

ALIAS = {
    '南大附中': '南开大学附属中学',
    '天大附中': '天津大学附属中学',
    '师大南开附中': '师大南开附属中学',
    '南开翔宇中学': '南开翔宇学校（南开校区）',
    '北师大附中': '北京师范大学天津附属中学',
    '师大二附小': '天津师范大学第二附属小学',
    '育婴里第一小学': '育婴里小学',
    '婴里小学': '育婴里小学',
    '河东实验': '河东实验小学',
    '河东一中心小学': '河东第一中心小学',
    '翟云小学': '冠云小学',
    '翔东小学': '东兴小学',
    '二十中附属小学': '第二十中学附属小学',
    '翔宇中学': '翔宇学校',
    '南开科技实验中学': '南开区科技实验中学',
    '日新小学': '日新国际学校',
    '美达菲小学': '美达菲学校',
    '南大附中南方小学': '南大附小',
    '弘扬学校小学部': '弘扬学校',
    '苑中小学': '苑中路小学',
    '南大附属小学部': '南大附小',
    '河西翔宇(初中)': '河西区南开翔宇学校（梅江校区）',
    '翔宇力仁': '翔宇力仁学校',
    '科技实验': '南开区科技实验中学',
    '四十三': '第四十三中学',
    '美达菲': '美达菲学校',
    '北京求实学校中部': '求实学校',
    '梧桐中学': '梧桐中学',
    '北师大附属学校中部': '北京师范大学天津附属中学',
    '汇德小学部': '汇德学校',
    '新会道学校': '新会道小学',
    '第二新华中学': '第二新华中学',
    '新华自动中学新校': '新华中学',
    '海河村小学': '海河中学',
    '厦学校小学': '厦学校',
    '抑摇小学': '逸阳梅江湾学校',
    '新华中学小学部': '新华中学',
    '中心小学梅苑小学': '梅苑小学',
    '梧桐中学': '梧桐中学',
    '子玉鸟实验小学': '红桥实验小学',
    '红桥泰达学校': '红桥泰达实验中学',
    '红桥区民族公立小学': '民族中学附属小学',
    '红桥五门校': '河北工业大学附属红桥小学',
    '红桥清源道小学': '清源道小学',
    '海光寺及附中区进生联校(钢门)': '钢门学校',
    '实验': '天津市实验中学（初中部）',
    '实验小学': '天津市实验小学',
    '第九中学': '第九中学',
    '中营小学': '中营小学',
    '中营瑞丽小学': '中营瑞丽小学',
    '六十三中': '第六十三中学',
    '二十五中': '第二十五中学',
    '津英中学': '津英中学',
    '艺术小学': '南开艺术小学',
    '南开小学': '南开小学',
    '风湖里小学': '风湖里小学',
    '汾水道小学': '汾水道小学',
    '咸阳路小学': '咸阳路小学',
    '宜宾里小学': '宜宾里小学',
    '川府里小学': '川府里小学',
    '小南大附小': '南大附小',
    '阳光小学': '阳光小学',
    '华苑小学': '华苑小学',
    '博瀚小学': '博瀚小学(民办)',
    '南开实验学校小学部': '南开实验学校小学部',
    '科技实验小学': '科技实验小学',
    '永基小学': '永基小学',
    '西营门外小学': '西营门外小学',
    '义兴里小学': '义兴里小学',
    '长治里小学': '长治里小学',
    '前园小学': '前园小学',
    '跃升里小学': '跃升里小学',
    '师大附属天大附小': '天大附小',
    '崇化中学': '崇化中学(北马路)',
    '凤凰小学': '凤凰小学',
    '行知小学': '行知小学',
    '大桥道小学': '大桥道小学',
    '七中教育集团太阳城学校': '七中教育集团太阳城学校',
    '七中教育集团东局子学校': '七中教育集团-东局子学校',
    '中心小学东湖校区': '中心小学(东湖校区)',
    '梅苑小学': '梅苑小学',
    '复兴小学': '复兴小学',
    '台湾路小学': '台湾路小学',
    '上海道小学': '上海道小学',
    '德贤小学': '德贤小学',
    '水晶小学': '水晶小学',
    '中心小学': '河西区中心小学梅江校区',
    '翔宇弘德': '翔宇弘德学校',
    '育婴里第二小学': '育婴里第二小学',
    '育婴里第三小学': '育婴里第三小学',
    '育婴里第四小学': '育婴里第四小学',
    '第二实验新世纪小学': '第二实验小学新世纪小学',
    '河北区第二实验小学': '河北区第二实验小学',
    '红桥实验小学': '红桥实验小学',
    '红桥区民族中学附属小学': '民族中学附属小学',
    '天津师范学校附属小学': '天津师范学校附属小学',
    '天津师范学校和苑附属小学': '天津师范学校和苑附属小学',
    '文昌宫民族小学': '文昌宫民族小学',
    '民族中学': '民族中学',
    '五十中学': '五十中学',
    '南开中学': '南开中学',
    '南开翔宇学校': '南开翔宇学校（南开校区）',
}

def sid_lookup(name, district):
    base = re.sub(r'[（(].*?[）)]', '', name).strip()
    base = re.sub(r'\(停招\)$', '', base).strip()
    # Try alias first
    aliased = ALIAS.get(base, base)
    for s in schools:
        if s['district'] != district: continue
        sn = re.sub(r'[（(].*?[）)]', '', s['name']).strip()
        if aliased == sn or aliased == s['name']:
            return s['id'], s['name']
    # Then substring
    for s in schools:
        if s['district'] != district: continue
        sn = re.sub(r'[（(].*?[）)]', '', s['name']).strip()
        if base in sn or sn in base:
            return s['id'], s['name']
    return None, None

groups = []
school_to_groups = defaultdict(list)

for district, ddata in raw['districts'].items():
    for g in ddata['groups']:
        g_id = gid(district, g['name'])
        leads = g['lead'] if isinstance(g['lead'], list) else [g['lead']]
        lead_records = []
        for L in leads:
            sid, sname = sid_lookup(L, district)
            lead_records.append({'name': L, 'school_id': sid, 'matched_school': sname})
            if sid:
                school_to_groups[sid].append({'group_id': g_id, 'group_name': g['name'], 'role': 'lead'})

        member_records = []
        for m in g['members']:
            stopped = '(停招)' in m
            m_clean = re.sub(r'\(停招\)$', '', m).strip()
            sid, sname = sid_lookup(m_clean, district)
            member_records.append({'name': m, 'school_id': sid, 'matched_school': sname, 'stopped': stopped})
            if sid:
                school_to_groups[sid].append({'group_id': g_id, 'group_name': g['name'], 'role': 'member', 'stopped': stopped})

        groups.append({
            'id': g_id,
            'district': district,
            'name': g['name'],
            'leads': lead_records,
            'members': member_records,
            'note': g.get('note'),
        })

(EXT / 'groups.json').write_text(json.dumps({
    'version': '2026.05.25',
    'source': 'PDF 津门学路通 P30 集团化办学',
    'count': len(groups),
    'items': groups,
    'school_to_groups': dict(school_to_groups),
    'warnings': raw['warnings'],
}, ensure_ascii=False, indent=2), encoding='utf-8')

# Stats
print(f'Wrote {len(groups)} groups')
matched_leads = sum(1 for g in groups for L in g['leads'] if L['school_id'])
total_leads = sum(len(g['leads']) for g in groups)
matched_mem = sum(1 for g in groups for m in g['members'] if m['school_id'])
total_mem = sum(len(g['members']) for g in groups)
print(f'  Leads matched to schools.json: {matched_leads}/{total_leads}')
print(f'  Members matched: {matched_mem}/{total_mem}')

from collections import Counter
by_d = Counter(g['district'] for g in groups)
for d, n in sorted(by_d.items()):
    print(f'  {d}: {n} groups')

print('\nUnmatched leads:')
for g in groups:
    for L in g['leads']:
        if not L['school_id']:
            print(f"  [{g['district']}] {g['name']}: lead='{L['name']}'")
print('\nUnmatched members (sample 20):')
unm = [(g['district'], g['name'], m['name']) for g in groups for m in g['members'] if not m['school_id']]
for d, gn, mn in unm[:20]:
    print(f"  [{d}] {gn}: member='{mn}'")
print(f'  ...({len(unm)} total)')
