/* Aetheris iOS Kit · MapCanvas
   Stylized map showing school zone polygons + compound pins.
   Designed to evoke Tianjin's central districts without claiming geographic accuracy. */

const TIER_COLORS = {
  top:  { stroke: '#C99B2C', fill: 'rgba(201,155,44,0.18)' },
  good: { stroke: '#5B7C9C', fill: 'rgba(91,124,156,0.18)' },
  reg:  { stroke: '#9C968B', fill: 'rgba(156,150,139,0.18)' },
  weak: { stroke: '#B8736B', fill: 'rgba(184,115,107,0.18)' },
};

const STATUS_COLORS = {
  unvisited: '#9C968B',  // gray — 未看
  want:      '#5B7C9C',  // blue — 想看
  visited:   '#7A9A7E',  // green — 看过
  excluded:  '#A85040',  // red — 排除
};

/* ---------- Status pin SVG ---------- */
function StatusPin({ color, x, y, label, selected, onClick }) {
  return (
    <g transform={`translate(${x} ${y})`} style={{ cursor: 'pointer' }} onClick={onClick}>
      {selected && <circle cx="0" cy="-12" r="18" fill={color} opacity="0.18" />}
      <path d="M 0 -22 C -8 -22, -12 -16, -12 -10 C -12 -2, 0 6, 0 6 C 0 6, 12 -2, 12 -10 C 12 -16, 8 -22, 0 -22 Z"
        fill={color} stroke="#FAF8F4" strokeWidth="1.5" />
      <circle cx="0" cy="-12" r="3.5" fill="#FAF8F4" />
      {label && (
        <text x="14" y="-8" fontSize="9" fill="#3E3A35" fontFamily="-apple-system, sans-serif" fontWeight="500">{label}</text>
      )}
    </g>
  );
}

function MapCanvas({ layers, tierFilter, compounds, selectedId, onSelect }) {
  // Stylized "blocks" path data and zone polygons baked in.
  return (
    <svg className="map-svg" viewBox="0 0 800 560" preserveAspectRatio="xMidYMid slice">
      <defs>
        <pattern id="block-pattern" x="0" y="0" width="14" height="14" patternUnits="userSpaceOnUse">
          <rect width="14" height="14" fill="transparent"/>
        </pattern>
      </defs>

      {/* Subtle city block grid */}
      <g opacity="0.55">
        {Array.from({ length: 28 }, (_, i) => (
          <line key={`h${i}`} x1="0" y1={i * 20} x2="800" y2={i * 20} stroke="#D8CFBE" strokeWidth="0.5" />
        ))}
        {Array.from({ length: 40 }, (_, i) => (
          <line key={`v${i}`} x1={i * 20} y1="0" x2={i * 20} y2="560" stroke="#D8CFBE" strokeWidth="0.5" />
        ))}
      </g>

      {/* River — Hai He suggestion */}
      <path d="M -20 80 Q 180 140 260 200 T 480 320 Q 600 380 820 360"
        fill="none" stroke="#B9CBD0" strokeWidth="22" opacity="0.55" strokeLinecap="round"/>
      <path d="M -20 80 Q 180 140 260 200 T 480 320 Q 600 380 820 360"
        fill="none" stroke="#A4BAC2" strokeWidth="1" opacity="0.5" strokeDasharray="2 3"/>

      {/* Major roads */}
      <g stroke="#C9C0AD" strokeLinecap="round" opacity="0.9">
        <line x1="60" y1="0" x2="180" y2="560" strokeWidth="4"/>
        <line x1="320" y1="0" x2="380" y2="560" strokeWidth="4"/>
        <line x1="560" y1="0" x2="620" y2="560" strokeWidth="3"/>
        <line x1="0" y1="260" x2="800" y2="240" strokeWidth="4"/>
        <line x1="0" y1="440" x2="800" y2="420" strokeWidth="3"/>
      </g>

      {/* Minor streets */}
      <g stroke="#D8CFBE" strokeWidth="1.5" opacity="0.7" strokeLinecap="round">
        <line x1="0" y1="120" x2="800" y2="110"/>
        <line x1="0" y1="180" x2="800" y2="170"/>
        <line x1="0" y1="340" x2="800" y2="320"/>
        <line x1="0" y1="500" x2="800" y2="490"/>
        <line x1="140" y1="0" x2="180" y2="560"/>
        <line x1="240" y1="0" x2="280" y2="560"/>
        <line x1="440" y1="0" x2="480" y2="560"/>
        <line x1="700" y1="0" x2="740" y2="560"/>
      </g>

      {/* School zone polygons */}
      {layers.zones && tierFilter.top && (
        <g>
          <polygon points="120,80 260,60 320,150 240,220 140,200 110,140"
            fill={TIER_COLORS.top.fill} stroke={TIER_COLORS.top.stroke} strokeWidth="1.5" strokeDasharray="0"/>
          <text x="200" y="135" fontSize="11" fill="#8A6818" fontFamily="-apple-system" fontWeight="500" textAnchor="middle">和平第一学区 · 顶尖</text>
        </g>
      )}
      {layers.zones && tierFilter.good && (
        <g>
          <polygon points="360,180 510,160 570,260 480,330 380,310 340,240"
            fill={TIER_COLORS.good.fill} stroke={TIER_COLORS.good.stroke} strokeWidth="1.5"/>
          <text x="450" y="245" fontSize="11" fill="#3E5468" fontFamily="-apple-system" fontWeight="500" textAnchor="middle">南开二片 · 优质</text>
        </g>
      )}
      {layers.zones && tierFilter.reg && (
        <g>
          <polygon points="600,80 740,100 760,200 700,260 620,240 580,160"
            fill={TIER_COLORS.reg.fill} stroke={TIER_COLORS.reg.stroke} strokeWidth="1.5"/>
          <text x="680" y="170" fontSize="11" fill="#6B6660" fontFamily="-apple-system" fontWeight="500" textAnchor="middle">河西二片 · 普通</text>
        </g>
      )}
      {layers.zones && tierFilter.weak && (
        <g>
          <polygon points="180,360 320,360 360,460 280,520 180,500 140,420"
            fill={TIER_COLORS.weak.fill} stroke={TIER_COLORS.weak.stroke} strokeWidth="1.5"/>
          <text x="240" y="435" fontSize="11" fill="#7E4D45" fontFamily="-apple-system" fontWeight="500" textAnchor="middle">河北二片 · 薄弱</text>
        </g>
      )}

      {/* User-drawn area */}
      {layers.userAreas && (
        <g>
          <polygon points="500,360 620,340 660,440 580,490 500,470 480,400"
            fill="rgba(181,112,58,0.10)" stroke="#B5703A" strokeWidth="1.5" strokeDasharray="6 4"/>
          <text x="570" y="420" fontSize="11" fill="#7A4822" fontFamily="-apple-system" fontWeight="500" textAnchor="middle">通勤可达圈</text>
        </g>
      )}

      {/* Compound pins */}
      {compounds.map(c => (
        <StatusPin
          key={c.id}
          x={c.x} y={c.y}
          color={STATUS_COLORS[c.status]}
          label={c.shortName}
          selected={selectedId === c.id}
          onClick={() => onSelect(c.id)}
        />
      ))}
    </svg>
  );
}

Object.assign(window, { MapCanvas, STATUS_COLORS, TIER_COLORS, StatusPin });
