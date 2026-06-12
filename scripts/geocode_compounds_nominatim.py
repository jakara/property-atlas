#!/usr/bin/env python3
"""Re-geocode failed compounds via OSM Nominatim.

Reads reports/extracted/compounds.geocoded.json, retries rows with
geocode_confidence == "failed" using Nominatim POI search. Updates the same file.
"""
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JSON_PATH = ROOT / "reports" / "extracted" / "compounds.geocoded.json"
NOMINATIM = "https://nominatim.openstreetmap.org/search"
UA = "PropertyAtlas/1.0 (https://github.com/local; internal-only)"
TIANJIN_LAT = (38.5, 40.3)
TIANJIN_LON = (116.7, 118.0)
THROTTLE_S = 1.1


def in_tianjin(lat: float, lon: float) -> bool:
    return TIANJIN_LAT[0] <= lat <= TIANJIN_LAT[1] and TIANJIN_LON[0] <= lon <= TIANJIN_LON[1]


def search(name: str) -> tuple[float, float] | None:
    q = urllib.parse.urlencode({
        "q": f"{name} 天津",
        "format": "json",
        "limit": 1,
        "accept-language": "zh-CN"
    })
    url = f"{NOMINATIM}?{q}"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        print(f"  ⚠ error for {name}: {e}", file=sys.stderr)
        return None
    if data and "lat" in data[0] and "lon" in data[0]:
        try:
            lat = float(data[0]["lat"])
            lon = float(data[0]["lon"])
        except (TypeError, ValueError):
            return None
        if in_tianjin(lat, lon):
            return (lat, lon)
    return None


def main() -> None:
    rows = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    failed = [i for i, r in enumerate(rows) if r.get("geocode_confidence") == "failed"]
    print(f"loaded {len(rows)} rows, retrying {len(failed)} failed via Nominatim")

    hit = 0
    miss = 0
    for n, i in enumerate(failed, 1):
        row = rows[i]
        name = row["name"]
        result = search(name)
        row["geocode_source"] = "nominatim"
        if result is not None:
            lat, lon = result
            row["lat"] = lat
            row["lon"] = lon
            row["geocode_confidence"] = "name"
            hit += 1
        else:
            row["geocode_confidence"] = "failed"
            miss += 1
        if n % 10 == 0 or n == len(failed):
            print(f"progress {n}/{len(failed)} hit={hit} miss={miss}")
        time.sleep(THROTTLE_S)

    JSON_PATH.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"DONE hit={hit} miss={miss} out={JSON_PATH}")


if __name__ == "__main__":
    main()
