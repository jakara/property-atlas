#!/usr/bin/env python3
"""Fetch administrative-district boundary polygons from DataV.GeoAtlas.

Used by the project skill `fetch-district-boundaries`. Keyless. DataV.GeoAtlas data
is already GCJ-02 (verified by point-in-polygon test against app data) → no
coordinate conversion. Output schema matches the app's seed loader
(SeedImporter.parseDistrictBoundaries):

    {"items":[{"adcode":<int>,"name":<str>,
               "geometry":{"type":"Polygon","coordinates":[[[lng,lat],...]]}}]}

DataV endpoint: https://geo.datav.aliyun.com/areas_v3/bound/{adcode}_full.json
  - `{adcode}_full.json` returns a FeatureCollection of the area's CHILDREN.
  - So city adcode 120000 → its 16 districts. (DataV stops at district level —
    it does NOT publish 街道/township boundaries; those 404.)

MultiPolygon features are reduced to their largest ring as a Polygon (the app's
GeoJSONHelper.decodePolygon reads coordinates[0] only, matching the existing file).

    python3 scripts/fetch_district_boundaries.py [parent_adcode]   # default 120000 (天津)
"""
import json
import os
import sys
import urllib.request

UA = "PropertyAtlas/1.0 (offline map district research)"
PARENT = sys.argv[1] if len(sys.argv) > 1 else "120000"  # 天津市

OUT_PATHS = [
    "PropertyAtlas/PropertyAtlas/Resources/Seeds/district_boundaries.json",
    "reports/extracted/district_boundaries.json",
]


def fetch(adcode):
    url = f"https://geo.datav.aliyun.com/areas_v3/bound/{adcode}_full.json"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def largest_ring(geometry):
    """Polygon → its outer ring; MultiPolygon → largest polygon's outer ring."""
    gtype = geometry.get("type")
    coords = geometry.get("coordinates") or []
    if gtype == "Polygon":
        return coords[0] if coords else None
    if gtype == "MultiPolygon":
        best = None
        for poly in coords:
            ring = poly[0] if poly else None
            if ring and (best is None or len(ring) > len(best)):
                best = ring
        return best
    return None


def main():
    fc = fetch(PARENT)
    items = []
    report = []
    for feat in fc.get("features", []):
        props = feat.get("properties", {})
        adcode = props.get("adcode")
        name = props.get("name")
        ring = largest_ring(feat.get("geometry") or {})
        if adcode is None or not name or not ring:
            report.append(f"  --  skip {name or adcode}: no ring")
            continue
        items.append({
            "adcode": adcode,
            "name": name,
            "geometry": {"type": "Polygon", "coordinates": [ring]},
        })
        report.append(f"  OK  {name} ({adcode}): {len(ring)} pts")

    blob = json.dumps({"items": items}, ensure_ascii=False, separators=(",", ":"))
    for p in OUT_PATHS:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            f.write(blob)

    print("\n".join(report))
    print(f"\n{len(items)} districts → {OUT_PATHS[0]}")
    if items:
        s = items[0]["geometry"]["coordinates"][0][0]
        print(f"sample ({items[0]['name']}): {s}  (expect ~117.x, ~39.x)")


if __name__ == "__main__":
    main()
