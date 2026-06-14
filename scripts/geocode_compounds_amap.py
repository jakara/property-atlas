#!/usr/bin/env python3
"""Re-geocode failed compounds via 高德 web service (v3/place/text).

Reads reports/extracted/compounds.geocoded.json, retries rows with
geocode_confidence == "failed" using 高德 place text search. Updates the
same file.

高德 web key: 从 env AMAP_WEB_KEY 读. 失败退码 1.
87 个 failed 跑完 ~10s (0.1s throttle).
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "reports" / "extracted" / "compounds.geocoded.json"
AMAP = "https://restapi.amap.com/v3/place/text"
TIANJIN_LAT = (38.5, 40.3)
TIANJIN_LON = (116.7, 118.0)
THROTTLE_S = 0.1
CITY = "天津"
OFFSET = 1


def in_tianjin(lat: float, lon: float) -> bool:
    return TIANJIN_LAT[0] <= lat <= TIANJIN_LAT[1] and TIANJIN_LON[0] <= lon <= TIANJIN_LON[1]


def search(name: str, key: str) -> tuple[float, float] | None:
    q = urllib.parse.urlencode({
        "key": key,
        "keywords": name,
        "city": CITY,
        "citylimit": "true",
        "offset": str(OFFSET),
        "extensions": "base",
        "output": "json",
    })
    url = f"{AMAP}?{q}"
    req = urllib.request.Request(url)
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
        elapsed = time.time() - t0
        status = data.get("status")
        info = data.get("info")
        infocode = data.get("infocode")
        pois = data.get("pois") or []
        print(f"    HTTP {elapsed:.2f}s status={status} info={info} code={infocode} pois={len(pois)}", flush=True)
    except Exception as e:
        elapsed = time.time() - t0
        print(f"    HTTP {elapsed:.2f}s ERROR {type(e).__name__}: {e}", file=sys.stderr, flush=True)
        return None
    if status != "1" or not pois:
        return None
    p0 = pois[0]
    loc = p0.get("location")
    if not loc:
        return None
    try:
        lon_s, lat_s = loc.split(",")
        lat, lon = float(lat_s), float(lon_s)
    except (ValueError, AttributeError):
        return None
    if not in_tianjin(lat, lon):
        print(f"    out_of_bounds: {lat},{lon} name={p0.get('name')!r}", file=sys.stderr, flush=True)
        return None
    return (lat, lon)


def main() -> None:
    key = os.environ.get("AMAP_WEB_KEY")
    if not key:
        print("ERROR: AMAP_WEB_KEY env var not set", file=sys.stderr, flush=True)
        sys.exit(1)

    print(f"START amap_retry pid={os.getpid()} key={key[:6]}...{key[-4:]}", flush=True)
    rows = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    failed = [i for i, r in enumerate(rows) if r.get("geocode_confidence") == "failed"]
    print(f"loaded {len(rows)} rows, retrying {len(failed)} failed via 高德", flush=True)

    hit = 0
    miss = 0
    for n, i in enumerate(failed, 1):
        row = rows[i]
        name = row["name"]
        print(f"[{n}/{len(failed)}] {name}", flush=True)
        result = search(name, key)
        row["geocode_source"] = "amap"
        if result is not None:
            lat, lon = result
            row["lat"] = lat
            row["lon"] = lon
            row["geocode_confidence"] = "name"
            hit += 1
            print(f"  HIT  {lat:.5f} {lon:.5f}", flush=True)
        else:
            row["geocode_confidence"] = "failed"
            miss += 1
            print(f"  MISS", flush=True)
        if n % 10 == 0:
            print(f"--- checkpoint n={n} hit={hit} miss={miss} ---", flush=True)
            JSON_PATH.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"    wrote {JSON_PATH}", flush=True)
        time.sleep(THROTTLE_S)

    JSON_PATH.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"DONE hit={hit} miss={miss} out={JSON_PATH}", flush=True)


if __name__ == "__main__":
    main()
