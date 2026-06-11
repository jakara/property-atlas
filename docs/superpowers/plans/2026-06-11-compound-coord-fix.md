# Compound Coord Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Backfill 174 compound coordinates in `ZCOMPOUND` via Apple MKLocalSearch, replace the `(39.1, 117.2)` placeholder values with real positions, write through the existing SwiftData store.

**Architecture:** Extend `scripts/geocode_mklocal/` SPM with `--mode compounds`. SPM reads `ZCOMPOUND` rows via the system `sqlite3` C library, queries MKLocalSearch by compound name with whole-Tianjin region, writes `reports/extracted/compounds.geocoded.json`. A new `scripts/apply_compound_coords.py` reads the JSON and issues `UPDATE` statements against the SwiftData store. `Compound` @Model is unchanged.

**Tech Stack:** Swift 5.10 (SPM, macOS 14), MapKit (`MKLocalSearch`), SQLite3 C API, Python 3.11+ stdlib.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `scripts/geocode_mklocal/Sources/GeocodeMK/main.swift` | Modify | Add `--mode` arg parsing, sqlite read, JSON write, compounds branch |
| `scripts/geocode_mklocal/Package.swift` | Modify | Link `sqlite3` system lib |
| `scripts/apply_compound_coords.py` | Create | Read JSON, write `UPDATE` to SwiftData store, pkill guard |
| `scripts/tests/test_apply_compound_coords.py` | Create | Unit tests: Cocoa epoch conversion, JSON row parsing |
| `reports/extracted/compounds.geocoded.json` | Created at runtime | Intermediate artifact (id, lat, lon, source, confidence) |

---

## Task 1: Link sqlite3 in SPM

**Files:**
- Modify: `scripts/geocode_mklocal/Package.swift`

- [ ] **Step 1: Replace Package.swift with sqlite3 link**

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "GeocodeMK",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GeocodeMK",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
    ]
)
```

- [ ] **Step 2: Verify build still works (sanity)**

Run: `cd scripts/geocode_mklocal && swift build`
Expected: `Build complete!` (no errors; existing schools mode still compiles)

- [ ] **Step 3: Commit**

```bash
git add scripts/geocode_mklocal/Package.swift
git commit -m "build(geocode): link sqlite3 in SPM target"
```

---

## Task 2: Add sqlite read + JSON write to GeocodeMK

**Files:**
- Modify: `scripts/geocode_mklocal/Sources/GeocodeMK/main.swift`

- [ ] **Step 1: Add sqlite3 import and store path constant near top of file**

After `import MapKit` (around line 3) add:

```swift
import SQLite3
```

At the top of the file (after imports) add:

```swift
/// SQLITE_TRANSIENT for sqlite3_bind_text
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Default SwiftData store path (Mac Catalyst, debug build).
/// Override with `--store <path>` if needed.
let defaultStorePath = "\(NSHomeDirectory())/Library/Application Support/default.store"

let defaultCompoundsOutput = "../../reports/extracted/compounds.geocoded.json"
```

- [ ] **Step 2: Add `loadCompounds` function**

Insert before `let app = NSApplication.shared` (around line 82):

```swift
struct CompoundRow {
    let pk: Int64
    let name: String
}

func loadCompounds(storePath: String) -> [CompoundRow] {
    var db: OpaquePointer?
    guard sqlite3_open(storePath, &db) == SQLITE_OK, let db else {
        FileHandle.standardError.write("ERROR: cannot open \(storePath)\n".data(using: .utf8)!)
        exit(1)
    }
    defer { sqlite3_close(db) }

    let sql = "SELECT Z_PK, ZNAME FROM ZCOMPOUND WHERE ZDELETED = 0"
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
        FileHandle.standardError.write("ERROR: prepare failed\n".data(using: .utf8)!)
        exit(1)
    }
    defer { sqlite3_finalize(stmt) }

    var rows: [CompoundRow] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
        let pk = sqlite3_column_int64(stmt, 0)
        if let cName = sqlite3_column_text(stmt, 1) {
            let name = String(cString: cName)
            if !name.isEmpty {
                rows.append(CompoundRow(pk: pk, name: name))
            }
        }
    }
    return rows
}

func saveCompoundsJSON(_ results: [[String: Any]], to path: String) {
    let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? JSONSerialization.data(withJSONObject: results, options: opts) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}
```

- [ ] **Step 3: Refactor main entry to dispatch on `--mode`**

Replace the `let app = NSApplication.shared ... app.run()` block (lines 82-85) with:

```swift
// Args: [--mode schools|compounds] [path]
var mode = "schools"
var positional: [String] = []
var i = 1
while i < CommandLine.arguments.count {
    let a = CommandLine.arguments[i]
    if a == "--mode", i + 1 < CommandLine.arguments.count {
        mode = CommandLine.arguments[i + 1]
        i += 2
    } else {
        positional.append(a)
        i += 1
    }
}

switch mode {
case "schools":
    let path = positional.first ?? "../../reports/extracted/schools.json"
    guard let raw = FileManager.default.contents(atPath: path),
          var root = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
          var items = root["items"] as? [[String: Any]]
    else {
        FileHandle.standardError.write("ERROR: cannot read \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    let app = NSApplication.shared
    let delegate = AppDelegate(items: items, root: root, saveFn: { save($0) }, path: path)
    app.delegate = delegate
    app.run()

case "compounds":
    let storePath = positional.first ?? defaultStorePath
    let outPath = positional.count >= 2 ? positional[1] : defaultCompoundsOutput
    let rows = loadCompounds(storePath: storePath)
    print("loaded \(rows.count) compounds from \(storePath)")
    let app = NSApplication.shared
    let delegate = CompoundAppDelegate(rows: rows, outPath: outPath)
    app.delegate = delegate
    app.run()

default:
    FileHandle.standardError.write("ERROR: unknown mode \(mode)\n".data(using: .utf8)!)
    exit(1)
}
```

- [ ] **Step 4: Update `AppDelegate` to accept `saveFn` and `path` parameters**

Replace the existing `AppDelegate` class (lines 87-159) with:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    var items: [[String: Any]]
    var root: [String: Any]
    let saveFn: ([String: Any]) -> Void
    let path: String

    init(items: [[String: Any]], root: [String: Any], saveFn: @escaping ([String: Any]) -> Void, path: String) {
        self.items = items
        self.root = root
        self.saveFn = saveFn
        self.path = path
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            var hit = 0
            var miss = 0
            for i in items.indices {
                var item = items[i]
                let name = (item["name"] as? String) ?? ""
                let district = (item["district"] as? String) ?? ""
                let address = (item["address"] as? String) ?? ""
                let src = item["geocode_source"] as? String
                let conf = item["geocode_confidence"] as? String
                let needsRedo = src == nil || src == "auto-bbox" || conf == "failed"
                if !needsRedo { continue }
                var found: CLLocationCoordinate2D?
                var confidence = "name"
                if address.contains("市"), address.contains("区") {
                    let firstAddr = address.split(separator: "、").first.map(String.init) ?? address
                    let cleaned = firstAddr.split(separator: "(").first.map(String.init) ?? firstAddr
                    found = await search(name: cleaned, district: "_TIANJIN_")
                    if found != nil { confidence = "address" }
                }
                if found == nil {
                    found = await search(name: name, district: district)
                    if found != nil { confidence = "name" }
                }
                if found == nil, !address.isEmpty {
                    let firstAddr = address.split(separator: "、").first.map(String.init) ?? address
                    let cleaned = firstAddr.split(separator: "(").first.map(String.init) ?? firstAddr
                    found = await search(name: "天津市\(district)\(cleaned)", district: district)
                    if found != nil { confidence = "address" }
                }
                if let c = found {
                    item["lat"] = c.latitude
                    item["lon"] = c.longitude
                    item["geocode_source"] = "mklocalsearch"
                    item["geocode_confidence"] = confidence
                    items[i] = item
                    hit += 1
                    if hit % 25 == 0 { print("hit=\(hit) miss=\(miss)") }
                } else {
                    item["geocode_source"] = "mklocalsearch"
                    item["geocode_confidence"] = "failed"
                    items[i] = item
                    miss += 1
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
                if (hit + miss) % 50 == 0 {
                    root["items"] = items
                    saveFn(root)
                    print("snapshot saved at \(hit + miss)")
                }
            }
            root["items"] = items
            saveFn(root)
            print("DONE hit=\(hit) miss=\(miss)")
            NSApp.terminate(nil)
        }
    }
}
```

- [ ] **Step 5: Add `CompoundAppDelegate` class**

Append at the end of the file:

```swift
final class CompoundAppDelegate: NSObject, NSApplicationDelegate {
    let rows: [CompoundRow]
    let outPath: String

    init(rows: [CompoundRow], outPath: String) {
        self.rows = rows
        self.outPath = outPath
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            var results: [[String: Any]] = []
            var hit = 0
            var miss = 0
            for (i, row) in rows.enumerated() {
                // Single pass: name + whole-Tianjin region
                let found = await search(name: row.name, district: "_TIANJIN_")
                var entry: [String: Any] = [
                    "pk": row.pk,
                    "name": row.name
                ]
                if let c = found {
                    entry["lat"] = c.latitude
                    entry["lon"] = c.longitude
                    entry["geocode_source"] = "mklocalsearch"
                    entry["geocode_confidence"] = "name"
                    hit += 1
                } else {
                    entry["geocode_source"] = "mklocalsearch"
                    entry["geocode_confidence"] = "failed"
                    miss += 1
                }
                results.append(entry)
                if (i + 1) % 25 == 0 {
                    saveCompoundsJSON(results, to: outPath)
                    print("progress \(i + 1)/\(rows.count) hit=\(hit) miss=\(miss)")
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            saveCompoundsJSON(results, to: outPath)
            print("DONE hit=\(hit) miss=\(miss) out=\(outPath)")
            NSApp.terminate(nil)
        }
    }
}
```

- [ ] **Step 6: Build to verify no syntax errors**

Run: `cd scripts/geocode_mklocal && swift build`
Expected: `Build complete!` (no errors)

- [ ] **Step 7: Commit**

```bash
git add scripts/geocode_mklocal/Sources/GeocodeMK/main.swift
git commit -m "feat(geocode): add --mode compounds for SwiftData store backfill"
```

---

## Task 3: Create apply_compound_coords.py with pkill guard

**Files:**
- Create: `scripts/apply_compound_coords.py`

- [ ] **Step 1: Write the script**

```python
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
```

- [ ] **Step 2: Make executable**

Run: `chmod +x scripts/apply_compound_coords.py`

- [ ] **Step 3: Commit**

```bash
git add scripts/apply_compound_coords.py
git commit -m "feat(apply): apply_compound_coords.py to write coords back to SwiftData store"
```

---

## Task 4: Unit tests for apply script helpers

**Files:**
- Create: `scripts/tests/test_apply_compound_coords.py`

- [ ] **Step 1: Write tests**

```python
"""Unit tests for apply_compound_coords.py."""
import json
import subprocess
import sys
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import apply_compound_coords as acc  # noqa: E402


def test_cocoa_timestamp_is_positive_and_close_to_now():
    ts = acc.cocoa_timestamp()
    # 2026-06-11 minus 2001-01-01 ≈ 25.5 years ≈ 8.05e8 seconds
    assert 7e8 < ts < 9e8


def test_cocoa_timestamp_matches_known_value():
    # 2001-01-01 00:00:01 UTC → 1.0
    fixed = datetime(2001, 1, 1, 0, 0, 1, tzinfo=timezone.utc)
    expected = (fixed - acc.COCOA_EPOCH).total_seconds()
    assert expected == pytest.approx(1.0, abs=1e-6)


def test_load_rows_parses_array(tmp_path: Path):
    p = tmp_path / "x.json"
    p.write_text(json.dumps([{"pk": 1, "lat": 39.1, "lon": 117.2, "geocode_confidence": "name"}]))
    rows = acc.load_rows(p)
    assert len(rows) == 1
    assert rows[0]["pk"] == 1


def test_load_rows_rejects_object(tmp_path: Path):
    p = tmp_path / "x.json"
    p.write_text(json.dumps({"items": []}))
    with pytest.raises(SystemExit):
        acc.load_rows(p)


def test_ensure_app_closed_exits_when_running(monkeypatch):
    # Simulate pgrep finding PropertyAtlas.app
    monkeypatch.setattr(subprocess, "run",
                        lambda *a, **kw: subprocess.CompletedProcess(args=(), returncode=0, stdout=b"1234\n"))
    with pytest.raises(SystemExit) as exc:
        acc.ensure_app_closed()
    assert exc.value.code == 2
```

- [ ] **Step 2: Run tests**

Run: `python3 -m pytest scripts/tests/test_apply_compound_coords.py -v`
Expected: 5 passed

- [ ] **Step 3: Commit**

```bash
git add scripts/tests/test_apply_compound_coords.py
git commit -m "test(apply): cover cocoa epoch, json loader, pkill guard"
```

---

## Task 5: Pre-flight baseline check

**Files:** none (read-only verification)

- [ ] **Step 1: Confirm 174 placeholder coords exist**

Run:
```bash
sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT COUNT(*) FROM ZCOMPOUND WHERE ZLATITUDE = 39.1 AND ZLONGITUDE = 117.2 AND ZDELETED = 0"
```
Expected: `174`

- [ ] **Step 2: Confirm app is closed**

Run: `pgrep -f PropertyAtlas.app`
Expected: no output (empty)

If output: `pkill -f PropertyAtlas.app` then re-check.

- [ ] **Step 3: Confirm no commit step needed** (no code change in this task)

---

## Task 6: Run GeocodeMK in compounds mode

**Files:** none (generates `reports/extracted/compounds.geocoded.json`)

- [ ] **Step 1: Run SPM**

Run:
```bash
cd scripts/geocode_mklocal && swift run GeocodeMK --mode compounds
```
Expected: `loaded 174 compounds from ...`, then progress lines every 25 rows (`progress 25/174 hit=... miss=...`), ending with `DONE hit=... miss=... out=...`

Time: ~5-10 minutes (174 × 200ms + API latency).

- [ ] **Step 2: Inspect output JSON**

Run:
```bash
python3 -c "import json; d=json.load(open('reports/extracted/compounds.geocoded.json')); print('total:', len(d)); print('failed:', sum(1 for r in d if r['geocode_confidence']=='failed')); print('hit_rate:', sum(1 for r in d if r['geocode_confidence']!='failed')/len(d))"
```
Expected: `total: 174`, `failed: <50` (target <30%), `hit_rate: >0.7`

If hit_rate <0.5: stop. Decide whether to add a B-plan pass (高德 POI) or accept the gap. Document decision in commit message of next task.

- [ ] **Step 3: Verify all coords inside Tianjin bounds**

Run:
```bash
python3 -c "
import json
d = json.load(open('reports/extracted/compounds.geocoded.json'))
bad = [r for r in d if 'lat' in r and not (38.5 <= r['lat'] <= 40.3 and 116.7 <= r['lon'] <= 118.0)]
print('out_of_bounds:', len(bad))
for r in bad[:5]: print(r)
"
```
Expected: `out_of_bounds: 0`

- [ ] **Step 4: Commit generated JSON (optional, kept for traceability)**

```bash
git add reports/extracted/compounds.geocoded.json
git commit -m "data(geocode): compound coords backfill snapshot ($(hit)/174 hit, $(miss) failed)"
```

If hit_rate was low, amend commit message to note B-plan deferral.

---

## Task 7: Apply coords to SwiftData store

**Files:** none (writes to `~/Library/Application Support/default.store`)

- [ ] **Step 1: Confirm app still closed**

Run: `pgrep -f PropertyAtlas.app`
Expected: no output

- [ ] **Step 2: Run apply script**

Run: `python3 scripts/apply_compound_coords.py`
Expected: `loaded 174 rows, skipped <N> failed, applying <M>`, then `updated <M>/<M> rows in <T>s (skipped <N> failed)`

The `updated` count must equal `total` (every actionable row matched a Z_PK).

- [ ] **Step 3: Verify in DB**

Run:
```bash
sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT COUNT(*) FROM ZCOMPOUND WHERE ZLATITUDE = 39.1 AND ZLONGITUDE = 117.2 AND ZDELETED = 0"
```
Expected: `0` (or equal to number of failed rows from Task 6, if any)

Run:
```bash
sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT COUNT(DISTINCT ZLATITUDE) FROM ZCOMPOUND WHERE ZDELETED = 0"
```
Expected: > 100 (was 1 before)

Run:
```bash
sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT Z_PK, ZNAME, ZLATITUDE, ZLONGITUDE FROM ZCOMPOUND
   WHERE ZDELETED = 0 AND (ZLATITUDE NOT BETWEEN 38.5 AND 40.3 OR ZLONGITUDE NOT BETWEEN 116.7 AND 118.0)"
```
Expected: empty

- [ ] **Step 4: Spot-check 5 compounds in DB**

Run:
```bash
sqlite3 ~/Library/Application\ Support/default.store \
  "SELECT ZNAME, ZLATITUDE, ZLONGITUDE FROM ZCOMPOUND WHERE ZDELETED = 0 ORDER BY RANDOM() LIMIT 5"
```
Expected: 5 rows with varied lat/lon (no `(39.1, 117.2)`).

Cross-check 2-3 names in Apple Maps mentally. If any look off (e.g. compound in 河北区 showing in 滨海), note in commit message and consider B-plan follow-up.

- [ ] **Step 5: No commit step** (DB write, not source change). The `compounds.geocoded.json` artifact is already committed in Task 6.

---

## Task 8: Visual confirmation in app

**Files:** none (manual verification)

- [ ] **Step 1: Launch app**

Run: `open PropertyAtlas.xcodeproj` then Cmd+R in Xcode (or `xcodebuild` if pre-built).

- [ ] **Step 2: Open Studio, zoom to 市内六区 / 环城四区**

- [ ] **Step 3: Confirm compound pins spread, not stacked at one point**

Expected: pins distributed across districts matching the actual compound locations.

- [ ] **Step 4: Tap 3 pins, confirm EntityCard shows correct district/area**

If any pin looks wildly misplaced (cross-district, in sea, etc.), document in a follow-up issue / spec. Do NOT re-run the geocoder from this state without first committing the current DB state — see `p5-smoke-remigrate-procedure.md`.

- [ ] **Step 5: Close app, commit any post-flight notes**

If a follow-up spec is needed (B-plan or manual fix list), create it in `docs/superpowers/specs/`. Otherwise, no commit.

---

## Self-Review Notes

- **Spec coverage**: All design sections mapped to tasks (data flow → Tasks 1-7; verification → Tasks 5/7/8; out-of-scope items not in tasks).
- **Placeholder scan**: No "TBD" or "implement later". All code blocks complete.
- **Type consistency**: `CompoundRow(pk: Int64, name: String)` used in both `loadCompounds` and `CompoundAppDelegate`. JSON `pk` field read as `int` by Python (sqlite3 rowcount needs `int`, not `str`).
- **Cocoa epoch**: Tested in Task 4; formula documented inline.
- **Failure paths**: SPM mode dispatch has unknown-mode branch. apply script has missing-json / missing-store / app-running branches.
- **Concurrency**: pkill guard in apply script; documented at top of Task 7.
