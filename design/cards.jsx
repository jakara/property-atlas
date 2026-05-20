/* Aetheris iOS Kit · drawer cards
   CompoundCard (visit log), SchoolCard, ZoneCard. */

function CompoundCard({ compound, selected, onClick }) {
  const statusColor = STATUS_COLORS[compound.status];
  return (
    <div className={`compound-card ${selected ? 'selected' : ''}`} onClick={onClick}>
      <div className="cc-head">
        <div className="cc-pin" style={{ background: statusColor }}>
          <Icon name="map-pin" size={14} strokeWidth={2.5} />
        </div>
        <div className="cc-title-row">
          <div className="cc-title">{compound.name}</div>
          <div className="cc-sub">{compound.district} · {compound.zone} · {compound.buildYear}</div>
        </div>
        {compound.priceWan && (
          <div className="cc-price">{compound.priceWan}<span style={{ color: 'var(--ink-500)', fontWeight: 400, fontSize: 11, marginLeft: 2 }}>万</span></div>
        )}
      </div>
      {compound.rating && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Stars value={compound.rating} />
          <span style={{ fontSize: 11, color: 'var(--ink-500)' }}>{compound.visitDate}</span>
        </div>
      )}
      {compound.meta && (
        <div className="cc-meta-row">
          {compound.meta.map((m, i) => (
            <span key={i} className="item">
              {m.icon && <Icon name={m.icon} size={12} strokeWidth={1.5} />}
              {m.text}
            </span>
          ))}
        </div>
      )}
      {compound.tags && compound.tags.length > 0 && (
        <div className="cc-tags">
          {compound.tags.map((t, i) => <TagChip key={i} polarity={t.p}>{t.label}</TagChip>)}
        </div>
      )}
      {compound.thumbs && compound.thumbs.length > 0 && (
        <div className="cc-thumbs">
          {compound.thumbs.slice(0, 3).map((t, i) => (
            <div key={i} className="cc-thumb"><Icon name={t} size={16} strokeWidth={1.25} /></div>
          ))}
          {compound.thumbs.length > 3 && (
            <div className="cc-thumb more">+{compound.thumbs.length - 3}</div>
          )}
        </div>
      )}
    </div>
  );
}

function SchoolCard({ school, onClick }) {
  const tierClass = { 顶尖: 'tier-top', 优质: 'tier-good', 普通: 'tier-reg', 薄弱: 'tier-weak' }[school.tier];
  return (
    <div className="school-card" onClick={onClick}>
      <div className="school-head">
        <div className="sh-icon"><Icon name={school.type === '小学' ? 'book-open' : 'graduation-cap'} size={18} strokeWidth={1.5} /></div>
        <div className="sh-body">
          <div className="sh-name">{school.name}</div>
          <div className="sh-sub">{school.district} · {school.type} · {school.zone}</div>
        </div>
        <span className={`tier-badge ${tierClass}`}>{school.tier}</span>
      </div>
      <div className="school-meta">
        {school.rank && <span className="item">中考排名<strong>{school.rank}</strong></span>}
        {school.top10 && <span className="item">前10%率<strong>{school.top10}</strong></span>}
        {school.compounds != null && <span className="item">关联小区<strong>{school.compounds}</strong></span>}
      </div>
    </div>
  );
}

function ZoneCard({ zone, onToggleVisible }) {
  return (
    <div className="zone-card">
      <div className="zone-swatch" style={{ background: zone.fillColor || `${zone.strokeColor}26`, borderColor: zone.strokeColor }} />
      <div className="zone-body">
        <div className="zone-name">{zone.name}</div>
        <div className="zone-sub">{zone.kind} · {zone.area}</div>
      </div>
      <span className="zone-eye" onClick={onToggleVisible}>
        <Icon name={zone.visible ? 'eye' : 'eye-off'} size={18} strokeWidth={1.5} />
      </span>
    </div>
  );
}

Object.assign(window, { CompoundCard, SchoolCard, ZoneCard });
