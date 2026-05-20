/* Tianjin Property Atlas — full-frame screens
   SeedImporter (dark progress), PolygonEditor (map + drawing handles) */

/* ============================================================
   SEED IMPORTER (first-launch full-screen progress)
   ============================================================ */
function SeedImportScreen() {
  const steps = [
    { name: '学区边界 polygon', count: '24 / 24', state: 'done' },
    { name: '学校数据', count: '218 / 218', state: 'done' },
    { name: '小区数据', count: '1,247 / 3,140', state: 'active' },
    { name: '中考排名（近 3 年）', count: '— 等待中', state: 'pending' },
    { name: '地铁线路', count: '— 等待中', state: 'pending' },
    { name: '招生政策原件', count: '— 等待中', state: 'pending' },
  ];
  const percent = 47;
  return (
    <div className="seed-screen">
      <div className="seed-mark"><Icon name="map" size={32} strokeWidth={1.5}/></div>
      <div className="seed-title">准备本地数据库</div>
      <div className="seed-sub">第一次启动会一次性把天津市内六区的学区与小区数据导入到本机，约 1–2 分钟。之后离线也能用。</div>

      <div className="seed-steps">
        {steps.map((s, i) => (
          <div key={i} className={`seed-step ${s.state}`}>
            <div className="badge">{s.state === 'done' && <Icon name="check" size={12} strokeWidth={2.5}/>}</div>
            <div className="name">{s.name}</div>
            <div className="count">{s.count}</div>
          </div>
        ))}
      </div>

      <div className="seed-progress"><div style={{ width: `${percent}%` }}/></div>
      <div className="seed-percent">{percent}% · 预计还需 38 秒</div>
    </div>
  );
}

/* ============================================================
   POLYGON EDITOR — full map with drawing handles
   ============================================================ */
function PolygonEditorScreen({ mode = 'tap' }) {
  // 'tap' = manual point-by-point; 'pencil' = freehand
  const points = [
    [320, 200], [440, 180], [520, 240], [560, 340], [490, 410], [380, 420], [310, 360],
  ];
  const pointsStr = points.map(p => p.join(',')).join(' ');
  const midpoints = points.map((p, i) => {
    const next = points[(i + 1) % points.length];
    return [(p[0] + next[0]) / 2, (p[1] + next[1]) / 2];
  });

  return (
    <div className="frame platform-ios">
      <StatusBar/>
      <div className="toolbar">
        <button className="tb-button">
          <Icon name="chevron-left" size={16} strokeWidth={1.5}/>
          <span>退出绘制</span>
        </button>
        <div style={{ width: 1, height: 18, background: 'var(--border)', margin: '0 4px' }}/>
        <span style={{ fontSize: 13, color: 'var(--ink-700)', fontWeight: 500 }}>新建私有区域</span>
        <div className="toolbar-spacer"/>
        <span style={{ fontSize: 11, color: 'var(--ink-500)' }}>7 个顶点 · 约 4.2 km²</span>
        <button className="tb-button" style={{ background: 'var(--accent-500)', color: '#FAF8F4' }}>
          <Icon name="check" size={16} strokeWidth={2}/>
          <span>完成</span>
        </button>
      </div>

      <div style={{ flex: 1, position: 'relative' }}>
        <div className="map-pane" style={{ position: 'absolute', inset: 0, borderRight: 'none' }}>
          {/* base map */}
          <svg className="map-svg" viewBox="0 0 800 560" preserveAspectRatio="xMidYMid slice">
            {/* grid */}
            <g opacity="0.55">
              {Array.from({ length: 28 }, (_, i) => (
                <line key={`h${i}`} x1="0" y1={i * 20} x2="800" y2={i * 20} stroke="#D8CFBE" strokeWidth="0.5"/>
              ))}
              {Array.from({ length: 40 }, (_, i) => (
                <line key={`v${i}`} x1={i * 20} y1="0" x2={i * 20} y2="560" stroke="#D8CFBE" strokeWidth="0.5"/>
              ))}
            </g>
            {/* river */}
            <path d="M -20 80 Q 180 140 260 200 T 480 320 Q 600 380 820 360"
              fill="none" stroke="#B9CBD0" strokeWidth="22" opacity="0.55" strokeLinecap="round"/>
            {/* roads */}
            <g stroke="#C9C0AD" strokeLinecap="round" opacity="0.85">
              <line x1="60" y1="0" x2="180" y2="560" strokeWidth="4"/>
              <line x1="320" y1="0" x2="380" y2="560" strokeWidth="4"/>
              <line x1="560" y1="0" x2="620" y2="560" strokeWidth="3"/>
              <line x1="0" y1="260" x2="800" y2="240" strokeWidth="4"/>
              <line x1="0" y1="440" x2="800" y2="420" strokeWidth="3"/>
            </g>

            {/* faded existing school zone underneath */}
            <polygon points="360,180 510,160 570,260 480,330 380,310 340,240"
              fill="rgba(91,124,156,0.10)" stroke="rgba(91,124,156,0.5)" strokeWidth="1" strokeDasharray="3 3"/>

            {/* active polygon being drawn */}
            <polygon points={pointsStr}
              fill="rgba(181,112,58,0.18)"
              stroke="#B5703A" strokeWidth="2.5"
              strokeLinejoin="round"
              style={{ filter: 'drop-shadow(0 2px 6px rgba(181,112,58,0.18))' }}/>

            {/* edge midpoint + buttons (insert vertex) */}
            {midpoints.map((m, i) => (
              <g key={`m${i}`} transform={`translate(${m[0]} ${m[1]})`} opacity="0.7">
                <circle r="7" fill="#FAF8F4" stroke="#B5703A" strokeWidth="1.5"/>
                <line x1="-3" y1="0" x2="3" y2="0" stroke="#B5703A" strokeWidth="1.5"/>
                <line x1="0" y1="-3" x2="0" y2="3" stroke="#B5703A" strokeWidth="1.5"/>
              </g>
            ))}

            {/* vertex handles */}
            {points.map((p, i) => (
              <g key={`v${i}`} transform={`translate(${p[0]} ${p[1]})`}>
                <rect x="-7" y="-7" width="14" height="14" rx="3"
                  fill="#FAF8F4" stroke="#B5703A" strokeWidth="2"/>
                {i === 0 && (
                  <circle r="14" fill="none" stroke="#B5703A" strokeWidth="1.5" strokeDasharray="2 3"/>
                )}
              </g>
            ))}

            {/* selected vertex (3rd one) with pulse */}
            <g transform={`translate(${points[2][0]} ${points[2][1]})`}>
              <circle r="20" fill="rgba(181,112,58,0.15)"/>
              <rect x="-8" y="-8" width="16" height="16" rx="3"
                fill="#B5703A" stroke="#FAF8F4" strokeWidth="2"/>
            </g>

            {/* compounds inside polygon — show as small pins */}
            <g opacity="0.85">
              <StatusPin x={420} y={220} color={STATUS_COLORS.visited}/>
              <StatusPin x={480} y={250} color={STATUS_COLORS.want}/>
              <StatusPin x={440} y={290} color={STATUS_COLORS.excluded}/>
            </g>
          </svg>

          {/* Top banner */}
          <div className="pe-banner">
            <Icon name="pen-tool" size={14} strokeWidth={1.5}/>
            <span>绘制新区域</span>
            <div className="mode-toggle">
              <button className={mode === 'tap' ? 'on' : ''}>点选打点</button>
              <button className={mode === 'pencil' ? 'on' : ''}>Pencil 手绘</button>
            </div>
          </div>

          {/* Vertex callout (selected) */}
          <div style={{
            position: 'absolute', left: '53%', top: '38%',
            background: 'rgba(28,27,25,0.92)', color: '#F2EDDF',
            padding: '6px 10px', borderRadius: 8, fontSize: 11,
            display: 'flex', alignItems: 'center', gap: 6,
            boxShadow: '0 4px 10px rgba(28,27,25,.2)',
            zIndex: 12,
          }}>
            顶点 3 · 39.094, 117.218
            <span style={{ width: 1, height: 12, background: 'rgba(255,255,255,0.2)' }}/>
            <Icon name="trash-2" size={11} strokeWidth={1.8}/>
            删除
          </div>

          {/* Action bar */}
          <div className="pe-action-bar">
            <button><Icon name="undo-2" size={14} strokeWidth={1.5}/>撤销</button>
            <button><Icon name="redo-2" size={14} strokeWidth={1.5}/>重做</button>
            <div className="sep"/>
            <button><Icon name="trash-2" size={14} strokeWidth={1.5}/>清空</button>
            <button><Icon name="link-2" size={14} strokeWidth={1.5}/>闭合</button>
            <div className="sep"/>
            <button className="primary"><Icon name="check" size={14} strokeWidth={2}/>命名并保存</button>
          </div>

          {/* Snap hint chip */}
          <div style={{
            position: 'absolute', left: 16, bottom: 80,
            background: 'rgba(250,248,244,0.96)',
            backdropFilter: 'blur(20px)',
            border: '1px solid var(--border)',
            borderRadius: 10, padding: '8px 12px',
            fontSize: 11, color: 'var(--ink-700)',
            display: 'flex', alignItems: 'center', gap: 8,
            maxWidth: 220, lineHeight: 1.45,
          }}>
            <Icon name="info" size={14} strokeWidth={1.5} style={{ color: 'var(--accent-500)' }}/>
            <span>提示：用 Apple Pencil 沿道路画就行，会自动吸附转折点。</span>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { SeedImportScreen, PolygonEditorScreen });
