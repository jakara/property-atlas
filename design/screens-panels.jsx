/* Tianjin Property Atlas — drawer-filling panels & wizard
   CompoundDetail, SchoolDetail, SettingsPanel, ICloudGate, VisitWizard */

/* ============================================================
   COMPOUND DETAIL — fills the drawer
   ============================================================ */
function CompoundDetail({ compound, tab = '概览' }) {
  if (!compound) return null;
  const statusLabel = { unvisited: '未看', want: '想看', visited: '看过', excluded: '排除' }[compound.status];
  const statusColor = STATUS_COLORS[compound.status];

  return (
    <>
      <div className="cd-header">
        <span className="cd-back"><Icon name="chevron-left" size={20} strokeWidth={2}/></span>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="cd-title">{compound.name}</div>
          <div className="cd-sub">
            <span>{compound.district}</span><span className="dot"/>
            <span>{compound.zone}</span><span className="dot"/>
            <span>建成 {compound.buildYear}</span>
          </div>
          <div style={{ marginTop: 10, display: 'flex', gap: 6, alignItems: 'center' }}>
            <span className="cd-status-pill" style={{ background: statusColor }}>
              <span className="dot-i"/>{statusLabel}
            </span>
            {compound.rating && <Stars value={compound.rating} size={13}/>}
            {compound.priceWan && <span style={{ fontSize: 12, color: 'var(--ink-500)', marginLeft: 'auto' }}>参考报价 <strong style={{ color: 'var(--ink-800)', fontWeight: 600 }}>{compound.priceWan}</strong> 万</span>}
          </div>
        </div>
      </div>

      <div className="cd-segments">
        {['概览', '看房', '学校', '学区'].map(t => (
          <button key={t} className={`cd-segment ${tab === t ? 'active' : ''}`}>
            {t}{t === '看房' && <span style={{ marginLeft: 4, color: 'var(--ink-400)', fontWeight: 400 }}>2</span>}
          </button>
        ))}
      </div>

      <div className="cd-body">
        {tab === '概览' && <CDOverview compound={compound}/>}
        {tab === '看房' && <CDVisits compound={compound}/>}
        {tab === '学校' && <CDSchools compound={compound}/>}
        {tab === '学区' && <CDZone compound={compound}/>}
      </div>
    </>
  );
}

function CDOverview({ compound }) {
  return (
    <>
      <div>
        <div className="cd-section-label">基础信息</div>
        <div className="cd-keyvals">
          <div><div className="cd-kv-label">地址</div><div className="cd-kv-value">和平区昆明路 28 号</div></div>
          <div><div className="cd-kv-label">行政区</div><div className="cd-kv-value">{compound.district}</div></div>
          <div><div className="cd-kv-label">建成年份</div><div className="cd-kv-value">{compound.buildYear}</div></div>
          <div><div className="cd-kv-label">总楼栋</div><div className="cd-kv-value">8 栋 · 共 412 户</div></div>
          <div><div className="cd-kv-label">物业费</div><div className="cd-kv-value">2.30 元/㎡·月</div></div>
          <div><div className="cd-kv-label">产权年限</div><div className="cd-kv-value">70 年</div></div>
          <div><div className="cd-kv-label">绿化率</div><div className="cd-kv-value">38%</div></div>
          <div><div className="cd-kv-label">车位比</div><div className="cd-kv-value">1:1.2</div></div>
        </div>
      </div>

      <div>
        <div className="cd-section-label">我的标记</div>
        <div className="cd-stat-row">
          <div className="cd-stat">
            <div className="cd-stat-label">优先级</div>
            <div className="cd-stat-value">★★★★☆</div>
            <div className="cd-stat-sub">A 级候选</div>
          </div>
          <div className="cd-stat">
            <div className="cd-stat-label">看房次数</div>
            <div className="cd-stat-value">2</div>
            <div className="cd-stat-sub">最近 5 月 8 日</div>
          </div>
          <div className="cd-stat">
            <div className="cd-stat-label">报价区间</div>
            <div className="cd-stat-value">680 – 720</div>
            <div className="cd-stat-sub">万元</div>
          </div>
        </div>
      </div>

      <div>
        <div className="cd-section-label">私人备注</div>
        <div className="cd-visit-note">
          {`阳台朝南，窗外是树。\n中介说业主诚心卖，可谈到 700 出头。社区里有老人晨练但不吵。`}
        </div>
      </div>
    </>
  );
}

function CDVisits({ compound }) {
  return (
    <>
      <button className="btn-gray" style={{ alignSelf: 'flex-start', padding: '8px 14px', fontSize: 13, borderRadius: 9 }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <Icon name="plus" size={14} strokeWidth={1.5}/> 再次看房
        </span>
      </button>
      {TPA_VISITS_C2.map(v => (
        <div key={v.id} className="cd-visit">
          <div className="cd-visit-h">
            <div>
              <div className="cd-visit-date">{v.date}</div>
              <div className="cd-visit-meta">{v.floor} · {v.area} ㎡ · 报价 {v.priceWan} 万</div>
            </div>
            <Stars value={v.overall} size={14}/>
          </div>
          <div className="cd-rate-grid">
            <div className="cd-rate"><div className="cd-rate-label">采光</div><Stars value={v.light}/></div>
            <div className="cd-rate"><div className="cd-rate-label">噪音</div><Stars value={v.noise}/></div>
            <div className="cd-rate"><div className="cd-rate-label">户型</div><Stars value={v.layout}/></div>
            <div className="cd-rate"><div className="cd-rate-label">物业</div><Stars value={v.propertyMgmt}/></div>
          </div>
          <div className="cc-tags">
            {v.tags.map((t, i) => <TagChip key={i} polarity={t.p}>{t.label}</TagChip>)}
          </div>
          <div className="cd-visit-note">{v.note}</div>
          <div className="cd-thumb-strip">
            {Array.from({ length: Math.min(v.thumbs, 4) }).map((_, i) => (
              <div key={i} className="cc-thumb"><Icon name="image" size={16} strokeWidth={1.25}/></div>
            ))}
            {v.thumbs > 4 && <div className="cc-thumb more">+{v.thumbs - 4}</div>}
          </div>
        </div>
      ))}
    </>
  );
}

function CDSchools({ compound }) {
  return (
    <>
      <div>
        <div className="cd-section-label">对口小学 · 单校划片</div>
        <div className="cd-school-row">
          <div className="sr-icon"><Icon name="book-open" size={18} strokeWidth={1.5}/></div>
          <div className="sr-body">
            <div className="sr-name">{compound.primarySchool || '万全道小学'}</div>
            <div className="sr-sub">和平区 · 顶尖 · 中考升学率 32%</div>
          </div>
          <span className="tier-badge tier-top">顶尖</span>
          <span className="sr-arrow"><Icon name="chevron-right" size={18} strokeWidth={2}/></span>
        </div>
      </div>

      <div>
        <div className="cd-section-label">学区初中 · 摇号范围</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[
            { name: '昆鹏中学', sub: '市第5 · 前10%率 28%', tier: '顶尖', tierCls: 'tier-top' },
            { name: '和平实验中学', sub: '市第14 · 前10%率 19%', tier: '顶尖', tierCls: 'tier-top' },
            { name: '汇文中学', sub: '市第31 · 前10%率 8%', tier: '优质', tierCls: 'tier-good' },
          ].map((s, i) => (
            <div key={i} className="cd-school-row">
              <div className="sr-icon"><Icon name="graduation-cap" size={18} strokeWidth={1.5}/></div>
              <div className="sr-body">
                <div className="sr-name">{s.name}</div>
                <div className="sr-sub">{s.sub}</div>
              </div>
              <span className={`tier-badge ${s.tierCls}`}>{s.tier}</span>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

function CDZone({ compound }) {
  return (
    <>
      <div>
        <div className="cd-section-label">{compound.zone}</div>
        <div className="cd-stat-row">
          <div className="cd-stat">
            <div className="cd-stat-label">学区等级</div>
            <div className="cd-stat-value" style={{ color: '#8A6818' }}>顶尖</div>
            <div className="cd-stat-sub">按区内初中整体水平</div>
          </div>
          <div className="cd-stat">
            <div className="cd-stat-label">落户年限</div>
            <div className="cd-stat-value">3 年</div>
            <div className="cd-stat-sub">2024 招生要求</div>
          </div>
        </div>
      </div>
      <div>
        <div className="cd-section-label">原文描述</div>
        <div className="cd-visit-note">珠江道以北，南门外大街以东，多伦道以南，海河以西。共覆盖 22 个住宅小区，3 所初中。</div>
      </div>
      <div>
        <div className="cd-section-label">招生政策原件</div>
        <div className="cd-school-row">
          <div className="sr-icon" style={{ background: 'var(--ink-150)', color: 'var(--ink-600)' }}>
            <Icon name="file-text" size={18} strokeWidth={1.5}/>
          </div>
          <div className="sr-body">
            <div className="sr-name">和平区 2024 年义务教育招生方案</div>
            <div className="sr-sub">官方文件 · 24 页 · 已离线缓存</div>
          </div>
          <span className="sr-arrow"><Icon name="chevron-right" size={18} strokeWidth={2}/></span>
        </div>
      </div>
    </>
  );
}

/* ============================================================
   SCHOOL DETAIL
   ============================================================ */
function SchoolDetail({ school }) {
  if (!school) return null;
  const tierClass = { 顶尖: 'tier-top', 优质: 'tier-good', 普通: 'tier-reg', 薄弱: 'tier-weak' }[school.tier];
  return (
    <>
      <div className="cd-header">
        <span className="cd-back"><Icon name="chevron-left" size={20} strokeWidth={2}/></span>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="cd-title">{school.name}</div>
          <div className="cd-sub">
            <span>{school.district}</span><span className="dot"/>
            <span>{school.type}</span><span className="dot"/>
            <span>{school.zone}</span>
          </div>
          <div style={{ marginTop: 10, display: 'flex', gap: 8, alignItems: 'center' }}>
            <span className={`tier-badge ${tierClass}`}>{school.tier}</span>
            <span style={{ fontSize: 12, color: 'var(--ink-500)' }}>建于 {school.foundedYear}</span>
            <span style={{ fontSize: 12, color: 'var(--ink-500)', marginLeft: 'auto' }}>关联小区 <strong style={{ color: 'var(--ink-800)', fontWeight: 600 }}>{school.compounds}</strong> 个</span>
          </div>
        </div>
      </div>

      <div className="cd-body">
        <div>
          <div className="cd-section-label">中考排名（近 3 年）</div>
          <div className="sd-rank-bar">
            <div className="sd-rank-cell">
              <div className="sd-rank-year">2022</div>
              <div className="sd-rank-num">市第 7</div>
              <div className="sd-rank-sub">前 10%率 26%</div>
            </div>
            <div className="sd-rank-cell">
              <div className="sd-rank-year">2023</div>
              <div className="sd-rank-num">市第 4</div>
              <div className="sd-rank-sub">前 10%率 30%</div>
            </div>
            <div className="sd-rank-cell" style={{ paddingLeft: 10, borderLeft: '1px solid var(--border)' }}>
              <div className="sd-rank-year" style={{ color: 'var(--accent-700)' }}>2024 · 最新</div>
              <div className="sd-rank-num" style={{ color: 'var(--accent-700)' }}>市第 {school.rank.replace('市第','')}</div>
              <div className="sd-rank-sub">前 10%率 {school.top10}</div>
            </div>
          </div>
        </div>

        {school.motto && (
          <div>
            <div className="cd-section-label">校训</div>
            <div style={{ fontSize: 14, color: 'var(--ink-700)', fontStyle: 'italic' }}>{school.motto}</div>
          </div>
        )}

        <div>
          <div className="cd-section-label">关联小区 · {school.compounds}</div>
          <div style={{ background: 'var(--ink-50)', border: '1px solid var(--border)', borderRadius: 12, overflow: 'hidden' }}>
            {TPA_COMPOUNDS.filter(c => c.zone === school.zone).slice(0, 5).map(c => (
              <div key={c.id} className="sd-compound-row">
                <div className="pin-tile" style={{ background: STATUS_COLORS[c.status] }}>
                  <Icon name="map-pin" size={11} strokeWidth={2.5}/>
                </div>
                <span className="name">{c.name}</span>
                <span className="meta">{c.buildYear}{c.priceWan ? ` · ${c.priceWan} 万` : ''}</span>
              </div>
            ))}
            <div style={{ padding: '10px 12px', fontSize: 12, color: 'var(--accent-600)', cursor: 'pointer', textAlign: 'center' }}>
              查看全部 {school.compounds} 个 →
            </div>
          </div>
        </div>

        <div>
          <div className="cd-section-label">招生简章</div>
          <div className="cd-school-row">
            <div className="sr-icon" style={{ background: 'var(--ink-150)', color: 'var(--ink-600)' }}>
              <Icon name="file-text" size={18} strokeWidth={1.5}/>
            </div>
            <div className="sr-body">
              <div className="sr-name">2024 年 {school.type}招生公告</div>
              <div className="sr-sub">PDF · 已离线缓存</div>
            </div>
            <span className="sr-arrow"><Icon name="chevron-right" size={18} strokeWidth={2}/></span>
          </div>
        </div>
      </div>
    </>
  );
}

/* ============================================================
   SETTINGS PANEL (fills drawer)
   ============================================================ */
function SettingsPanel() {
  return (
    <>
      <div className="cd-header">
        <span className="cd-back"><Icon name="chevron-left" size={20} strokeWidth={2}/></span>
        <div>
          <div className="cd-title">设置</div>
          <div className="cd-sub"><span>本地偏好不进 iCloud</span></div>
        </div>
      </div>

      <div className="cd-body">
        <div>
          <div className="cd-section-label">iCloud 同步</div>
          <div className="set-quota">
            <div className="quota-row">
              <div><span className="quota-used">412</span><span style={{ fontSize: 14, color: 'var(--ink-500)', marginLeft: 4 }}>MB</span></div>
              <div className="quota-of">/ 1 GB 免费</div>
            </div>
            <div className="quota-bar"><div style={{ width: '41%' }}/></div>
            <div className="quota-breakdown">
              <span><span className="quota-dot" style={{ background: 'var(--accent-500)' }}/>照片 348 MB</span>
              <span><span className="quota-dot" style={{ background: '#5B7C9C' }}/>记录 52 MB</span>
              <span><span className="quota-dot" style={{ background: '#9C968B' }}/>缓存 12 MB</span>
            </div>
          </div>
          <div className="set-group" style={{ marginTop: 10 }}>
            <div className="set-row">
              <div className="icon-tile accent"><Icon name="cloud" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">同步状态</div><div className="sub">最近同步 2 分钟前</div></div>
              <span className="value" style={{ color: '#5F7F65' }}>● 正常</span>
            </div>
            <div className="set-row">
              <div className="icon-tile"><Icon name="image" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">照片压缩</div><div className="sub">1280px 长边 · HEIC · Q 0.8</div></div>
              <span className="chev"><Icon name="chevron-right" size={16} strokeWidth={2}/></span>
            </div>
            <div className="set-row">
              <div className="icon-tile"><Icon name="refresh-cw" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">仅 Wi-Fi 同步照片</div></div>
              <Switch value onChange={() => {}}/>
            </div>
          </div>
        </div>

        <div>
          <div className="cd-section-label">地图</div>
          <div className="set-group">
            <div className="set-row">
              <div className="icon-tile"><Icon name="map" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">地图样式</div></div>
              <span className="value">标准</span>
              <span className="chev"><Icon name="chevron-right" size={16} strokeWidth={2}/></span>
            </div>
            <div className="set-row">
              <div className="icon-tile"><Icon name="locate" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">默认中心</div><div className="sub">和平区中心</div></div>
              <span className="chev"><Icon name="chevron-right" size={16} strokeWidth={2}/></span>
            </div>
            <div className="set-row">
              <div className="icon-tile"><Icon name="layers" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">默认学区图层</div></div>
              <span className="value">顶尖 · 优质</span>
              <span className="chev"><Icon name="chevron-right" size={16} strokeWidth={2}/></span>
            </div>
            <div className="set-row">
              <div className="icon-tile"><Icon name="moon" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">深色模式</div></div>
              <span className="value">跟随系统</span>
              <span className="chev"><Icon name="chevron-right" size={16} strokeWidth={2}/></span>
            </div>
          </div>
        </div>

        <div>
          <div className="cd-section-label">数据</div>
          <div className="set-group">
            <div className="set-row">
              <div className="icon-tile"><Icon name="database" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">学区数据版本</div><div className="sub">2024 招生季 · 5 月 12 日</div></div>
              <span className="value">v1.3.2</span>
            </div>
            <div className="set-row">
              <div className="icon-tile"><Icon name="download" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">检查公共数据更新</div></div>
              <span className="chev"><Icon name="chevron-right" size={16} strokeWidth={2}/></span>
            </div>
            <div className="set-row">
              <div className="icon-tile"><Icon name="upload" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">导出我的数据</div><div className="sub">JSON · 不含照片</div></div>
              <span className="chev"><Icon name="chevron-right" size={16} strokeWidth={2}/></span>
            </div>
          </div>
        </div>

        <div>
          <div className="cd-section-label">关于</div>
          <div className="set-group">
            <div className="set-row">
              <div className="icon-tile"><Icon name="info" size={14} strokeWidth={1.5}/></div>
              <div className="body"><div className="label">版本</div></div>
              <span className="value">1.0 (build 142)</span>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}

/* ============================================================
   ICLOUD GATE — covers drawer when not signed in
   ============================================================ */
function ICloudGate() {
  return (
    <div className="cloud-gate">
      <div className="icon-tile"><Icon name="cloud-off" size={26} strokeWidth={1.5}/></div>
      <h2>需要登录 iCloud</h2>
      <p>看房记录、照片和私人备注会通过 iCloud 在你的 iPad 和 iPhone 之间私密同步。地图仍可正常浏览。</p>
      <div className="actions">
        <button className="btn-filled" style={{ borderRadius: 12 }}>前往「设置 › iCloud」</button>
        <button className="btn-gray" style={{ borderRadius: 12 }}>仅本地使用</button>
      </div>
      <p style={{ marginTop: 18, fontSize: 11, color: 'var(--ink-400)', maxWidth: 280 }}>
        数据存放在你自己的 iCloud Private Database，开发者无法访问。
      </p>
    </div>
  );
}

/* ============================================================
   VISIT WIZARD — right-side sheet
   ============================================================ */
function VisitWizard({ step = 1, compound }) {
  return (
    <div className="wizard">
      <div className="wizard-header">
        <div>
          <div className="wizard-title">新建看房记录</div>
          <div style={{ fontSize: 12, color: 'var(--ink-500)', marginTop: 2 }}>{compound?.name || '昆明路花园'} · 5月19日（今天）</div>
        </div>
        <button className="btn-plain">取消</button>
      </div>
      <div className="wizard-stepper">
        {[1,2,3,4].map(i => <div key={i} className={`dot ${step >= i ? 'done' : ''}`}/>)}
      </div>
      <div className="wizard-body">
        {step === 1 && <WizStep1 compound={compound}/>}
        {step === 2 && <WizStep2/>}
        {step === 3 && <WizStep3/>}
        {step === 4 && <WizStep4/>}
      </div>
      <div className="wizard-footer">
        {step > 1 ? <button className="btn-plain">‹ 上一步</button> : <span/>}
        {step < 4 ? <button className="btn-filled">下一步</button> : <button className="btn-filled">保存看房记录</button>}
      </div>
    </div>
  );
}

function WizStep1({ compound }) {
  return (
    <>
      <div className="wizard-step-label">步骤 1 / 4 · 基本信息</div>
      <div>
        <div className="wizard-field-label">小区</div>
        <div style={{ padding: '11px 14px', border: '1px solid var(--border)', borderRadius: 12, background: 'var(--ink-50)', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div className="cc-pin" style={{ width: 22, height: 22, borderRadius: 6, background: STATUS_COLORS[compound?.status || 'visited'] }}>
            <Icon name="map-pin" size={11} strokeWidth={2.5}/>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 500, color: 'var(--ink-900)' }}>{compound?.name || '昆明路花园'}</div>
            <div style={{ fontSize: 11, color: 'var(--ink-500)' }}>{compound?.district} · {compound?.zone}</div>
          </div>
          <span style={{ fontSize: 12, color: 'var(--accent-600)' }}>更换</span>
        </div>
      </div>
      <div>
        <div className="wizard-field-label">楼层</div>
        <div className="chip-row">
          <button className="chip-pick">低层 1-3</button>
          <button className="chip-pick on">中层 4-9</button>
          <button className="chip-pick">高层 10+</button>
        </div>
      </div>
      <div>
        <div className="wizard-field-label">面积 <span style={{ fontSize: 11, color: 'var(--ink-500)', fontWeight: 400 }}>· 滑动选择</span></div>
        <SliderField value={92} min={40} max={200} unit="㎡"/>
      </div>
      <div>
        <div className="wizard-field-label">报价 <span style={{ fontSize: 11, color: 'var(--ink-500)', fontWeight: 400 }}>· 步进调整</span></div>
        <StepperField value={580} step={10} unit="万元"/>
      </div>
    </>
  );
}

function WizStep2() {
  return (
    <>
      <div className="wizard-step-label">步骤 2 / 4 · 评分</div>
      <div style={{ fontSize: 12, color: 'var(--ink-500)' }}>留空也没关系。回家再补。</div>
      <div><div className="wizard-field-label">总评</div><StarsInput value={4} onChange={() => {}}/></div>
      <div><div className="wizard-field-label">采光</div><StarsInput value={5} onChange={() => {}}/></div>
      <div><div className="wizard-field-label">噪音 · 5 = 最静</div><StarsInput value={3} onChange={() => {}}/></div>
      <div><div className="wizard-field-label">户型</div><StarsInput value={4} onChange={() => {}}/></div>
      <div><div className="wizard-field-label">物业</div><StarsInput value={0} onChange={() => {}}/></div>
    </>
  );
}

function WizStep3() {
  const groups = [
    { cat: '采光', items: [['南北通透','+',true],['全朝南','+',false],['西晒','-',false],['楼层遮挡','-',false]] },
    { cat: '噪音', items: [['安静','+',true],['临街主干道','-',false],['楼上熊孩子','-',false],['高架旁','-',false]] },
    { cat: '装修', items: [['新装精装','+',true],['次新整洁','+',false],['陈旧','-',false],['毛坯','0',false]] },
    { cat: '物业', items: [['物业积极','+',true],['物业散漫','-',false],['电梯老旧','-',false],['安保严格','+',false]] },
  ];
  return (
    <>
      <div className="wizard-step-label">步骤 3 / 4 · 快速标签</div>
      <div style={{ fontSize: 12, color: 'var(--ink-500)' }}>已选 4 个。点一下加上，再点一下取消。</div>
      {groups.map(g => (
        <div key={g.cat}>
          <div className="wizard-field-label">{g.cat}</div>
          <div className="chip-row">
            {g.items.map(([label, p, on]) => (
              <button key={label} className={`chip-pick ${on ? 'on' : ''}`}>
                <span style={{ opacity: 0.55, marginRight: 4 }}>{p}</span>{label}
              </button>
            ))}
          </div>
        </div>
      ))}
    </>
  );
}

function WizStep4() {
  return (
    <>
      <div className="wizard-step-label">步骤 4 / 4 · 拍照与备注</div>
      <div>
        <div className="wizard-field-label">现场拍照 <span style={{ fontSize: 11, color: 'var(--ink-500)', fontWeight: 400 }}>· 已 5 张</span></div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 6 }}>
          {[1,2,3,4,5].map(i => (
            <div key={i} style={{ aspectRatio: '1 / 1', background: 'var(--ink-150)', border: '1px solid var(--border)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--ink-400)' }}>
              <Icon name="image" size={20} strokeWidth={1.5}/>
            </div>
          ))}
          <div style={{ aspectRatio: '1 / 1', background: 'var(--accent-50)', border: '1px dashed var(--accent-300)', borderRadius: 10, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--accent-600)', cursor: 'pointer' }}>
            <Icon name="camera" size={20} strokeWidth={1.5}/>
          </div>
        </div>
      </div>
      <div>
        <div className="wizard-field-label">备注 <span style={{ fontSize: 11, color: 'var(--ink-500)', fontWeight: 400 }}>· 可空 · 支持语音输入</span></div>
        <div style={{ width: '100%', minHeight: 100, padding: 14, borderRadius: 12, border: '1px solid var(--border)', fontSize: 14, background: 'var(--ink-50)', color: 'var(--ink-800)', lineHeight: 1.55 }}>
          阳台朝南，窗外是树。中介说业主诚心卖，可谈到 700 出头。社区里有老人晨练但不吵。
          <span style={{ display: 'inline-block', width: 1.5, height: 16, background: 'var(--accent-500)', verticalAlign: 'middle', marginLeft: 2, animation: 'blink 1s infinite' }}/>
        </div>
        <div style={{ marginTop: 8, display: 'flex', justifyContent: 'flex-end' }}>
          <span style={{ fontSize: 11, color: 'var(--accent-600)', display: 'inline-flex', alignItems: 'center', gap: 4, cursor: 'pointer' }}>
            <Icon name="mic" size={12} strokeWidth={1.5}/> 语音输入
          </span>
        </div>
      </div>
      <div style={{ fontSize: 11, color: 'var(--ink-500)', padding: 12, background: 'var(--ink-50)', border: '1px solid var(--border)', borderRadius: 10, lineHeight: 1.55 }}>
        <span style={{ color: 'var(--accent-600)' }}>已自动保存</span> · 最少有日期 + 小区即可保存为草稿，其他字段可后补。
      </div>
    </>
  );
}

/* ============================================================
   Form primitives — Slider, Stepper
   ============================================================ */
function SliderField({ value, min, max, unit }) {
  const pct = ((value - min) / (max - min)) * 100;
  return (
    <div style={{ padding: '4px 2px' }}>
      <div style={{ position: 'relative', height: 24, display: 'flex', alignItems: 'center' }}>
        <div style={{ position: 'absolute', left: 0, right: 0, top: 11, height: 4, borderRadius: 2, background: 'var(--ink-150)' }}/>
        <div style={{ position: 'absolute', left: 0, top: 11, width: `${pct}%`, height: 4, borderRadius: 2, background: 'var(--accent-500)' }}/>
        <div style={{ position: 'absolute', left: `${pct}%`, top: 0, width: 24, height: 24, marginLeft: -12, borderRadius: '50%', background: '#FAF8F4', border: '1px solid var(--border)', boxShadow: '0 2px 6px rgba(28,27,25,0.15)' }}/>
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: 'var(--ink-500)', marginTop: 4 }}>
        <span>{min} {unit}</span>
        <span style={{ color: 'var(--accent-700)', fontWeight: 600, fontSize: 15 }}>{value} {unit}</span>
        <span>{max} {unit}</span>
      </div>
    </div>
  );
}

function StepperField({ value, step, unit }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <button style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--ink-100)', border: 'none', color: 'var(--ink-800)', fontSize: 22, cursor: 'pointer', fontFamily: 'inherit' }}>−</button>
      <div style={{ flex: 1, textAlign: 'center', padding: '11px 14px', border: '1px solid var(--border)', borderRadius: 12, background: 'var(--ink-50)' }}>
        <span style={{ fontSize: 22, fontWeight: 600, color: 'var(--ink-900)', letterSpacing: '-0.4px' }}>{value}</span>
        <span style={{ fontSize: 12, color: 'var(--ink-500)', marginLeft: 6 }}>{unit}</span>
      </div>
      <button style={{ width: 44, height: 44, borderRadius: 12, background: 'var(--accent-500)', border: 'none', color: '#FAF8F4', fontSize: 22, cursor: 'pointer', fontFamily: 'inherit' }}>+</button>
    </div>
  );
}

Object.assign(window, {
  CompoundDetail, SchoolDetail, SettingsPanel, ICloudGate, VisitWizard,
  SliderField, StepperField,
});
