#!/usr/bin/env python3
"""Fetch named-road polylines from OpenStreetMap Overpass → GCJ-02 LineStrings.

Used by the project skill `fetch-road-lines`. Keyless. Output schema matches the
app's seed loader (SeedImporter.parseRoadLines):

    {"items":[{"name","ring":<str|null>,"radial":<bool>,
               "geometry":{"type":"MultiLineString","coordinates":[[[lng,lat],...],...]}}]}

Coordinates are GCJ-02 (OSM is WGS-84 → converted here; the app/basemap is GCJ-02).
Output is MultiLineString per road (each OSM way = one component, NOT stitched —
stitching joined disjoint ways with straight off-network connectors).
Ring roads come from OSM route=road RELATIONS (full closed ring); radial roads come
from way NAME REGEX. Edit ROADS below to add/adjust roads, then re-run.

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

# 天津"三环十四射"。
#   环路 → OSM **route=road 关系**(`rel` 字段):成员 way 一次收全,闭合无缺口。
#         名称正则收不全(环由不同街名段拼成),且会误命中外区同名局部路。
#         内环线 OSM 无 route=road 关系、way 也不统名 → 暂不抓(见 skill 文档)。
#   放射 → way name 正则(`match` 字段)。十四射名称随版本浮动,按实际命中调整。
ROADS = [
    # 三环(中/外环走关系;内环 OSM 无可靠源,暂缺)
    {"name": "中环线", "rel": 19378071, "ring": "中环", "radial": False},
    {"name": "外环线", "rel": 19379007, "ring": "外环", "radial": False},
    # 十四射(权威名单:reformdata/sohu「三环十四射」放射干线)。OSM 实名有出入,按命中调正则。
    {"name": "丁字沽三号路", "match": "丁字沽三号路|丁字沽三", "ring": None, "radial": True},
    {"name": "京津公路", "match": "^京津公路$", "ring": None, "radial": True},
    {"name": "铁东路", "match": "^铁东路$", "ring": None, "radial": True},
    {"name": "十一经路", "match": "^十一经路$", "ring": None, "radial": True},
    {"name": "新开路", "match": "^新开路$", "ring": None, "radial": True},
    {"name": "中山北路", "match": "^中山北路$", "ring": None, "radial": True},
    {"name": "解放路", "match": "^解放(南|北)?路$", "ring": None, "radial": True},
    {"name": "大沽路", "match": "^大沽(南)?路$", "ring": None, "radial": True},
    {"name": "卫津路", "match": "^卫津(南)?路$", "ring": None, "radial": True},
    {"name": "津淄路", "match": "^津淄路$|津淄", "ring": None, "radial": True},
    {"name": "新宜白大道", "match": "^新宜白大道$|宜白", "ring": None, "radial": True},
    {"name": "金钟路", "match": "^金钟河大街$|^金钟路$", "ring": None, "radial": True},
    {"name": "卫国道", "match": "^卫国道$", "ring": None, "radial": True},
    {"name": "津塘路", "match": "^津塘路$", "ring": None, "radial": True},
    {"name": "复康路", "match": "^复康路$", "ring": None, "radial": True},
    {"name": "西青道", "match": "^西青道$", "ring": None, "radial": True},
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
def _fetch(overpass_ql):
    data = urllib.parse.urlencode({"data": overpass_ql}).encode()
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


def query(regex):
    """Radial roads: ways matching a name regex within the urban bbox."""
    return _fetch(
        f'[out:json][timeout:60];'
        f'way["highway"]["name"~"{regex}"]'
        f'({BBOX[0]},{BBOX[1]},{BBOX[2]},{BBOX[3]});out geom;'
    )


def query_relation(rel_id):
    """Ring roads: all member ways of an OSM route=road relation (full closed ring)."""
    return _fetch(f'[out:json][timeout:90];rel({rel_id});way(r);out geom;')


def ways_geometry(resp):
    """Each way → list[(lng,lat)] (WGS-84)."""
    out = []
    for el in resp.get("elements", []):
        geom = el.get("geometry") or []
        pts = [(g["lon"], g["lat"]) for g in geom]
        if len(pts) >= 2:
            out.append(pts)
    return out


def main():
    items = []
    report = []
    for road in ROADS:
        if "rel" in road:
            resp = query_relation(road["rel"])
        else:
            resp = query(road["match"])
        segs = ways_geometry(resp)
        # 不缝合:每个 OSM way 各自成一条线 → MultiLineString。缝合会用直线把不相邻
        # 的段强连,产生横穿街区的假连线(实测错误)。way 本身已是连续折线。
        lines = [[list(wgs2gcj(lng, lat)) for lng, lat in s] for s in segs if len(s) >= 2]
        if lines:
            pts = sum(len(line) for line in lines)
            items.append({
                "name": road["name"],
                "ring": road["ring"],
                "radial": road["radial"],
                "geometry": {"type": "MultiLineString", "coordinates": lines},
            })
            report.append(f"  OK  {road['name']}: {len(lines)} ways, {pts} pts")
        else:
            src = f"rel={road['rel']}" if "rel" in road else f"match='{road['match']}'"
            report.append(f"  --  {road['name']}: no geometry ({src})")
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
        s = items[0]["geometry"]["coordinates"][0][0]
        print(f"sample ({items[0]['name']}): {s}  (expect ~117.x, ~39.x)")


if __name__ == "__main__":
    main()
