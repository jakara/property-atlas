/* Tianjin Property Atlas — sample data
   Realistic Tianjin district / compound / school names per design doc. */

const TPA_COMPOUNDS = [
  // 和平 (top tier)
  { id: 'c1', name: '万全道小区', shortName: '万全道', district: '和平区', zone: '和平第一学区', buildYear: 1998, x: 180, y: 130, status: 'visited', rating: 4, visitDate: '5月12日', priceWan: 580, areaM2: 88, floor: '中层', primarySchool: '万全道小学', meta: [{icon:'home',text:'88㎡'},{icon:'layers',text:'中楼层'}], tags: [{p:'+',label:'南北通透'},{p:'+',label:'新装'},{p:'-',label:'楼上吵'}], thumbs: ['image','image','image','image'] },
  { id: 'c2', name: '昆明路花园', shortName: '昆明路', district: '和平区', zone: '和平第一学区', buildYear: 2005, x: 240, y: 170, status: 'visited', rating: 5, visitDate: '5月8日', priceWan: 720, areaM2: 104, floor: '高层', primarySchool: '万全道小学', meta: [{icon:'home',text:'104㎡'},{icon:'sun',text:'全南'}], tags: [{p:'+',label:'物业积极'},{p:'+',label:'安静'}], thumbs: ['image','image'] },
  { id: 'c3', name: '岳阳道48号', shortName: '岳阳道', district: '和平区', zone: '和平第一学区', buildYear: 1995, x: 150, y: 180, status: 'want', priceWan: null, primarySchool: '岳阳道小学', meta: [{icon:'calendar',text:'本周看'}] },

  // 南开 (good)
  { id: 'c4', name: '川府新村', shortName: '川府', district: '南开区', zone: '南开二片', buildYear: 2010, x: 420, y: 220, status: 'visited', rating: 3, visitDate: '5月5日', priceWan: 410, areaM2: 92, floor: '低层', primarySchool: '南开实验小学', meta: [{icon:'home',text:'92㎡'}], tags: [{p:'-',label:'临街主干道'},{p:'+',label:'楼层适中'}], thumbs: ['image','image','image'] },
  { id: 'c5', name: '雅安里', shortName: '雅安里', district: '南开区', zone: '南开二片', buildYear: 2003, x: 480, y: 250, status: 'want', primarySchool: '南开实验小学', meta: [{icon:'calendar',text:'5月20日'}] },
  { id: 'c6', name: '风湖里', shortName: '风湖', district: '南开区', zone: '南开二片', buildYear: 2001, x: 440, y: 290, status: 'excluded', priceWan: 380, primarySchool: '南开实验小学', meta: [{icon:'x-circle',text:'楼层太低'}] },

  // 河西 (regular)
  { id: 'c7', name: '友谊路35号', shortName: '友谊路', district: '河西区', zone: '河西二片', buildYear: 2008, x: 660, y: 140, status: 'unvisited', primarySchool: '友谊路小学' },
  { id: 'c8', name: '广东路60号', shortName: '广东路', district: '河西区', zone: '河西二片', buildYear: 2015, x: 700, y: 200, status: 'unvisited', primarySchool: '广东路小学' },

  // 河北 (weak)
  { id: 'c9', name: '王串场二号路', shortName: '王串场', district: '河北区', zone: '河北二片', buildYear: 1996, x: 240, y: 430, status: 'want', primarySchool: '王串场一小' },
  { id: 'c10', name: '宇翠里', shortName: '宇翠里', district: '河北区', zone: '河北二片', buildYear: 2002, x: 280, y: 470, status: 'unvisited', primarySchool: '王串场一小' },
];

const TPA_SCHOOLS = [
  { id: 's1', name: '万全道小学', type: '小学', district: '和平区', zone: '和平第一学区', tier: '顶尖', rank: '市第3', top10: '32%', compounds: 14, foundedYear: 1952, motto: '以人为本，全面发展' },
  { id: 's2', name: '昆鹏中学', type: '初中', district: '和平区', zone: '和平第一学区', tier: '顶尖', rank: '市第5', top10: '28%', compounds: 22, foundedYear: 1948 },
  { id: 's3', name: '南开实验小学', type: '小学', district: '南开区', zone: '南开二片', tier: '优质', rank: '市第18', top10: '14%', compounds: 11, foundedYear: 1985 },
  { id: 's4', name: '天津四中', type: '初中', district: '南开区', zone: '南开二片', tier: '优质', rank: '市第22', top10: '11%', compounds: 18, foundedYear: 1955 },
  { id: 's5', name: '环湖中学', type: '初中', district: '河西区', zone: '河西二片', tier: '普通', rank: '市第65', top10: '4%', compounds: 9, foundedYear: 1972 },
];

const TPA_ZONES_USER = [
  { id: 'z1', name: '通勤可达圈', kind: '通勤', area: '滨海高速 30 分钟', strokeColor: '#B5703A', visible: true },
  { id: 'z2', name: '排除区', kind: '排除', area: '北辰区以北', strokeColor: '#A85040', visible: true },
  { id: 'z3', name: '夫妻通勤交点', kind: '自定义', area: '南开 - 滨海', strokeColor: '#5B7C9C', visible: false },
];

/* Visit history sample for compound detail */
const TPA_VISITS_C2 = [
  {
    id: 'v1', date: '5月8日 周四', floor: '高层 14/18', area: 104, priceWan: 720,
    overall: 5, light: 5, noise: 4, layout: 4, propertyMgmt: 5,
    tags: [{p:'+',label:'物业积极'},{p:'+',label:'安静'},{p:'+',label:'全南'},{p:'+',label:'电梯整洁'}],
    note: '阳台朝南，窗外是树。中介说业主诚心卖，可谈到 700 出头。社区里有老人晨练但不吵。',
    thumbs: 6,
  },
  {
    id: 'v2', date: '4月22日 周二', floor: '中层 8/18', area: 88, priceWan: 680,
    overall: 4, light: 4, noise: 4, layout: 3, propertyMgmt: 4,
    tags: [{p:'+',label:'采光好'},{p:'-',label:'户型一般'}],
    note: '第一次来。这套面积小一些，户型不太方正。',
    thumbs: 3,
  },
];

Object.assign(window, { TPA_COMPOUNDS, TPA_SCHOOLS, TPA_ZONES_USER, TPA_VISITS_C2 });
