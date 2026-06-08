#!/usr/bin/env python3
"""Fetch named-road polylines from OpenStreetMap Overpass → GCJ-02 LineStrings.

Used by the project skill `fetch-road-lines`. Keyless. Output schema matches the
app's seed loader (SeedImporter.parseRoadLines):

    {"items":[{"name","ring":<str|null>,"radial":<bool>,
               "geometry":{"type":"LineString","coordinates":[[lng,lat],...]}}]}

Coordinates are GCJ-02 (OSM is WGS-84 → converted here; the app/basemap is GCJ-02).
Roads in OSM are split into directional segments (e.g. 中环东路/南路/西路), so each
target road matches by NAME REGEX and the segments are greedily stitched into one
LineString. Edit ROADS below to add/adjust roads, then re-run.

    python3 scripts/fetch_road_lines.py
"""
import json
import math
import os
import time
import urllib.parse
import urllib.request

OVERPASS = "https://overpass-api.de/api/interpreter"
UA = "PropertyAtlas/1.0 (offline map road research)"
BBOX = (38.85, 116.90, 39.40, 117.60)  # S, W, N, E — Tianjin urban area
SLEEP = 6  # polite gap between Overpass calls (public endpoint is rate-limited)

OUT_PATHS = [
    "PropertyAtlas/PropertyAtlas/Resources/Seeds/road_lines.json",
    "reports/extracted/road_lines.json",
]

# 天津"三环十四射"。match = OSM name 正则;环路按方向分段,用 .* 收全。
# 十四射名称随版本浮动(见 skill 文档),按实际命中调整。
ROADS = [
    {"name": "内环线", "match": "^内环.*路$", "ring": "内环", "radial": False},
    {"name": "中环线", "match": "^中环.*路$", "ring": "中环", "radial": False},
    {"name": "外环线", "match": "外环线|^外环.*路$", "ring": "外环", "radial": False},
    {"name": "西青道", "match": "^西青道$", "ring": None, "radial": True},
    {"name": "复康路", "match": "^复康路$", "ring": None, "radial": True},
    {"name": "卫津路", "match": "^卫津(南)?路$", "ring": None, "radial": True},
    {"name": "友谊路", "match": "^友谊(南)?路$", "ring": None, "radial": True},
    {"name": "大沽路", "match": "^大沽(南)?路$", "ring": None, "radial": True},
    {"name": "津滨大道", "match": "^津滨大道$", "ring": None, "radial": True},
    {"name": "卫国道", "match": "^卫国道$", "ring": None, "radial": True},
    {"name": "新开路", "match": "^新开路$", "ring": None, "radial": True},
    {"name": "中山北路", "match": "^中山北路$", "ring": None, "radial": True},
    {"name": "解放路", "match": "^解放(南|北)?路$", "ring": None, "radial": True},
    {"name": "金钟路", "match": "^金钟河大街$|^金钟路$", "ring": None, "radial": True},
    {"name": "津塘公路", "match": "^津塘公路$", "ring": None, "radial": True},
    {"name": "新宜白大道", "match": "^新宜白大道$", "ring": None, "radial": True},
]

# ---- WGS-84 → GCJ-02 (standard China offset, "eviltransform" formula) ----
_A = 6378245.0
_EE = 0.00669342162296594323


def _out_of_china(lng, lat):
    return not (73.66 < lng < 135.05 and 3.86 < lat < 53.55)


def _t_lat(x, y):
    ret = -100 + 2 * x + 3 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(abs(x))
    ret += (20 * math.sin(6 * x * math.pi) + 20 * math.sin(2 * x * math.pi)) * 2 / 3
    ret += (20 * math.sin(y * math.pi) + 40 * math.sin(y / 3 * math.pi)) * 2 / 3
    ret += (160 * math.sin(y / 12 * math.pi) + 320 * math.sin(y * math.pi / 30)) * 2 / 3
    return ret


def _t_lng(x, y):
    ret = 300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(abs(x))
    ret += (20 * math.sin(6 * x * math.pi) + 20 * math.sin(2 * x * math.pi)) * 2 / 3
    ret += (20 * math.sin(x * math.pi) + 40 * math.sin(x / 3 * math.pi)) * 2 / 3
    ret += (150 * math.sin(x / 12 * math.pi) + 300 * math.sin(x / 30 * math.pi)) * 2 / 3
    return ret


def wgs2gcj(lng, lat):
    if _out_of_china(lng, lat):
        return lng, lat
    dlat = _t_lat(lng - 105, lat - 35)
    dlng = _t_lng(lng - 105, lat - 35)
    radlat = lat / 180 * math.pi
    magic = math.sin(radlat)
    magic = 1 - _EE * magic * magic
    sqrtmagic = math.sqrt(magic)
    dlat = (dlat * 180) / ((_A * (1 - _EE)) / (magic * sqrtmagic) * math.pi)
    dlng = (dlng * 180) / (_A / sqrtmagic * math.cos(radlat) * math.pi)
    return lng + dlng, lat + dlat


# ---- Overpass ----
def query(regex):
    q = (
        f'[out:json][timeout:60];'
        f'way["highway"]["name"~"{regex}"]'
        f'({BBOX[0]},{BBOX[1]},{BBOX[2]},{BBOX[3]});out geom;'
    )
    data = urllib.parse.urlencode({"data": q}).encode()
    req = urllib.request.Request(OVERPASS, data=data, headers={"User-Agent": UA})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001 — rate-limit / timeout → backoff
            wait = 12 * (attempt + 1)
            print(f"    retry {attempt + 1}/5 after {wait}s ({e})")
            time.sleep(wait)
    return {"elements": []}


def ways_geometry(resp):
    """Each way → list[(lng,lat)] (WGS-84)."""
    out = []
    for el in resp.get("elements", []):
        geom = el.get("geometry") or []
        pts = [(g["lon"], g["lat"]) for g in geom]
        if len(pts) >= 2:
            out.append(pts)
    return out


def _dist2(a, b):
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2


def stitch(segments):
    """Greedy nearest-endpoint stitch of segments → one chain (WGS-84)."""
    if not segments:
        return []
    segs = [list(s) for s in segments]
    chain = segs.pop(0)
    while segs:
        head, tail = chain[0], chain[-1]
        best_i, best_rev, best_at_tail, best_d = None, False, True, None
        for i, s in enumerate(segs):
            for at_tail, anchor in ((True, tail), (False, head)):
                d_start = _dist2(anchor, s[0])
                d_end = _dist2(anchor, s[-1])
                d, rev = (d_start, False) if d_start <= d_end else (d_end, True)
                if best_d is None or d < best_d:
                    best_d, best_i, best_rev, best_at_tail = d, i, rev, at_tail
        s = segs.pop(best_i)
        if best_rev:
            s = list(reversed(s))
        if best_at_tail:
            chain += s
        else:
            chain = s + chain
    return chain


def main():
    items = []
    report = []
    for road in ROADS:
        resp = query(road["match"])
        segs = ways_geometry(resp)
        chain = stitch(segs)
        if len(chain) >= 2:
            coords = [list(wgs2gcj(lng, lat)) for lng, lat in chain]
            items.append({
                "name": road["name"],
                "ring": road["ring"],
                "radial": road["radial"],
                "geometry": {"type": "LineString", "coordinates": coords},
            })
            report.append(f"  OK  {road['name']}: {len(segs)} segs → {len(coords)} pts")
        else:
            report.append(f"  --  {road['name']}: no geometry (match='{road['match']}')")
        time.sleep(SLEEP)

    payload = {"items": items}
    blob = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    for p in OUT_PATHS:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as f:
            f.write(blob)

    print("\n".join(report))
    print(f"\n{len(items)}/{len(ROADS)} roads with geometry → {OUT_PATHS[0]}")
    if items:
        s = items[0]["geometry"]["coordinates"][0]
        print(f"sample ({items[0]['name']}): {s}  (expect ~117.x, ~39.x)")


if __name__ == "__main__":
    main()
