#!/usr/bin/env python3
"""Auto-geocode 822 schools using Nominatim district bboxes + deterministic spread.

Apple CLGeocoder doesn't work from headless CLI; OSM Nominatim has no street-level
data for Tianjin. So we approximate:
  1. Fetch each district bbox once (Nominatim, cached locally)
  2. Per zone: derive a deterministic centroid inside its district's bbox
  3. Per school: jitter around its zone centroid (small spread)

Result: schools appear roughly where their district is, with same-zone schools
clustered. Hulls computed from these are district-rough, not block-accurate.
Marked `geocode_confidence=approximate`, `geocode_source=auto-bbox`.

Usage: python3 scripts/auto_geocode.py
"""
import hashlib
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXT = ROOT / "reports" / "extracted"
SCHOOLS_PATH = EXT / "schools.json"
BBOX_CACHE = EXT / "district_bboxes.json"

NOMINATIM = "https://nominatim.openstreetmap.org/search"
UA = "PropertyAtlas/1.0 (https://github.com/local; internal-only)"

# Fallback bboxes if Nominatim fails or doesn't return a district.
# Approximate Tianjin districts via well-known centers; covers 18 districts.
FALLBACK_BBOXES = {
    "和平区":    (39.099, 39.135, 117.173, 117.216),
    "河西区":    (39.069, 39.131, 117.190, 117.265),
    "南开区":    (39.085, 39.155, 117.115, 117.205),
    "河东区":    (39.085, 39.165, 117.215, 117.275),
    "河北区":    (39.135, 39.205, 117.175, 117.245),
    "红桥区":    (39.155, 39.215, 117.135, 117.195),
    "北辰区":    (39.180, 39.310, 117.080, 117.225),
    "西青区":    (38.985, 39.165, 117.000, 117.180),
    "津南区":    (38.890, 39.075, 117.205, 117.430),
    "东丽区":    (39.045, 39.205, 117.265, 117.475),
    "武清区":    (39.305, 39.625, 116.860, 117.150),
    "宝坻区":    (39.555, 39.835, 117.205, 117.605),
    "静海区":    (38.815, 39.105, 116.700, 117.085),
    "宁河区":    (39.235, 39.535, 117.475, 117.985),
    "蓟州区":    (39.815, 40.225, 117.215, 117.755),
    "滨海新区":  (38.850, 39.380, 117.435, 117.985),
    "塘沽区":    (38.985, 39.085, 117.625, 117.775),
    "大港区":    (38.685, 38.835, 117.385, 117.555),
}


def fetch_bbox(district: str) -> tuple[float, float, float, float] | None:
    q = urllib.parse.urlencode(
        {"q": f"天津市{district}", "format": "json", "limit": 1, "accept-language": "zh-CN"}
    )
    url = f"{NOMINATIM}?{q}"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read().decode("utf-8"))
    except Exception as e:
        print(f"  ⚠ nominatim error {district}: {e}", file=sys.stderr)
        return None
    if not data:
        return None
    bb = data[0].get("boundingbox")
    if not bb:
        return None
    return (float(bb[0]), float(bb[1]), float(bb[2]), float(bb[3]))


# Schema constraints: lat ∈ [38.5, 40.3], lon ∈ [116.7, 118.0]
TIANJIN_LAT = (38.5, 40.3)
TIANJIN_LON = (116.7, 118.0)


def bbox_in_tianjin(bb: tuple[float, float, float, float]) -> bool:
    lat_min, lat_max, lon_min, lon_max = bb
    if not (TIANJIN_LAT[0] <= lat_min and lat_max <= TIANJIN_LAT[1]):
        return False
    if not (TIANJIN_LON[0] <= lon_min and lon_max <= TIANJIN_LON[1]):
        return False
    return True


def load_bboxes(districts: list[str]) -> dict[str, tuple[float, float, float, float]]:
    cache = {}
    if BBOX_CACHE.exists():
        cache = json.loads(BBOX_CACHE.read_text())
    out = {}
    for d in districts:
        cached = cache.get(d)
        if cached and bbox_in_tianjin(tuple(cached)):
            out[d] = tuple(cached)
            continue
        bb = fetch_bbox(d) if not cached else None
        if bb and not bbox_in_tianjin(bb):
            print(f"  ↳ {d}: nominatim outside Tianjin {bb} → fallback")
            bb = None
        if bb is None:
            bb = FALLBACK_BBOXES.get(d)
            if bb:
                print(f"  ↳ {d}: using fallback bbox")
        if bb is None:
            print(f"  ✗ {d}: no fallback bbox", file=sys.stderr)
            continue
        out[d] = bb
        cache[d] = list(bb)
        if not cached:
            time.sleep(1.1)
    BBOX_CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2))
    return out


def det_jitter(seed_str: str) -> tuple[float, float]:
    """Return (u, v) in [0, 1) deterministic from seed."""
    h = hashlib.md5(seed_str.encode("utf-8")).digest()
    u = int.from_bytes(h[0:4], "big") / (2**32)
    v = int.from_bytes(h[4:8], "big") / (2**32)
    return u, v


def main() -> int:
    data = json.loads(SCHOOLS_PATH.read_text(encoding="utf-8"))
    items = data["items"]
    districts = sorted({s["district"] for s in items if s.get("district")})
    print(f"Loading bboxes for {len(districts)} districts...")
    bboxes = load_bboxes(districts)
    print(f"  ✓ {len(bboxes)} bboxes resolved")

    # Per-zone centroid: random point inside district bbox.
    zone_centroids: dict[str, tuple[float, float]] = {}
    placed = 0
    skipped = 0
    for s in items:
        if s.get("lat") is not None and s.get("lon") is not None:
            placed += 1
            continue
        district = s.get("district")
        bb = bboxes.get(district)
        if bb is None:
            skipped += 1
            continue
        lat_min, lat_max, lon_min, lon_max = bb
        zone_id = s.get("zone_id") or s["id"]
        if zone_id not in zone_centroids:
            u, v = det_jitter(f"zone:{zone_id}")
            # Sub-bbox: 60% inset to keep zones bunched
            zc_lat = lat_min + 0.2 * (lat_max - lat_min) + u * 0.6 * (lat_max - lat_min)
            zc_lon = lon_min + 0.2 * (lon_max - lon_min) + v * 0.6 * (lon_max - lon_min)
            zone_centroids[zone_id] = (zc_lat, zc_lon)
        zc_lat, zc_lon = zone_centroids[zone_id]
        # School-level jitter: ±0.005° (~500 m) around zone centroid
        u, v = det_jitter(f"sch:{s['id']}")
        s["lat"] = round(zc_lat + (u - 0.5) * 0.01, 6)
        s["lon"] = round(zc_lon + (v - 0.5) * 0.01, 6)
        s["geocode_source"] = "auto-bbox"
        s["geocode_confidence"] = "approximate"
        placed += 1

    data["items"] = items
    SCHOOLS_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"placed: {placed} schools, skipped: {skipped}")
    print(f"unique zones: {len(zone_centroids)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
