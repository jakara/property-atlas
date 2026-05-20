/* Aetheris iOS UI Kit · primitives
   Used by app.jsx — kept small and reusable. */

const { useState, useEffect, useRef } = React;

/* ---------- Icon helper (Lucide) ---------- */
function Icon({ name, size = 18, strokeWidth = 1.5, className = '', style = {} }) {
  const ref = useRef(null);
  useEffect(() => {
    if (ref.current && window.lucide) {
      ref.current.innerHTML = '';
      const el = document.createElement('i');
      el.setAttribute('data-lucide', name);
      ref.current.appendChild(el);
      window.lucide.createIcons({ attrs: { 'stroke-width': strokeWidth }, nameAttr: 'data-lucide', icons: window.lucide.icons });
    }
  }, [name, strokeWidth]);
  return <span ref={ref} className={className} style={{ display: 'inline-flex', width: size, height: size, ...style }} />;
}

/* ---------- Status bar ---------- */
function StatusBar({ time = '上午 9:41' }) {
  return (
    <div className="statusbar">
      <span>{time}</span>
      <span className="right">
        <Icon name="signal" size={14} strokeWidth={2} />
        <Icon name="wifi" size={14} strokeWidth={2} />
        <Icon name="battery-full" size={14} strokeWidth={2} />
      </span>
    </div>
  );
}

/* ---------- Star rating ---------- */
function Stars({ value, max = 5, size = 12 }) {
  return (
    <span className="cc-stars">
      {Array.from({ length: max }, (_, i) => (
        <Icon key={i} name="star" size={size} strokeWidth={1.5} className={i < value ? 'filled' : ''} />
      ))}
    </span>
  );
}
function StarsInput({ value, onChange, max = 5 }) {
  return (
    <span className="stars-input">
      {Array.from({ length: max }, (_, i) => (
        <button key={i} onClick={() => onChange(i + 1)}>
          <Icon name="star" size={22} strokeWidth={1.5} className={i < value ? 'filled' : 'empty'} />
        </button>
      ))}
    </span>
  );
}

/* ---------- Toolbar primitives ---------- */
function TBButton({ icon, children, active, onClick, caret }) {
  return (
    <button className={`tb-button ${active ? 'active' : ''}`} onClick={onClick}>
      {icon && <Icon name={icon} size={16} strokeWidth={1.5} />}
      <span>{children}</span>
      {caret && <span className="caret">▾</span>}
    </button>
  );
}
function TBIconOnly({ icon, onClick, ariaLabel }) {
  return (
    <button className="tb-icon-only" onClick={onClick} aria-label={ariaLabel}>
      <Icon name={icon} size={18} strokeWidth={1.5} />
    </button>
  );
}

/* ---------- Popover primitive ---------- */
function Popover({ children, style }) {
  return <div className="popover" style={style}>{children}</div>;
}
function PoCheckRow({ label, checked, onToggle, swatchColor }) {
  return (
    <div className="po-row" onClick={onToggle}>
      <div className={`po-check ${checked ? 'on' : ''}`}>✓</div>
      <span className="po-label">{label}</span>
      {swatchColor && <span className="po-swatch" style={{ background: swatchColor }} />}
    </div>
  );
}

/* ---------- Tag chip ---------- */
function TagChip({ children, polarity }) {
  const cls = polarity === '+' ? 'pos' : polarity === '-' ? 'neg' : '';
  return <span className={`tag-chip ${cls}`}>{polarity && polarity !== '0' ? <span style={{opacity:0.6}}>{polarity}</span> : null}{children}</span>;
}

/* ---------- iOS switch ---------- */
function Switch({ value, onChange }) {
  return (
    <div className={`ios-switch ${value ? 'on' : ''}`} onClick={(e) => { e.stopPropagation(); onChange(!value); }}>
      <div className="knob" />
    </div>
  );
}

Object.assign(window, { Icon, StatusBar, Stars, StarsInput, TBButton, TBIconOnly, Popover, PoCheckRow, TagChip, Switch });
