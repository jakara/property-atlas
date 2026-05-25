#!/usr/bin/env python3
"""Build policies.json + admission_rates.json + enhance primary tier from pptx + zones md."""
import json, hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / 'reports' / 'extracted'

# ============= Admission rates (slide 64 / slide 120 of pptx) =============
admission = [
    # (district, 普高录取率%, 职高录取率%)
    ('和平区',      85, 12),
    ('河西区',      80, 17),
    ('南开区',      77, 20),
    ('河东区',      70, 20),
    ('河北区',      67, 27),
    ('红桥区',      65, 30),
    ('滨海新区',    63, 32),
    ('蓟州区',      62, 34),
    ('武清区',      60, 35),
    ('宝坻区',      58, 37),
    ('静海区',      53, 39),
    ('宁河区',      51, 44),
    ('津南区',      49, 48),
    ('北辰区',      47, 50),
    ('西青区',      43, 54),
    ('东丽区',      41, 56),
    ('空港',        85, None),
    ('海教园',      83, None),
    ('生态城',      80, None),
]
adm_items = [
    {'district': d, 'gaokao_admit_pct': g, 'vocational_admit_pct': v,
     'year': 2023, 'source':'pptx slide 64+120'}
    for d, g, v in admission
]
(EXT / 'admission_rates.json').write_text(json.dumps(
    {'version':'2026.05.25','count':len(adm_items),'note':'各区2023年中考普高/职高录取率',
     'items':adm_items}, ensure_ascii=False, indent=2), encoding='utf-8')

# ============= Policies (structured) =============
def pid(slug): return 'pol_' + slug

policies = [
    # ----- 落户 -----
    {'id':pid('hhyc_xueli'), 'category':'落户', 'subcategory':'海河英才',
     'name':'海河英才（学历型）',
     'eligibility':[
         '全日制本科 ≤ 40 周岁（含）',
         '硕士研究生 ≤ 45 周岁',
         '博士研究生 不限年龄',
     ],
     'docs':['学历证','学历认证报告','身份证正反面','境外学历需教育部留学服务中心学历学位证书','在津有工作者需加盖单位公章营业执照副本'],
     'source':'pptx slides 12-17',
     'note':'最快当月可拿到准迁; 公务员/事业编不可叠加外地社保'},

    {'id':pid('hhyc_jineng'), 'category':'落户', 'subcategory':'海河英才',
     'name':'海河英才（技能型）',
     'eligibility':[
         '高职毕业 + 用人单位就业, 三选一: <30岁/高级职业资格满1年<35岁/技师<40岁/高级技师<50岁',
         '中职毕业 + 在津工作满1年: 高级资格<35/技师<40/高级技师<50',
     ],
     'docs':['全日制学历证书','职业资格证书','身份证','单位营业执照副本','中专/职高毕业生需毕业生登记表'],
     'source':'pptx slides 18-22'},

    {'id':pid('hhyc_zige'), 'category':'落户', 'subcategory':'海河英才',
     'name':'海河英才（资格型）',
     'eligibility':[
         '副高及以上职称',
         '精算师/CFA/FRM/注会/税务师/注册建筑师/注册勘察设计/资产评估/律师/公证员',
         '中国民航局飞机驾驶执照',
     ],
     'source':'pptx slide 23',
     'note':'身体健康+无犯罪记录+法定劳动年龄内'},

    {'id':pid('hhyc_jixu'), 'category':'落户', 'subcategory':'海河英才',
     'name':'海河英才（急需型）',
     'eligibility':[
         '人工智能/生物医药/新一代信息技术/航空航天/高端装备制造/新能源新材料/节能环保/精细化工/高新技术服务/现代金融/国际航运 等战略性新兴产业领军企业急需人才',
         '由企业认定 → 区人才办核准 → 出具急需型人才认定书',
     ],
     'source':'pptx slide 24'},

    {'id':pid('jifen'), 'category':'落户', 'subcategory':'积分落户',
     'name':'积分落户',
     'eligibility':[
         '高中及以下学历可走此路径',
         '基础分:年龄+学历+技能证+买新房',
         '时间累计分:房子+社保+公积金+居住证(每次签注6分)+配偶社保',
         '社保要求:累计满3年或连续满1年; 必须单位缴(灵活就业不可)',
     ],
     'timing':{'upper_half':'1-4月申报, 6月下准迁','lower_half':'7-10月申报, 12月下准迁'},
     'caveats':[
         '异地同时有社保会被拒',
         '光交社保未申报个税会被拒',
         '社保单位和个税单位需一致',
         '想子女随迁必须买房',
         '商住公寓不可积分(必须70年产权)',
         '婚后买房只能落户不能积分; 婚前买房可积分',
     ],
     'source':'pptx slides 25-29'},

    {'id':pid('zinv_suiqian'), 'category':'落户', 'subcategory':'子女随迁',
     'name':'子女随迁',
     'eligibility':[
         '父母一方天津户口(集体户不可)',
         '子女<18周岁',
         '父母在天津有自有住房',
     ],
     'process':'房本+父母双方户口本+身份证+孩子出生证+孩子户口本 → 房屋所在地派出所领准迁 → 原户籍地办迁出 → 24小时后天津派出所落户',
     'source':'pptx slide 30'},

    {'id':pid('fumu_touku'), 'category':'落户', 'subcategory':'父母投靠',
     'name':'父母投靠子女落户',
     'eligibility':[
         '男≥60周岁, 女≥55周岁, 或已退休来津满6个月',
         '至少一位成年子女为天津户口',
         '在天津有本人/父母/子女住房',
     ],
     'source':'pptx slide 30'},

    # ----- 入学/转学 政策 -----
    {'id':pid('zhuanxue_hedong_xs'), 'category':'转学', 'subcategory':'河东',
     'name':'河东区小学转学+入学(2025起)',
     'rules':[
         '小学仅暑假转学; 登记时间为每年放暑假前一周',
         '新二至新五年级可申请; 新六年级不接收',
         '统筹安置,不保证对口学校',
         '二手房须持房满3年方可申请(以契税票时间为准, 至8月31日)',
         '一手房(新建商品房)不受影响',
         '房产产权人须为学生父母/祖父母/外祖父母, 私产房须持全部产权',
     ],
     'effective_date':'2024-11-15',
     'specific_schools_3yr':['河东区实验小学','河东区第二实验小学','河东区缘诚小学','河东区前程小学','河东区九年一贯制学校小学部'],
     'source':'pptx slides 33-34'},

    {'id':pid('zhuanxue_nankai_xs'), 'category':'转学', 'subcategory':'南开',
     'name':'南开区小学转学+初中入学(2025起)',
     'rules':[
         '小学仅秋季新二至新五年级可转; 新六不接收',
         '二手房持有满3年',
         '一手房不受影响',
         '六年级毕业派位时须持有与入学/转入时一致的户籍+房产, 否则统筹',
         '产权人须为父母/祖父母/外祖父母 + 持全部产权',
     ],
     'source':'pptx slides 35-37'},

    {'id':pid('zhuanxue_nankai_huijin'), 'category':'转学', 'subcategory':'南开',
     'name':'南开区初中外省回户籍地升学及转学',
     'effective_date':'2025-01-25',
     'rules':[
         '适用2025秋季起回户籍地升学及转学',
         '二手房须满3年(至入学当年8月31日)',
         '一手房不受影响',
         '登记时间调整为每年5月',
         '统筹安置在全区有空余学位的学校',
     ],
     'source':'pptx slide 37'},

    {'id':pid('zhuanxue_heping_huijin'), 'category':'转学', 'subcategory':'和平',
     'name':'和平区初中外省回户籍地升学及转学',
     'rules':[
         '二手房须满3年',
         '一手房不受影响',
         '登记5月',
         '住宿需求可选第二耀华中学提前录取',
     ],
     'source':'pptx slide 38'},

    {'id':pid('heping_xuewei_kongzhi'), 'category':'入学', 'subcategory':'和平',
     'name':'和平区学位控制(六年一学位)',
     'schools':['天津市实验小学','昆明路小学','岳阳道小学','中心小学','耀华小学','鞍山道小学','万全小学','第二南开学校小学部','万全第二小学'],
     'rules':[
         '学区内每户地址6年内只享一次同校对口入学机会',
         '同一房屋6年内多个适龄儿童入学时, 房主+户主须是相同的父母(或祖父母/外祖父母)',
         '不符合则统筹到其他公办小学',
     ],
     'source':'pptx slide 39'},

    {'id':pid('hexi_xs'), 'category':'转学', 'subcategory':'河西',
     'name':'河西区小学转学+初中入学',
     'rules':[
         '小学仅暑假转学; 新二至五可转; 新六不接收',
         '二手房须满3年',
         '一手房不受影响',
         '六年级毕业派位须保持入学时一致户籍房产, 否则统筹',
         '产权人须为父母/祖父母/外祖父母 + 持全部产权',
     ],
     'source':'pptx slides 40-42'},

    {'id':pid('shengtaicheng'), 'category':'转学', 'subcategory':'生态城',
     'name':'生态城转学+入学',
     'rules':[
         '小学仅秋季转学; 新二至五; 新六不接收',
         '二手房须满3年',
         '一手房不受影响',
         '初中转学:二手房须满1年',
         '所有小学执行 六年一学位',
         '未购房则协调到新区其他区域',
     ],
     'effective_date':'2024-07-31',
     'source':'pptx slides 43-44'},

    # ----- 高考/中考 -----
    {'id':pid('gaokao_req'), 'category':'高考', 'subcategory':'报名条件',
     'name':'天津高考要求',
     'rules':[
         '3年学籍 + 户籍要求',
         '最晚落户时间:高一开学前(初三毕业当年9月1号前)',
         '最晚转学时间:高一下学期(也算3年学籍)',
         '安置考要求:全国电子学籍+高中在读+在津中考但未达普高线者不接收',
     ],
     'source':'pptx slide 45'},

    {'id':pid('kongjiang_zhongkao'), 'category':'中考', 'subcategory':'空降中考',
     'name':'空降中考流程',
     'description':'户籍天津、学籍外地, 中考报名在天津',
     'steps':[
         '前一年12月报名中考',
         '当年4月体检',
         '6月中考最后一天补考会考',
     ],
     'caveats':[
         '体育满分22分(无平时分18分)',
         '建议初三下学期来津进行衔接复习',
         '海教园不可空降中考',
         '空港可空降中考(需空港户口+房子, 中考报名前取得)',
     ],
     'source':'pptx slides 46+58'},

    {'id':pid('zhongkao_suoqu'), 'category':'中考', 'subcategory':'锁区',
     'name':'天津中考锁区政策',
     'rules':[
         '市六区+海教园=统考',
         '其他各区只能考本区高中',
         '武清区: 乡镇/城区分开考',
         '海教园可考市六区高中(但需海教园学籍)',
         '滨海新区部分学校面向全区招生',
         '市九所面向各区投放少量名额(掐尖)',
     ],
     'source':'pptx slide 50+116'},

    {'id':pid('zhibiao_sheng'), 'category':'中考', 'subcategory':'指标生',
     'name':'中考指标生政策',
     'description':'按比例将本区优质高中招生指标分配到本区每所初中',
     'rules':[
         '不能跨区',
         '获指标资格可降20分录取',
         '当前比例 50%',
         '放弃指标不影响报考其他高中',
     ],
     'source':'pptx slide 50'},

    {'id':pid('xiaoshengchu'), 'category':'小升初', 'subcategory':'划片',
     'name':'天津小升初3种方式',
     'rules':[
         '单校划片(环城+郊区)',
         '多校划片(市六区) 摇号入学',
         '对口直升(九年一贯制)',
         '前提:有天津小学学籍',
     ],
     'source':'pptx slide 52'},

    {'id':pid('gongmin_tongyao'), 'category':'小升初', 'subcategory':'公民同摇',
     'name':'公民同摇政策(2022起)',
     'rules':[
         '2022前: 私立学校可笔试+面试招生',
         '2022起: 私立必须与公办一起摇号',
         '除小外学校外其他初中都不看孩子成绩, 全凭运气',
     ],
     'source':'pptx slide 117'},

    {'id':pid('zhiyuan_tianbao'), 'category':'小升初', 'subcategory':'志愿填报',
     'name':'各区小升初志愿填报规则',
     'rules_by_district':{
         '和平':'民办不限, 片内公办必须填满',
         '南开':'民办不限, 最多填6所(片内公办不少于4所)',
         '河西':'民办不限, 片内公办必须填满',
         '红桥':'片内仅有的公办校',
         '河北':'民办不限, 最多4所',
         '河东':'片内仅有的公办校',
     },
     'source':'pptx slide 96'},

    {'id':pid('liunian_xuewei'), 'category':'入学', 'subcategory':'六年一学位',
     'name':'六年一学位',
     'description':'一套房6年内只允许一个家庭的孩子上学(可包含祖父母/外祖父母)',
     'applicable':[
         '和平区: 鞍山道小学/耀华小学/昆明路小学/万全小学/天津实验小学/第二南开学校小学部/万全第二小学/岳阳道小学/和平中心小学/20中附小',
         '海教园南开学校:9年一学位',
         '团泊西北师大附属:6年一学位',
         '北辰区所有学校',
         '生态城所有小学',
     ],
     'source':'pptx slide 54'},

    {'id':pid('heping_3yr'), 'category':'入学', 'subcategory':'和平',
     'name':'和平区提前三年购房',
     'rules':[
         '入学+转学都要求提前三年买房',
         '不满三年的, 其他区无房产可统筹入学',
         '新房不受限制',
         '只要求房产时间, 落户时间不要求',
     ],
     'source':'pptx slides 55+118'},

    {'id':pid('wuzheng'), 'category':'入学', 'subcategory':'外来务工子女',
     'name':'五证上学',
     'docs':[
         '天津居住证',
         '居住证持有人及配偶+随迁子女户口本',
         '合法居住证明(租赁合同+租赁备案 或 自家房本)',
         '务工就业证明(劳动合同 或 营业执照)',
         '社保证明(河西/南开/和平要求不低于本区半年社保)',
         '孩子预防接种证',
     ],
     'note':'不买房不落户也可上学; 教育局统筹分配; 中考仍要求天津户口',
     'source':'pptx slide 56'},

    {'id':pid('xs_zhuanxue_special'), 'category':'转学', 'subcategory':'通用',
     'name':'天津初中转学时间提醒',
     'rules':[
         '初一上学期 不接收转学',
         '初三下学期 不接收转学',
         '初一下转入:有平时体育18分, 中考体育满分40',
         '初二/初三上转入:无平时分, 体测40分一次取得',
         '空降中考:体育满分22',
     ],
     'source':'pptx slide 51+11'},
]

(EXT / 'policies.json').write_text(json.dumps(
    {'version':'2026.05.25','count':len(policies),'items':policies},
    ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Wrote {len(policies)} policies')

# ============= 重点小学梯队 (slide 101-103) — enhance primaries =============
primary_tiers = {
    '和平': {
        1: ['逸阳梅江湾国际学校','岳阳道小学','实验小学','昆明路小学','中心小学','模范小学'],
        2: ['万全小学','鞍山道小学','二南开小学','新华南路小学'],
        3: ['耀华小学','哈密道小学','新星小学','西康路小学','二十中附小','四平东道小学'],
    },
    '河西': {
        1: ['上海道小学','台湾路小学','闽侯路小学','河西中心小学','师大二附小'],
        2: ['湘江道小学','平山道小学','水晶小学','财大附小'],
        3: ['东楼小学','恩德里小学','马场道小学','滨湖小学','南开翔宇','全运村小学','四号路小学',
            '南湖小学','友谊路小学','卫东路小学','名都小学','纯真小学','师大附小','梧桐小学',
            '中山小学','同望小学','纯皓小学','梅苑小学','复兴小学','德贤小学','天津小学',
            '土城小学','财大二附属','科技大附属柳林小学','职业技术师范大学附属小学',
            '科技大学附属小学','新会道小学'],
    },
    '南开': {
        1: ['五马路小学','中营小学','南开中心小学','南开小学','天大附小','南大附小','南开实验小学'],
        2: ['永基小学','西营门外小学','南开艺术小学','咸阳路小学','科技实验小学','汾水道小学',
            '前园小学','跃升里小学','中心小学','师大南开附小','长治里小学','宜宾里小学',
            '凤湖里小学','华夏小学','义兴里小学','川府里小学','华宁道小学','新星小学',
            '水上小学','勤敏小学','阳光小学','华苑小学'],
    },
}

primaries = json.loads((EXT / 'schools_primary.json').read_text(encoding='utf-8'))
for s in primaries['items']:
    d_short = s['district'].replace('区','')
    s['tier_rank'] = None
    s['tier_label'] = None
    tiers = primary_tiers.get(d_short, {})
    # match by name containing one of the listed names
    for rank, names in tiers.items():
        for n in names:
            if n in s['name'] or s['name'] in n:
                s['tier_rank'] = rank
                s['tier_label'] = {1:'重点',2:'良好',3:'普通'}[rank]
                break
        if s['tier_rank']: break

(EXT / 'schools_primary.json').write_text(json.dumps(primaries, ensure_ascii=False, indent=2), encoding='utf-8')

tier_count = sum(1 for s in primaries['items'] if s['tier_rank'])
print(f'Tagged {tier_count}/{len(primaries["items"])} primary schools with tier')
