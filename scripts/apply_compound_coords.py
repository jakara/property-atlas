#!/usr/bin/env python3
"""Apply compound coords from compounds.geocoded.json → SwiftData store.

Reads reports/extracted/compounds.geocoded.json (id, lat, lon, geocode_confidence).
Issues UPDATE ZCOMPOUND SET ZLATITUDE, ZLONGITUDE, ZUPDATEDAT WHERE Z_PK=?.
Skips rows with geocode_confidence == "failed".

Usage:
  python3 scripts/apply_compound_coords.py [--json PATH] [--store PATH]

Defaults:
  --json   reports/extracted/compounds.geocoded.json
  --store  ~/Library/Application Support/default.store
"""
import argparse
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_JSON = ROOT / "reports" / "extracted" / "compounds.geocoded.json"
DEFAULT_STORE = Path.home() / "Library" / "Application Support" / "default.store"
# macOS Cocoa reference date: 2001-01-01 00:00:00 UTC
COCOA_EPOCH = datetime(2001, 1, 1, tzinfo=timezone.utc)


def cocoa_timestamp() -> float:
    return (datetime.now(timezone.utc) - COCOA_EPOCH).total_seconds()


def ensure_app_closed() -> None:
    """Refuse to run while PropertyAtlas.app holds the sqlite lock."""
    r = subprocess.run(["pgrep", "-f", "PropertyAtlas.app"], capture_output=True)
    if r.returncode == 0:
        print("ERROR: PropertyAtlas.app is running. pkill first:", file=sys.stderr)
        print("  pkill -f PropertyAtlas.app", file=sys.stderr)
        sys.exit(2)


def load_rows(json_path: Path) -> list[dict]:
    import json
    with json_path.open(encoding="utf-8") as f:
        rows = json.load(f)
    if not isinstance(rows, list):
        print(f"ERROR: {json_path} must be a JSON array", file=sys.stderr)
        sys.exit(1)
    return rows


def apply(json_path: Path, store_path: Path) -> tuple[int, int, int]:
    rows = load_rows(json_path)
    skipped = sum(1 for r in rows if r.get("geocode_confidence") == "failed")
    actionable = [r for r in rows if r.get("geocode_confidence") != "failed"]
    print(f"loaded {len(rows)} rows, skipped {skipped} failed, applying {len(actionable)}")

    if not store_path.exists():
        print(f"ERROR: store not found: {store_path}", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(str(store_path))
    try:
        cur = conn.cursor()
        now = cocoa_timestamp()
        sql = "UPDATE ZCOMPOUND SET ZLATITUDE = ?, ZLONGITUDE = ?, ZUPDATEDAT = ? WHERE Z_PK = ?"
        updated = 0
        for r in actionable:
            pk = r["pk"]
            lat = float(r["lat"])
            lon = float(r["lon"])
            cur.execute(sql, (lat, lon, now, pk))
            updated += cur.rowcount
        conn.commit()
        return updated, len(actionable), skipped
    finally:
        conn.close()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", type=Path, default=DEFAULT_JSON)
    ap.add_argument("--store", type=Path, default=DEFAULT_STORE)
    args = ap.parse_args()

    ensure_app_closed()
    if not args.json.exists():
        print(f"ERROR: {args.json} not found. Run GeocodeMK --mode compounds first.", file=sys.stderr)
        sys.exit(1)

    t0 = time.time()
    updated, total, skipped = apply(args.json, args.store)
    dt = time.time() - t0
    print(f"updated {updated}/{total} rows in {dt:.2f}s (skipped {skipped} failed)")


if __name__ == "__main__":
    main()
