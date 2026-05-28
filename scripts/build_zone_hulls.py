#!/usr/bin/env python3
"""Compute convex/alpha hull for each zone from its schools' lat/lon.

Usage:
    python3 scripts/build_zone_hulls.py
    python3 scripts/build_zone_hulls.py --schools path --zones path --alpha 0.5
"""
import argparse
import json
import sys
from pathlib import Path

try:
    from shapely.geometry import MultiPoint, Polygon
except ImportError:
    print("Install shapely: pip install shapely alphashape", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SCHOOLS = ROOT / "reports" / "extracted" / "schools.json"
DEFAULT_ZONES = ROOT / "reports" / "extracted" / "zones.json"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--schools", default=str(DEFAULT_SCHOOLS))
    ap.add_argument("--zones", default=str(DEFAULT_ZONES))
    ap.add_argument(
        "--alpha",
        type=float,
        default=0.0,
        help="0=convex hull; >0 tries alphashape (more concave)",
    )
    args = ap.parse_args()

    schools_path = Path(args.schools)
    zones_path = Path(args.zones)
    schools = json.loads(schools_path.read_text(encoding="utf-8"))
    zones = json.loads(zones_path.read_text(encoding="utf-8"))

    by_zone: dict[str, list[tuple[float, float]]] = {}
    for s in schools["items"]:
        zid = s.get("zone_id")
        if not zid or s.get("lat") is None or s.get("lon") is None:
            continue
        by_zone.setdefault(zid, []).append((s["lon"], s["lat"]))

    upgraded = 0
    skipped = 0
    preserved_raster = 0
    for z in zones["items"]:
        # Preserve existing raster geometry (don't overwrite Stage A with Stage B)
        if z.get("geometry_stage") == "raster":
            preserved_raster += 1
            continue
        pts = by_zone.get(z["id"], [])
        if len(pts) < 3:
            skipped += 1
            continue
        hull = compute_hull(pts, alpha=args.alpha)
        if hull is None or hull.area == 0:
            skipped += 1
            continue
        coords = list(hull.exterior.coords)
        z["geometry_stage"] = "hull"
        z["geometry"] = {
            "type": "Polygon",
            "coordinates": [[[x, y] for x, y in coords]],
        }
        upgraded += 1

    zones_path.write_text(
        json.dumps(zones, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(
        f"hulls: {upgraded} upgraded, {skipped} skipped (insufficient pts), {preserved_raster} kept as raster"
    )
    return 0


def compute_hull(pts, alpha: float):
    if alpha > 0:
        try:
            import alphashape

            shape = alphashape.alphashape(pts, alpha)
            if isinstance(shape, Polygon) and shape.area > 0:
                return shape
        except Exception:
            pass
    return MultiPoint(pts).convex_hull if len(pts) >= 3 else None


if __name__ == "__main__":
    sys.exit(main())
