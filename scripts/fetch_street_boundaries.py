#!/usr/bin/env python3
"""Fetch Tianjin street/subdistrict (街道/镇/乡) boundaries from DataV.GeoAtlas.

For each of the 16 Tianjin district adcodes, downloads the `_full.json`
FeatureCollection (which contains the district's children, i.e. the
街道/镇/乡 features), flattens them all into one list, and writes a single
bundled JSON file matching the district_boundaries.json schema:

    {"items":[{"adcode":<int>,"name":"<街道名>","geometry":{...}}]}

Coordinates are GCJ-02 (DataV.GeoAtlas native) — the app uses GCJ-02
directly, so NO conversion is performed.

The app's GeoJSONHelper.decodePolygon only reads coordinates[0] (the first
ring of a Polygon), so MultiPolygon geometries are flattened to the
largest-ring Polygon — mirroring district_boundaries.json exactly.

Usage:
    python3 scripts/fetch_street_boundaries.py
"""
import json
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_SEED = ROOT / "PropertyAtlas" / "PropertyAtlas" / "Resources" / "Seeds" / "street_boundaries.json"
OUT_REPORT = ROOT / "reports" / "extracted" / "street_boundaries.json"

URL_TMPL = "https://geo.datav.aliyun.com/areas_v3/bound/{adcode}_full.json"

# 16 Tianjin districts (区县) -> expand into their 街道/镇/乡 children.
DISTRICTS = [
    (120101, "和平区"), (120102, "河东区"), (120103, "河西区"),
    (120104, "南开区"), (120105, "河北区"), (120106, "红桥区"),
    (120110, "东丽区"), (120111, "西青区"), (120112, "津南区"),
    (120113, "北辰区"), (120114, "武清区"), (120115, "宝坻区"),
    (120116, "滨海新区"), (120117, "宁河区"), (120118, "静海区"),
    (120119, "蓟州区"),
]


def fetch(adcode: int):
    url = URL_TMPL.format(adcode=adcode)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def ring_area(ring) -> float:
    """Shoelace absolute area of a single ring [[lng,lat],...]."""
    n = len(ring)
    if n < 3:
        return 0.0
    s = 0.0
    for i in range(n):
        x1, y1 = ring[i][0], ring[i][1]
        x2, y2 = ring[(i + 1) % n][0], ring[(i + 1) % n][1]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2.0


def to_polygon(geometry):
    """Normalize geometry to a single-outer-ring Polygon.

    Polygon -> keep outer ring (coordinates[0]).
    MultiPolygon -> take the polygon whose outer ring has the largest area.
    Returns {"type":"Polygon","coordinates":[[[lng,lat],...]]} or None.
    """
    if not geometry:
        return None
    gtype = geometry.get("type")
    coords = geometry.get("coordinates")
    if not coords:
        return None

    if gtype == "Polygon":
        outer = coords[0]
        if not outer:
            return None
        return {"type": "Polygon", "coordinates": [outer]}

    if gtype == "MultiPolygon":
        best_ring = None
        best_area = -1.0
        for poly in coords:
            if not poly:
                continue
            outer = poly[0]
            a = ring_area(outer)
            if a > best_area:
                best_area = a
                best_ring = outer
        if best_ring:
            return {"type": "Polygon", "coordinates": [best_ring]}
        return None

    return None


def main() -> int:
    items = []
    per_district = {}
    empty_districts = []

    for adcode, dname in DISTRICTS:
        try:
            fc = fetch(adcode)
        except Exception as exc:  # noqa: BLE001
            print(f"[WARN] {adcode} {dname}: fetch failed: {exc}", file=sys.stderr)
            empty_districts.append((adcode, dname, f"fetch error: {exc}"))
            per_district[dname] = 0
            continue

        features = fc.get("features", []) if isinstance(fc, dict) else []
        count = 0
        for feat in features:
            props = feat.get("properties", {}) or {}
            child_adcode = props.get("adcode")
            name = props.get("name")
            # Skip the parent feature itself if present.
            if child_adcode is None or child_adcode == adcode:
                continue
            if not name:
                continue
            poly = to_polygon(feat.get("geometry"))
            if poly is None or not poly["coordinates"] or not poly["coordinates"][0]:
                print(f"[WARN] {child_adcode} {name}: empty/invalid geometry, skipped",
                      file=sys.stderr)
                continue
            items.append({
                "adcode": int(child_adcode),
                "name": name,
                "geometry": poly,
            })
            count += 1

        per_district[dname] = count
        if count == 0:
            empty_districts.append((adcode, dname, "no children returned"))
        # Be polite to the endpoint.
        time.sleep(0.3)

    payload = {"items": items}
    OUT_REPORT.parent.mkdir(parents=True, exist_ok=True)
    OUT_SEED.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    OUT_SEED.write_text(text, encoding="utf-8")
    OUT_REPORT.write_text(text, encoding="utf-8")

    print(f"\nTotal streets: {len(items)}")
    print("Per district:")
    for adcode, dname in DISTRICTS:
        print(f"  {adcode} {dname}: {per_district.get(dname, 0)}")
    if empty_districts:
        print("Districts with no children / errors:")
        for adcode, dname, why in empty_districts:
            print(f"  {adcode} {dname}: {why}")
    if items:
        print("Sample names:", ", ".join(i["name"] for i in items[:3]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
