/* Tianjin Property Atlas — screen renderers
   Configurable iPad screen, plus full-screen variants (seed import, polygon editor).
   Each artboard in the design canvas mounts one of these with a frozen view config. */

const { useState: useStateScreens } = React;

/* ============================================================
   Toolbar (parameterized)
   ============================================================ */
function Toolbar({ layerActive, filterActive, syncStatus = 'synced' }) {
  const syncCfg = {
    synced:  { icon: 'cloud-check',  label: 'iCloud · 已同步', cls: '' },
    offline: { icon: 'cloud-off',    label: '离线 · 同步暂停', cls: 'offline' },
    warning: { icon: 'cloud-alert',  label: 'iCloud · 容量告警', cls: 'warning' },
  }[syncStatus];
  return (
    <div className="toolbar">
      <button className={`tb-button ${layerActive ? 'active' : ''}`}>
        <Icon name="layers" size={16} strokeWidth={1.5} />
        <span>图层</span>
        <span className="caret">▾</span>
      </button>
      <button className={`tb-button ${filterActive ? 'active' : ''}`}>
        <Icon name="sliders" size={16} strokeWidth={1.5} />
        <span>筛选</span>
        <span className="caret">▾</span>
      </button>
      <div style={{ width: 1, height: 18, background: 'var(--border)', margin: '0 4px' }}/>
      <button className="tb-button">
        <Icon name="plus" size={16} strokeWidth={1.5} />
        <span>新建看房</span>
      </button>
      <div className="toolbar-spacer"/>
      <span className={`sync-pill ${syncCfg.cls}`}><Icon name={syncCfg.icon} size={14} strokeWidth={1.5}/>{syncCfg.label}</span>
      <button className="tb-icon-only"><Icon name="search" size={18} strokeWidth={1.5}/></button>
      <button className="tb-icon-only"><Icon name="settings" size={18} strokeWidth={1.5}/></button>
    </div>
  );
}

/* ============================================================
   Map overlays (legend / FAB / selection chip / pin popover / offline)
   ============================================================ */
function MapOverlays({ selectedCompound, pinPopoverCompound, offline }) {
  return (
    <>
      {offline && (
        <div className="offline-chip"><Icon name="wifi-off" size={12} strokeWidth={1.8}/>离线 · 缓存地图 · 同步暂停</div>
      )}
      {selectedCompound && !pinPopoverCompound && (
        <div className="map-selection">
          <div className="cc-pin" style={{ background: STATUS_COLORS[selectedCompound.status], width: 22, height: 22, borderRadius: 6 }}>
            <Icon name="map-pin" size={12} strokeWidth={2.5} />
          </div>
          <div>
            <div style={{ fontWeight: 600 }}>{selectedCompound.name}</div>
            <div className="meta">{selectedCompound.zone} · {selectedCompound.district} · {selectedCompound.buildYear}</div>
          </div>
        </div>
      )}
      {pinPopoverCompound && (
        <PinPopover compound={pinPopoverCompound} />
      )}
      <div className="legend">
        <div className="legend-title">学区等级</div>
        <div className="legend-row"><span className="swatch" style={{ background: '#C99B2C', opacity: 0.75 }}/>顶尖</div>
        <div className="legend-row"><span className="swatch" style={{ background: '#5B7C9C', opacity: 0.75 }}/>优质</div>
        <div className="legend-row"><span className="swatch" style={{ background: '#9C968B', opacity: 0.75 }}/>普通</div>
        <div className="legend-row"><span className="swatch" style={{ background: '#B8736B', opacity: 0.75 }}/>薄弱</div>
      </div>
      <div className="map-controls">
        <div className="map-fab zoom-stack">
          <div><Icon name="plus" size={16} strokeWidth={2}/></div>
          <div><Icon name="minus" size={16} strokeWidth={2}/></div>
        </div>
        <div className="map-fab"><Icon name="navigation" size={16} strokeWidth={1.5}/></div>
      </div>
    </>
  );
}

/* Anchored to top-left of map area for the pin's stylized position */
function PinPopover({ compound }) {
  // anchor a bit right of pin position (compound.x, compound.y are in 800×560 viewBox)
  // we just place it in absolute pixels for the demo
  const left = `${(compound.x / 800) * 100}%`;
  const top = `${((compound.y + 12) / 560) * 100}%`;
  return (
    <div className="pin-popover" style={{ left, top, marginLeft: 14, marginTop: 4 }}>
      <div className="tip" style={{ left: 20 }}/>
      <h4>{compound.name}</h4>
      <div className="sub">{compound.district} · {compound.zone} · {compound.buildYear}</div>
      <div className="kvs">
        {compound.primarySchool && (<><div><div className="k">对口小学</div><div className="v">{compound.primarySchool}</div></div></>)}
        {compound.priceWan && (<div><div className="k">参考价</div><div className="v">{compound.priceWan} 万</div></div>)}
        {compound.areaM2 && (<div><div className="k">面积</div><div className="v">{compound.areaM2} ㎡</div></div>)}
        {compound.rating && (<div><div className="k">总评</div><div className="v"><Stars value={compound.rating}/></div></div>)}
      </div>
      <div className="actions">
        <button className="btn-gray" style={{ padding: '7px 10px', fontSize: 12, borderRadius: 8 }}>查看详情</button>
        <button className="btn-filled" style={{ padding: '7px 10px', fontSize: 12, borderRadius: 8 }}>开始看房</button>
      </div>
    </div>
  );
}

/* ============================================================
   Drawer panels — depending on drawerMode
   ============================================================ */
function DrawerList({ activeTab, compounds, schools, zones, selectedId, emptyState }) {
  const visitsByStatus = {
    want: compounds.filter(c => c.status === 'want'),
    visited: compounds.filter(c => c.status === 'visited'),
    excluded: compounds.filter(c => c.status === 'excluded'),
  };
  return (
    <>
      <div className="drawer-tabs">
        <button className={`drawer-tab ${activeTab === 'school' ? 'active' : ''}`}>学校 <span className="count">{schools.length}</span></button>
        <button className={`drawer-tab ${activeTab === 'visit' ? 'active' : ''}`}>看房 <span className="count">{visitsByStatus.want.length + visitsByStatus.visited.length}</span></button>
        <button className={`drawer-tab ${activeTab === 'zone' ? 'active' : ''}`}>区域 <span className="count">{zones.length}</span></button>
      </div>
      <div className="drawer-search">
        <div className="search">
          <Icon name="search" size={16} strokeWidth={2}/>
          <input value={emptyState === 'no-search' ? '万红里' : ''} readOnly placeholder={activeTab === 'school' ? '搜索学校 / 学区' : activeTab === 'visit' ? '搜索小区 / 标签' : '搜索我的区域'}/>
        </div>
      </div>

      <div className="drawer-list">
        {emptyState === 'no-visits' && <NoVisitsEmpty/>}
        {emptyState === 'no-search' && <NoSearchResultsEmpty/>}
        {emptyState === 'no-filter' && <NoFilterResultsEmpty/>}
        {!emptyState && activeTab === 'school' && schools.map(s => <SchoolCard key={s.id} school={s}/>)}
        {!emptyState && activeTab === 'visit' && (
          <>
            <div className="drawer-section-h">想看 <span className="n">{visitsByStatus.want.length}</span></div>
            {visitsByStatus.want.map(c => <CompoundCard key={c.id} compound={c} selected={c.id === selectedId}/>)}
            <div className="drawer-section-h">看过 <span className="n">{visitsByStatus.visited.length}</span></div>
            {visitsByStatus.visited.map(c => <CompoundCard key={c.id} compound={c} selected={c.id === selectedId}/>)}
            <div className="drawer-section-h">排除 <span className="n">{visitsByStatus.excluded.length}</span></div>
            {visitsByStatus.excluded.map(c => <CompoundCard key={c.id} compound={c} selected={c.id === selectedId}/>)}
          </>
        )}
        {!emptyState && activeTab === 'zone' && (
          <>
            {zones.map(z => <ZoneCard key={z.id} zone={z}/>)}
            <button className="btn-gray" style={{ marginTop: 10 }}>
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                <Icon name="pen-tool" size={14} strokeWidth={1.5}/> 绘制新区域
              </span>
            </button>
          </>
        )}
      </div>
    </>
  );
}

/* Empty states inside drawer-list */
function NoVisitsEmpty() {
  return (
    <div className="empty-state">
      <div className="icon"><Icon name="clipboard-list" size={28} strokeWidth={1.25}/></div>
      <div className="title">还没有看房记录</div>
      <div className="body">在地图上点选一个小区，长按即可"开始看房"。</div>
      <div className="actions">
        <button className="btn-filled" style={{ fontSize: 14, padding: '10px 14px', borderRadius: 10 }}>+ 新建看房记录</button>
      </div>
    </div>
  );
}
function NoSearchResultsEmpty() {
  return (
    <div className="empty-state">
      <div className="icon"><Icon name="search" size={28} strokeWidth={1.25}/></div>
      <div className="title">未找到「万红里」</div>
      <div className="body">这个小区可能还不在数据库里。你可以手动添加，或换个关键词。</div>
      <div className="chips">
        <span className="history-chip"><Icon name="history" size={11} strokeWidth={1.5}/>万全道</span>
        <span className="history-chip"><Icon name="history" size={11} strokeWidth={1.5}/>南开二片</span>
        <span className="history-chip"><Icon name="history" size={11} strokeWidth={1.5}/>顶尖学区</span>
      </div>
      <div className="actions">
        <button className="btn-gray" style={{ fontSize: 13, padding: '9px 14px', borderRadius: 10 }}>
          <Icon name="plus" size={14} strokeWidth={1.5}/> 手动添加小区
        </button>
      </div>
    </div>
  );
}
function NoFilterResultsEmpty() {
  return (
    <div className="empty-state">
      <div className="icon"><Icon name="sliders" size={28} strokeWidth={1.25}/></div>
      <div className="title">条件过于严格</div>
      <div className="body">当前筛选下没有任何小区。试着放宽以下条件之一：</div>
      <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 8, marginTop: 16 }}>
        <div className="suggest-row">
          <Icon name="lightbulb" size={14} strokeWidth={1.5}/>
          <span>包含「普通」学区 → 多 <strong>9</strong> 个小区</span>
          <span className="accent" style={{ marginLeft: 'auto' }}>放宽</span>
        </div>
        <div className="suggest-row">
          <Icon name="lightbulb" size={14} strokeWidth={1.5}/>
          <span>包含「排除」状态 → 多 <strong>4</strong> 个小区</span>
          <span className="accent" style={{ marginLeft: 'auto' }}>放宽</span>
        </div>
      </div>
      <div className="actions">
        <button className="btn-plain" style={{ fontSize: 13 }}>重置全部筛选</button>
      </div>
    </div>
  );
}

/* ============================================================
   Popovers (layer / filter)
   ============================================================ */
function LayerPopover() {
  return (
    <div className="popover popover-layer" style={{ top: 88, left: 16 }}>
      <div className="grp">
        <div className="grp-label">图层</div>
        <PoCheckRow label="学区 polygon" checked onToggle={() => {}}/>
        <PoCheckRow label="我的区域" checked onToggle={() => {}}/>
        <PoCheckRow label="通勤圈" checked={false} onToggle={() => {}}/>
      </div>
      <div className="grp">
        <div className="grp-label">学年</div>
        <PoCheckRow label="2024 年招生" checked onToggle={() => {}}/>
      </div>
    </div>
  );
}
function FilterPopover() {
  return (
    <div className="popover popover-filter" style={{ top: 88, left: 110 }}>
      <div className="grp">
        <div className="grp-label">学区等级</div>
        <PoCheckRow label="顶尖" checked swatchColor="#C99B2C" onToggle={() => {}}/>
        <PoCheckRow label="优质" checked swatchColor="#5B7C9C" onToggle={() => {}}/>
        <PoCheckRow label="普通" checked={false} swatchColor="#9C968B" onToggle={() => {}}/>
        <PoCheckRow label="薄弱" checked={false} swatchColor="#B8736B" onToggle={() => {}}/>
      </div>
      <div className="grp">
        <div className="grp-label">小区状态</div>
        <PoCheckRow label="未看" checked swatchColor="#9C968B" onToggle={() => {}}/>
        <PoCheckRow label="想看" checked swatchColor="#5B7C9C" onToggle={() => {}}/>
        <PoCheckRow label="看过" checked swatchColor="#7A9A7E" onToggle={() => {}}/>
        <PoCheckRow label="排除" checked={false} swatchColor="#A85040" onToggle={() => {}}/>
      </div>
    </div>
  );
}

/* ============================================================
   The MainScreen — assembled from all the above
   ============================================================ */
function MainScreen({ view = {} }) {
  const {
    activeTab = 'visit',
    popover = null,             // 'layer' | 'filter' | null
    selectedId = 'c2',
    drawerMode = 'list',        // 'list' | 'compoundDetail' | 'schoolDetail' | 'settings'
    compoundDetailTab = '概览',
    schoolId = 's1',
    wizardStep = null,          // null | 1..4
    mapMode = 'normal',         // 'normal' | 'polygon' | 'mosaic'
    topBanner = null,           // null | 'offline' | 'icloud-full'
    mapChip = null,             // 'offline' | null
    gate = null,                // 'icloud' | null
    emptyState = null,
    pinPopoverId = null,
    syncStatus = 'synced',
  } = view;

  const selectedCompound = TPA_COMPOUNDS.find(c => c.id === selectedId);
  const detailCompound = drawerMode === 'compoundDetail' ? selectedCompound : null;
  const detailSchool = drawerMode === 'schoolDetail' ? TPA_SCHOOLS.find(s => s.id === schoolId) : null;
  const pinPopoverCompound = pinPopoverId ? TPA_COMPOUNDS.find(c => c.id === pinPopoverId) : null;

  return (
    <div className="frame platform-ios">
      <StatusBar/>
      <Toolbar layerActive={popover === 'layer'} filterActive={popover === 'filter'} syncStatus={syncStatus}/>

      {topBanner === 'offline' && (
        <div className="banner offline">
          <Icon name="wifi-off"/>
          <span>当前离线 — 本地读写正常，恢复网络后将自动同步。</span>
          <span className="b-action">查看缓存</span>
        </div>
      )}
      {topBanner === 'icloud-full' && (
        <div className="banner warning">
          <Icon name="alert-triangle"/>
          <span>iCloud 容量 940 MB / 1 GB — 仍可继续，但部分照片可能暂未同步。</span>
          <span className="b-action">升级 iCloud+</span>
        </div>
      )}

      {popover === 'layer' && <LayerPopover/>}
      {popover === 'filter' && <FilterPopover/>}

      <div className="split">
        <div className="map-pane">
          {mapMode === 'mosaic' ? (
            <PhotoMosaicBg/>
          ) : (
            <MapCanvas
              layers={{ zones: true, userAreas: true, commute: false }}
              tierFilter={{ top: true, good: true, reg: true, weak: true }}
              compounds={TPA_COMPOUNDS}
              selectedId={selectedId}
              onSelect={() => {}}
            />
          )}
          {mapMode !== 'mosaic' && <MapOverlays selectedCompound={selectedCompound} pinPopoverCompound={pinPopoverCompound} offline={mapChip === 'offline' && !topBanner}/>}
        </div>

        <div className="drawer">
          {drawerMode === 'list' && (
            <DrawerList activeTab={activeTab} compounds={TPA_COMPOUNDS} schools={TPA_SCHOOLS} zones={TPA_ZONES_USER} selectedId={selectedId} emptyState={emptyState}/>
          )}
          {drawerMode === 'compoundDetail' && (
            <CompoundDetail compound={detailCompound} tab={compoundDetailTab}/>
          )}
          {drawerMode === 'schoolDetail' && (
            <SchoolDetail school={detailSchool}/>
          )}
          {drawerMode === 'settings' && <SettingsPanel/>}

          {gate === 'icloud' && <ICloudGate/>}
        </div>
      </div>

      {wizardStep !== null && (
        <VisitWizard step={wizardStep} compound={selectedCompound}/>
      )}
    </div>
  );
}

/* ============================================================
   Photo mosaic background (visit wizard mode)
   24 tiles cycling through 8 distinct apartment-photo SVG scenes:
   sky-through-window / wood floor / kitchen counter / bathroom tile /
   ceiling lamp / treetops / bedroom / doorway.
   ============================================================ */
const MOSAIC_SCENES = [
  // 0 — window with sky + sill
  (k) => (
    <svg key={k} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <rect width="100" height="68" fill="#A4BAC8"/>
      <rect y="68" width="100" height="32" fill="#8B7A60"/>
      <rect y="64" width="100" height="6" fill="#D8CFBE"/>
      <rect x="48" width="4" height="68" fill="#EFEADD"/>
      <rect y="30" width="100" height="3" fill="#EFEADD"/>
      <circle cx="75" cy="22" r="8" fill="#F2E4C8" opacity="0.7"/>
    </svg>
  ),
  // 1 — wood plank floor with diagonal light streak
  (k) => (
    <svg key={k} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <rect width="100" height="100" fill="#8B6F50"/>
      <line x1="0" y1="22" x2="100" y2="22" stroke="#6E5538" strokeWidth="0.6"/>
      <line x1="0" y1="48" x2="100" y2="48" stroke="#6E5538" strokeWidth="0.6"/>
      <line x1="0" y1="74" x2="100" y2="74" stroke="#6E5538" strokeWidth="0.6"/>
      <polygon points="0,100 100,28 100,100" fill="rgba(255,235,180,0.22)"/>
    </svg>
  ),
  // 2 — kitchen with stove burners
  (k) => (
    <svg key={k} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <rect width="100" height="58" fill="#C8B89C"/>
      <rect y="58" width="100" height="42" fill="#3E3A35"/>
      <circle cx="30" cy="78" r="10" fill="#1C1B19" stroke="#7A736A" strokeWidth="0.6"/>
      <circle cx="30" cy="78" r="5" fill="none" stroke="#7A736A" strokeWidth="0.5"/>
      <circle cx="68" cy="78" r="10" fill="#1C1B19" stroke="#7A736A" strokeWidth="0.6"/>
      <circle cx="68" cy="78" r="5" fill="none" stroke="#7A736A" strokeWidth="0.5"/>
      <rect y="55" width="100" height="2" fill="#A89880"/>
    </svg>
  ),
  // 3 — bathroom tile pattern
  (k) => (
    <svg key={k} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <rect width="100" height="100" fill="#D8CFBA"/>
      <g stroke="#FAF8F4" strokeWidth="1" fill="none">
        <line x1="0" y1="20" x2="100" y2="20"/>
        <line x1="0" y1="40" x2="100" y2="40"/>
        <line x1="0" y1="60" x2="100" y2="60"/>
        <line x1="0" y1="80" x2="100" y2="80"/>
        <line x1="20" y1="0" x2="20" y2="100"/>
        <line x1="40" y1="0" x2="40" y2="100"/>
        <line x1="60" y1="0" x2="60" y2="100"/>
        <line x1="80" y1="0" x2="80" y2="100"/>
      </g>
      <rect x="62" y="38" width="24" height="40" rx="3" fill="#9CB0BC"/>
    </svg>
  ),
  // 4 — ceiling with light fixture
  (k) => (
    <svg key={k} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <rect width="100" height="100" fill="#F2EDDF"/>
      <radialGradient id={`g${k}`} cx="50%" cy="38%" r="40%">
        <stop offset="0%" stopColor="#FFE5B0" stopOpacity="0.85"/>
        <stop offset="100%" stopColor="#FFE5B0" stopOpacity="0"/>
      </radialGradient>
      <rect width="100" height="100" fill={`url(#g${k})`}/>
      <line x1="50" y1="0" x2="50" y2="30" stroke="#B5A089" strokeWidth="1.5"/>
      <circle cx="50" cy="38" r="14" fill="#FFE9B8" stroke="#D4A95C" strokeWidth="1"/>
      <circle cx="50" cy="38" r="5" fill="#FFF6D8"/>
    </svg>
  ),
  // 5 — treetops outside window
  (k) => (
    <svg key={k} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <rect width="100" height="58" fill="#B6CDD2"/>
      <rect y="58" width="100" height="42" fill="#5F7C5A"/>
      <circle cx="15" cy="58" r="22" fill="#7A9270"/>
      <circle cx="50" cy="50" r="26" fill="#6A8A66"/>
      <circle cx="82" cy="58" r="20" fill="#7A9270"/>
      <circle cx="35" cy="68" r="14" fill="#5F7E5A"/>
    </svg>
  ),
  // 6 — bedroom (bed against wall)
  (k) => (
    <svg key={k} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <rect width="100" height="55" fill="#B0A088"/>
      <rect y="55" width="100" height="45" fill="#6E5A42"/>
      <rect x="8" y="40" width="84" height="48" fill="#F2EDDF" stroke="#A89880" strokeWidth="0.6"/>
      <rect x="8" y="40" width="84" height="14" fill="#E6DBC4"/>
      <rect x="15" y="42" width="28" height="10" rx="1.5" fill="#FAF8F4"/>
      <rect x="55" y="42" width="28" height="10" rx="1.5" fill="#FAF8F4"/>
    </svg>
  ),
  // 7 — doorway / hallway
  (k) => (
    <svg key={k} viewBox="0 0 100 100" preserveAspectRatio="xMidYMid slice">
      <rect width="100" height="100" fill="#B0A088"/>
      <polygon points="0,0 100,15 100,85 0,100" fill="#A8987C" opacity="0.6"/>
      <rect x="32" y="18" width="38" height="82" fill="#7A5E40" stroke="#5C4528" strokeWidth="0.8"/>
      <rect x="38" y="26" width="26" height="30" fill="#6B5238" stroke="#5C4528" strokeWidth="0.5"/>
      <rect x="38" y="62" width="26" height="30" fill="#6B5238" stroke="#5C4528" strokeWidth="0.5"/>
      <circle cx="62" cy="60" r="2" fill="#D4A95C"/>
    </svg>
  ),
];

function PhotoMosaicBg() {
  // 24 tiles, sequence chosen to feel like a real shoot — lots of windows,
  // floor, kitchen, balcony, bedroom interleaved.
  const seq = [
    0, 5, 1, 6, 0, 4,
    1, 2, 3, 5, 0, 1,
    4, 6, 1, 3, 7, 2,
    5, 0, 6, 1, 4, 7,
  ];
  return (
    <div className="photo-mosaic">
      {seq.map((s, i) => (
        <div key={i} className="photo-tile">{MOSAIC_SCENES[s](i)}</div>
      ))}
    </div>
  );
}

Object.assign(window, { MainScreen, Toolbar, PhotoMosaicBg });
