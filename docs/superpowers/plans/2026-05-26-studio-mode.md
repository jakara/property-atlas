# Studio Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Mac Catalyst Studio Mode to PropertyAtlas — interactive 4K-screenshot generator for Tianjin school-district maps, feeding a WeChat content workflow.

**Architecture:** Single SwiftUI codebase shared with iPad app. `@Observable AppMode` toggles `RootView` between Explore (existing) and Studio (new floating overlay over full-screen MKMapView). School-district polygons rendered in three stages: raster (hand-aligned PNG overlay), convex hull (Shapely-generated GeoJSON), street-level GeoJSON (out of MVP scope).

**Tech Stack:** Swift 5.10 · SwiftUI · SwiftData · MapKit · Mac Catalyst (macOS 14+) · Swift Testing · Python 3 (shapely + alphashape) for hull script · Apple `CLGeocoder` for school address → lat/lon.

**Spec:** `docs/superpowers/specs/2026-05-26-studio-mode-design.md`

---

## Pre-flight: File Structure

| Action | Path | Responsibility |
|---|---|---|
| Create | `PropertyAtlas/AppMode.swift` | `@Observable` global mode toggle |
| Modify | `PropertyAtlas/PropertyAtlasApp.swift` | Inject `AppMode` into environment |
| Modify | `PropertyAtlas/RootView.swift` | Branch on `AppMode` |
| Modify | `PropertyAtlas/Map/MapContainerView.swift` | Replace placeholder with `MKMapView` wrapper |
| Create | `PropertyAtlas/Map/MapKitView.swift` | `UIViewRepresentable` for `MKMapView` |
| Modify | `PropertyAtlas/Models/Public/School.swift` | Add `lat/lon/geocodeSource/geocodeConfidence` |
| Modify | `PropertyAtlas/Models/Public/SchoolZone.swift` | Add `geometryStage` |
| Modify | `reports/extracted/schemas/schools.schema.json` | Add new fields |
| Modify | `reports/extracted/schemas/zones.schema.json` | Add new fields with `oneOf` geometry shape |
| Modify | `scripts/validate.py` | (no change — schema-driven) |
| Create | `scripts/geocode_schools.swift` | CLI: batch geocode 822 schools |
| Create | `scripts/build_zone_hulls.py` | CLI: compute convex/alpha hulls |
| Create | `scripts/calibrate_raster/Package.swift` | Standalone macOS Swift Package |
| Create | `scripts/calibrate_raster/Sources/Calibrator/main.swift` | Calibrator UI |
| Create | `scripts/tests/test_build_zone_hulls.py` | pytest for hull script |
| Create | `PropertyAtlas/Resources/StudioRasters/*.png` | 18 district PNGs (manual asset prep, not code) |
| Create | `PropertyAtlas/Studio/StudioMode.swift` | Studio-only environment + helpers |
| Create | `PropertyAtlas/Studio/StudioOverlay.swift` | Top-level overlay container |
| Create | `PropertyAtlas/Studio/StudioTitleCard.swift` | Editable title/subtitle |
| Create | `PropertyAtlas/Studio/StudioLegend.swift` | 4-tier color legend |
| Create | `PropertyAtlas/Studio/StudioWatermark.swift` | Bottom-right brand watermark |
| Create | `PropertyAtlas/Studio/StudioToolbar.swift` | Center-bottom toolbar |
| Create | `PropertyAtlas/Studio/CameraPresets.swift` | 18 districts + 101 zones presets |
| Create | `PropertyAtlas/Studio/RasterAlignment/CalibratedImageOverlay.swift` | `MKOverlay` subclass |
| Create | `PropertyAtlas/Studio/RasterAlignment/CalibratedImageOverlayRenderer.swift` | `MKOverlayRenderer` subclass |
| Create | `PropertyAtlas/Studio/Layers/ZoneGeometryImporter.swift` | Dispatch raster/hull/geojson |
| Create | `PropertyAtlas/Studio/Layers/ZoneCentroidAnnotation.swift` | Zone-name tag |
| Create | `PropertyAtlas/Studio/Layers/SchoolAnnotation.swift` | `MKAnnotation` + view |
| Create | `PropertyAtlas/Studio/Snapshot/CanvasAspect.swift` | Enum |
| Create | `PropertyAtlas/Studio/Snapshot/SnapshotExporter.swift` | 4K PNG generator |
| Create | `PropertyAtlasTests/Studio/CalibratedImageOverlayTests.swift` | corners→MapRect math |
| Create | `PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift` | stage dispatch parsing |
| Create | `PropertyAtlasTests/Studio/CameraPresetsTests.swift` | bbox-in-Tianjin |
| Create | `PropertyAtlasTests/Studio/SnapshotExporterTests.swift` | aspect→pixel sizing |
| Create | `PropertyAtlasTests/Studio/StudioModeToggleTests.swift` | toggle doesn't reinit container |
| Create | `PropertyAtlasTests/Studio/SchoolModelGeocodeTests.swift` | lat/lon decode |
| Modify | `CLAUDE.md` | Add Studio pipeline + AppMode notes |

---

## Phase 0 — Mac Catalyst target + AppMode scaffold

### Task 1: Add Mac Catalyst destination to Xcode project

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas.xcodeproj/project.pbxproj` (via Xcode, not hand edit)

**Note:** TDD doesn't fit Xcode project mutations. Use manual verification.

- [ ] **Step 1: Open Xcode project**

Run: `open /Users/fujie/projects/天津买房/PropertyAtlas/PropertyAtlas.xcodeproj`

- [ ] **Step 2: Add Mac Catalyst destination**

In Xcode → PropertyAtlas target → General → Supported Destinations → click `+` → choose **Mac (Mac Catalyst)**. Use **Scale Interface to Match iPad**. Set deployment target to macOS 14.0.

- [ ] **Step 3: Verify build succeeds on My Mac (Mac Catalyst) destination**

Run: `xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Verify iPad build still passes**

Run: `xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'generic/platform=iOS' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/PropertyAtlas.xcodeproj
git commit -m "feat(studio): add Mac Catalyst destination (macOS 14+)"
```

---

### Task 2: AppMode `@Observable` + RootView branching

**Files:**
- Create: `PropertyAtlas/AppMode.swift`
- Modify: `PropertyAtlas/PropertyAtlasApp.swift`
- Modify: `PropertyAtlas/RootView.swift`
- Create: `PropertyAtlasTests/Studio/StudioModeToggleTests.swift`

- [ ] **Step 1: Write the failing test**

Create `PropertyAtlasTests/Studio/StudioModeToggleTests.swift`:

```swift
import Testing
@testable import PropertyAtlas

@Suite("AppMode")
struct AppModeTests {
    @Test("default mode is explore")
    func defaultMode() {
        let mode = AppMode()
        #expect(mode.value == .explore)
    }

    @Test("toggle switches between explore and studio")
    func toggle() {
        let mode = AppMode()
        mode.toggle()
        #expect(mode.value == .studio)
        mode.toggle()
        #expect(mode.value == .explore)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild -project PropertyAtlas/PropertyAtlas.xcodeproj -scheme PropertyAtlas -destination 'platform=macOS,variant=Mac Catalyst' test -only-testing:PropertyAtlasTests/AppModeTests`
Expected: build fails with `Cannot find 'AppMode' in scope`.

- [ ] **Step 3: Create `AppMode`**

Create `PropertyAtlas/AppMode.swift`:

```swift
import Foundation

enum AppModeValue: String, Codable, CaseIterable {
    case explore
    case studio
}

@Observable
final class AppMode {
    var value: AppModeValue

    init(_ value: AppModeValue = .explore) {
        self.value = value
    }

    func toggle() {
        value = (value == .explore) ? .studio : .explore
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/AppModeTests`
Expected: tests pass.

- [ ] **Step 5: Inject AppMode + branch RootView**

Modify `PropertyAtlas/PropertyAtlasApp.swift`:

```swift
@main
struct PropertyAtlasApp: App {
    let container: ModelContainer
    @State private var selectionState = MapSelectionState()
    @State private var appMode = AppMode()
    @State private var seedDone = false

    init() {
        do {
            let schema = Schema([
                SchoolZone.self, Compound.self, School.self,
                SchoolScore.self, AdmissionDoc.self, BuiltinTag.self,
                PropertyMark.self, Visit.self, Photo.self,
                TagExtension.self, VisitTag.self, UserArea.self, ShareSubmission.self,
            ])
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.fujie.propertyatlas")
            )
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if seedDone {
                    RootView()
                        .environment(selectionState)
                        .environment(appMode)
                } else {
                    SeedProgressView(onComplete: { seedDone = true })
                }
            }
        }
        .modelContainer(container)
    }
}
```

Modify `PropertyAtlas/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @Environment(MapSelectionState.self) private var selection
    @Environment(AppMode.self) private var appMode

    var body: some View {
        switch appMode.value {
        case .explore: ExploreRootView()
        case .studio:  StudioRootView()
        }
    }
}

struct ExploreRootView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                MapContainerView()
                    .ignoresSafeArea()

                ToolbarView()
                    .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 11, x: 0, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.top, 40)
                    .zIndex(30)

                DrawerContainerView()
                    .frame(width: geo.size.width * 0.382 - 16)
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 108)
                    .padding(.bottom, 16)
                    .padding(.trailing, 16)
                    .zIndex(5)
            }
        }
        .ignoresSafeArea()
    }
}

#if targetEnvironment(macCatalyst)
struct StudioRootView: View {
    var body: some View {
        ZStack {
            MapContainerView().ignoresSafeArea()
            // StudioOverlay added in Task 17
            Text("Studio Mode (UI pending)")
                .foregroundStyle(.secondary)
        }
    }
}
#else
struct StudioRootView: View {
    var body: some View {
        Text("Studio Mode is Mac-only.")
    }
}
#endif

struct ToolbarView: View {
    var body: some View { Color.clear }
}
```

- [ ] **Step 6: Build both targets**

Run: `xcodebuild ... -destination 'platform=macOS,variant=Mac Catalyst' build && xcodebuild ... -destination 'generic/platform=iOS' build`
Expected: both succeed.

- [ ] **Step 7: Commit**

```bash
git add PropertyAtlas/AppMode.swift PropertyAtlas/PropertyAtlasApp.swift PropertyAtlas/RootView.swift PropertyAtlasTests/Studio/StudioModeToggleTests.swift
git commit -m "feat(studio): AppMode toggle + RootView branching"
```

---

## Phase 1 — Data model & schema extensions

### Task 3: Extend schools schema with lat/lon/geocode fields

**Files:**
- Modify: `reports/extracted/schemas/schools.schema.json`
- Modify: `reports/extracted/schemas/_common.schema.json` (add `geocode_confidence` enum)

- [ ] **Step 1: Write failing validation test**

Create a one-off test file: `scripts/tests/test_schema_geocode.py`:

```python
import json, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def test_geocode_fields_accepted():
    sample = {
        "version": 1, "source": "test", "count": 1,
        "items": [{
            "id": "sch_0123456789", "name": "Test", "district": "和平区",
            "level": "primary", "is_private": False, "is_jiunian": False,
            "is_market_key": False, "source": "JM-PDF",
            "lat": 39.13, "lon": 117.20,
            "geocode_source": "CLGeocoder",
            "geocode_confidence": "address"
        }]
    }
    p = Path(tempfile.gettempdir()) / "schools_sample.json"
    p.write_text(json.dumps(sample, ensure_ascii=False))
    # patch validate.py to read this file by env var, or just run inline
    r = subprocess.run([sys.executable, str(ROOT / "scripts" / "validate.py"), "--file", str(p), "--schema", "schools.schema.json"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
```

- [ ] **Step 2: Add CLI flags to validate.py if missing**

Read `scripts/validate.py`. If it doesn't support `--file --schema` (it likely validates fixed paths), add this:

```python
import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--file")
parser.add_argument("--schema")
args, _ = parser.parse_known_args()

if args.file and args.schema:
    schema = json.load(open(SCHEMAS_DIR / args.schema))
    data = json.load(open(args.file))
    jsonschema.validate(data, schema, resolver=...)  # use existing resolver
    sys.exit(0)
# ... fall through to original full-validation path
```

(Adapt to existing structure — preserve all existing behavior.)

- [ ] **Step 3: Run test to see it fail (extra fields rejected)**

Run: `python3 scripts/tests/test_schema_geocode.py` or `pytest scripts/tests/test_schema_geocode.py -v`
Expected: FAIL — schema rejects `lat/lon/geocode_*` (additionalProperties: false).

- [ ] **Step 4: Add fields to schools schema**

Modify `reports/extracted/schemas/schools.schema.json`, in `$defs.School.properties` (alphabetic or after `communities_text`):

```json
"lat":                { "type": ["number", "null"], "minimum": 38.5, "maximum": 40.3 },
"lon":                { "type": ["number", "null"], "minimum": 116.7, "maximum": 118.0 },
"geocode_source":     { "$ref": "_common.schema.json#/$defs/geocode_source" },
"geocode_confidence": { "$ref": "_common.schema.json#/$defs/geocode_confidence" }
```

Modify `reports/extracted/schemas/_common.schema.json` `$defs`:

```json
"geocode_source": {
  "anyOf": [
    { "type": "null" },
    { "type": "string", "enum": ["CLGeocoder", "manual", "google", "amap"] }
  ]
},
"geocode_confidence": {
  "anyOf": [
    { "type": "null" },
    { "type": "string", "enum": ["address", "name", "manual", "failed"] }
  ]
}
```

- [ ] **Step 5: Re-run test to verify pass**

Run: `pytest scripts/tests/test_schema_geocode.py -v`
Expected: PASS.

- [ ] **Step 6: Re-run full validation to catch regressions**

Run: `python3 scripts/validate.py`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add reports/extracted/schemas/schools.schema.json reports/extracted/schemas/_common.schema.json scripts/validate.py scripts/tests/test_schema_geocode.py
git commit -m "feat(schema): schools accept lat/lon/geocode_source/geocode_confidence"
```

---

### Task 4: Extend zones schema with `geometry_stage` + `geometry`

**Files:**
- Modify: `reports/extracted/schemas/zones.schema.json`

- [ ] **Step 1: Write failing test**

Append to `scripts/tests/test_schema_geocode.py`:

```python
def test_zones_geometry_stage_raster():
    sample = {
        "version": 1, "source": "test", "count": 1,
        "items": [{
            "id": "zon_0123456789", "district": "和平区", "zone_name": "第一学片",
            "geometry_stage": "raster",
            "geometry": {
                "image": "和平区学片.png",
                "corners": [[39.13,117.20],[39.13,117.22],[39.12,117.22],[39.12,117.20]]
            }
        }]
    }
    p = Path(tempfile.gettempdir()) / "zones_raster_sample.json"
    p.write_text(json.dumps(sample, ensure_ascii=False))
    r = subprocess.run([sys.executable, str(ROOT/"scripts"/"validate.py"), "--file", str(p), "--schema", "zones.schema.json"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr

def test_zones_geometry_stage_hull():
    sample = {
        "version": 1, "source": "test", "count": 1,
        "items": [{
            "id": "zon_0123456789", "district": "和平区", "zone_name": "第一学片",
            "geometry_stage": "hull",
            "geometry": {
                "type": "Polygon",
                "coordinates": [[[117.20,39.13],[117.22,39.13],[117.22,39.12],[117.20,39.12],[117.20,39.13]]]
            }
        }]
    }
    p = Path(tempfile.gettempdir()) / "zones_hull_sample.json"
    p.write_text(json.dumps(sample, ensure_ascii=False))
    r = subprocess.run([sys.executable, str(ROOT/"scripts"/"validate.py"), "--file", str(p), "--schema", "zones.schema.json"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest scripts/tests/test_schema_geocode.py -v`
Expected: both new tests FAIL (additionalProperties).

- [ ] **Step 3: Add to zones schema**

Modify `reports/extracted/schemas/zones.schema.json`, add to `$defs.Zone.properties`:

```json
"geometry_stage": { "type": "string", "enum": ["raster", "hull", "geojson"] },
"geometry":       { "oneOf": [ { "$ref": "#/$defs/RasterGeometry" }, { "$ref": "#/$defs/GeoJSONPolygon" } ] }
```

Add new `$defs` entries:

```json
"RasterGeometry": {
  "type": "object",
  "required": ["image", "corners"],
  "additionalProperties": false,
  "properties": {
    "image":   { "type": "string", "pattern": ".+\\.png$" },
    "corners": {
      "type": "array", "minItems": 4, "maxItems": 4,
      "items": {
        "type": "array", "minItems": 2, "maxItems": 2,
        "items": { "type": "number" }
      }
    }
  }
},
"GeoJSONPolygon": {
  "type": "object",
  "required": ["type", "coordinates"],
  "additionalProperties": false,
  "properties": {
    "type":        { "const": "Polygon" },
    "coordinates": {
      "type": "array", "minItems": 1,
      "items": {
        "type": "array", "minItems": 4,
        "items": {
          "type": "array", "minItems": 2, "maxItems": 2,
          "items": { "type": "number" }
        }
      }
    }
  }
}
```

- [ ] **Step 4: Re-run all schema tests**

Run: `pytest scripts/tests/ -v && python3 scripts/validate.py`
Expected: all PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add reports/extracted/schemas/zones.schema.json scripts/tests/test_schema_geocode.py
git commit -m "feat(schema): zones accept geometry_stage + raster/hull geometry"
```

---

### Task 5: Add `lat/lon/geocode*` to `School` @Model

**Files:**
- Modify: `PropertyAtlas/Models/Public/School.swift`
- Create: `PropertyAtlasTests/Studio/SchoolModelGeocodeTests.swift`

- [ ] **Step 1: Write failing test**

Create `PropertyAtlasTests/Studio/SchoolModelGeocodeTests.swift`:

```swift
import Testing
import SwiftData
@testable import PropertyAtlas

@Suite("School geocode fields")
struct SchoolGeocodeTests {
    @Test("school accepts lat/lon/geocodeSource/geocodeConfidence")
    func acceptsGeocode() {
        let s = School(name: "鞍山道小学", type: "小学", district: "和平区")
        s.lat = 39.1234
        s.lon = 117.1234
        s.geocodeSource = "CLGeocoder"
        s.geocodeConfidence = "address"
        #expect(s.lat == 39.1234)
        #expect(s.geocodeConfidence == "address")
    }

    @Test("default lat/lon nil")
    func defaultsNil() {
        let s = School(name: "Test", type: "小学", district: "和平区")
        #expect(s.lat == nil)
        #expect(s.lon == nil)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/SchoolGeocodeTests`
Expected: FAIL — `Value of type 'School' has no member 'lat'`.

- [ ] **Step 3: Add fields to School model**

Modify `PropertyAtlas/Models/Public/School.swift`:

```swift
import Foundation
import SwiftData

@Model
final class School {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = "小学"
    var zoneId: UUID?
    var district: String = ""
    var tier: String = "普通"
    var motto: String?
    var websiteUrl: String?
    var foundedYear: Int?
    var isPublicSchool: Bool = true
    var notes: String?
    var sourceUrl: String?

    // Studio geocode fields (added 2026-05-26)
    var lat: Double?
    var lon: Double?
    var geocodeSource: String?      // "CLGeocoder" | "manual" | "google" | "amap"
    var geocodeConfidence: String?  // "address" | "name" | "manual" | "failed"

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        type: String,
        zoneId: UUID? = nil,
        district: String,
        tier: String = "普通"
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.zoneId = zoneId
        self.district = district
        self.tier = tier
    }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/SchoolGeocodeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/Models/Public/School.swift PropertyAtlasTests/Studio/SchoolModelGeocodeTests.swift
git commit -m "feat(model): School adds lat/lon/geocodeSource/geocodeConfidence"
```

---

### Task 6: Add `geometryStage` to `SchoolZone` @Model + raster decoding

**Files:**
- Modify: `PropertyAtlas/Models/Public/SchoolZone.swift`
- Create: `PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift`

- [ ] **Step 1: Write failing test**

Create `PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift`:

```swift
import Testing
@testable import PropertyAtlas

@Suite("SchoolZone geometry stage")
struct SchoolZoneGeometryStageTests {
    @Test("default stage is hull")
    func defaultStage() {
        let z = SchoolZone(name: "test", primaryDistrict: "和平区", geometry: "{}")
        #expect(z.geometryStage == "hull")
    }

    @Test("decodeRasterGeometry parses image+corners")
    func decodeRaster() throws {
        let json = #"{"image":"和平区学片.png","corners":[[39.13,117.20],[39.13,117.22],[39.12,117.22],[39.12,117.20]]}"#
        let r = try SchoolZone.decodeRaster(json)
        #expect(r.image == "和平区学片.png")
        #expect(r.corners.count == 4)
        #expect(r.corners[0].latitude == 39.13)
        #expect(r.corners[0].longitude == 117.20)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/SchoolZoneGeometryStageTests`
Expected: FAIL.

- [ ] **Step 3: Update SchoolZone**

Modify `PropertyAtlas/Models/Public/SchoolZone.swift`:

```swift
import CoreLocation
import SwiftData

@Model
final class SchoolZone {
    var id: UUID = UUID()
    var name: String = ""
    var tier: String = "普通"
    var primaryDistrict: String = ""
    var geometry: String = ""                  // JSON-encoded; shape depends on geometryStage
    var geometryStage: String = "hull"         // "raster" | "hull" | "geojson"
    var geometrySimplified: String?
    var residencyYears: Int?
    var strokeColorHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        tier: String = "普通",
        primaryDistrict: String,
        geometry: String,
        geometryStage: String = "hull"
    ) {
        self.id = id
        self.name = name
        self.tier = tier
        self.primaryDistrict = primaryDistrict
        self.geometry = geometry
        self.geometryStage = geometryStage
    }

    var decodedCoordinates: [CLLocationCoordinate2D] {
        (try? GeoJSONHelper.decodePolygon(geometry)) ?? []
    }

    struct RasterGeometry {
        let image: String
        let corners: [CLLocationCoordinate2D]
    }

    static func decodeRaster(_ json: String) throws -> RasterGeometry {
        guard let data = json.data(using: .utf8) else { throw GeoJSONHelper.GeoJSONError.invalidUTF8 }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let image = dict["image"] as? String,
              let corners = dict["corners"] as? [[Double]],
              corners.count == 4
        else { throw GeoJSONHelper.GeoJSONError.invalidStructure }
        return RasterGeometry(
            image: image,
            corners: corners.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
        )
    }
}

enum GeoJSONHelper {
    static func decodePolygon(_ geojson: String) throws -> [CLLocationCoordinate2D] {
        guard let data = geojson.data(using: .utf8) else {
            throw GeoJSONError.invalidUTF8
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let coords = dict["coordinates"] as? [[[Double]]],
              let ring = coords.first
        else {
            throw GeoJSONError.invalidStructure
        }
        return ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
    }

    static func encodePolygon(_ coords: [CLLocationCoordinate2D]) throws -> String {
        let ring = coords.map { [$0.longitude, $0.latitude] }
        let dict: [String: Any] = ["type": "Polygon", "coordinates": [ring]]
        let data = try JSONSerialization.data(withJSONObject: dict)
        return String(data: data, encoding: .utf8)!
    }

    enum GeoJSONError: Error {
        case invalidUTF8, invalidStructure
    }
}
```

- [ ] **Step 4: Run test to verify pass**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/SchoolZoneGeometryStageTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/Models/Public/SchoolZone.swift PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift
git commit -m "feat(model): SchoolZone adds geometryStage + raster decoder"
```

---

## Phase 2 — Geocoding pipeline

### Task 7: `scripts/geocode_schools.swift` CLI

**Files:**
- Create: `scripts/geocode_schools.swift`

**Note:** This is a standalone macOS Swift script using `CLGeocoder`. Geocoding API is async; throttle to 1 req/sec to respect Apple rate limits. Caches result in-place into `schools.json`. Idempotent: skips schools already having `lat`+`lon`.

- [ ] **Step 1: Create the script**

Create `scripts/geocode_schools.swift`:

```swift
#!/usr/bin/env swift
// Usage: swift scripts/geocode_schools.swift
// Reads reports/extracted/schools.json, geocodes missing lat/lon, writes back.

import CoreLocation
import Foundation

let path = "reports/extracted/schools.json"
let failPath = "reports/extracted/geocode_failed.json"

guard let data = FileManager.default.contents(atPath: path),
      var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      var items = root["items"] as? [[String: Any]]
else {
    FileHandle.standardError.write("ERROR: cannot read \(path)\n".data(using: .utf8)!)
    exit(1)
}

let geocoder = CLGeocoder()
let semaphore = DispatchSemaphore(value: 0)
var failed: [[String: String]] = []

func geocode(_ address: String) async -> CLLocationCoordinate2D? {
    do {
        let placemarks = try await geocoder.geocodeAddressString("天津市 " + address)
        return placemarks.first?.location?.coordinate
    } catch {
        return nil
    }
}

Task {
    for i in items.indices {
        var item = items[i]
        let name = (item["name"] as? String) ?? "?"
        if item["lat"] != nil, !(item["lat"] is NSNull) { continue }
        guard let address = item["address"] as? String, !address.isEmpty else {
            failed.append(["id": (item["id"] as? String) ?? "?", "name": name, "reason": "no address"])
            continue
        }
        // Strip multi-campus addresses to first one
        let firstAddr = address.split(separator: "、").first.map(String.init) ?? address
        let firstAddr2 = firstAddr.split(separator: "(").first.map(String.init) ?? firstAddr
        if let coord = await geocode(firstAddr2) {
            item["lat"] = coord.latitude
            item["lon"] = coord.longitude
            item["geocode_source"] = "CLGeocoder"
            item["geocode_confidence"] = "address"
            items[i] = item
            print("✓ \(name) → (\(coord.latitude), \(coord.longitude))")
        } else {
            failed.append(["id": (item["id"] as? String) ?? "?", "name": name, "reason": "geocode failed for: \(firstAddr2)"])
            item["geocode_confidence"] = "failed"
            items[i] = item
            print("✗ \(name) — \(firstAddr2)")
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 req/sec
    }
    root["items"] = items
    let out = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try! out.write(to: URL(fileURLWithPath: path))
    let failOut = try! JSONSerialization.data(withJSONObject: failed, options: [.prettyPrinted])
    try! failOut.write(to: URL(fileURLWithPath: failPath))
    print("\nDone. \(failed.count) failed → \(failPath)")
    semaphore.signal()
}

semaphore.wait()
```

- [ ] **Step 2: Dry-run on 5 schools (test mode)**

Add a temporary `--limit 5` env var path or hand-edit the loop break. Run:
`swift scripts/geocode_schools.swift`
Expected: 5 schools geocoded, JSON updated, `geocode_failed.json` written.

- [ ] **Step 3: Validate JSON still passes schema**

Run: `python3 scripts/validate.py`
Expected: exit 0.

- [ ] **Step 4: Full run (all 822 schools)**

Run: `swift scripts/geocode_schools.swift` (will take ~14 minutes at 1 req/sec).
Expected: ~95%+ success, residue in `geocode_failed.json`.

- [ ] **Step 5: Commit**

```bash
git add scripts/geocode_schools.swift reports/extracted/schools.json reports/extracted/geocode_failed.json
git commit -m "feat(data): geocode 822 schools via CLGeocoder, cache lat/lon"
```

---

## Phase 3 — Stage A raster pipeline + overlay

### Task 8: `scripts/calibrate_raster` standalone macOS Swift Package

**Files:**
- Create: `scripts/calibrate_raster/Package.swift`
- Create: `scripts/calibrate_raster/Sources/Calibrator/main.swift`
- Create: `scripts/calibrate_raster/Sources/Calibrator/CalibratorApp.swift`

**Note:** This is a separate Swift Package, not part of the iOS app. It runs only on macOS.

- [ ] **Step 1: Create Package.swift**

Create `scripts/calibrate_raster/Package.swift`:

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Calibrator",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Calibrator")
    ]
)
```

- [ ] **Step 2: Create main + app**

Create `scripts/calibrate_raster/Sources/Calibrator/main.swift`:

```swift
import SwiftUI

guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift run Calibrator <district-name> [raster-png-path]")
    exit(1)
}

let district = CommandLine.arguments[1]
let pngPath = CommandLine.arguments.count >= 3
    ? CommandLine.arguments[2]
    : "../../PropertyAtlas/PropertyAtlas/Resources/StudioRasters/raw/\(district)学片.png"

CalibratorApp.launch(district: district, pngPath: pngPath)
```

Create `scripts/calibrate_raster/Sources/Calibrator/CalibratorApp.swift`:

```swift
import AppKit
import MapKit
import SwiftUI

enum CalibratorApp {
    static func launch(district: String, pngPath: String) {
        let app = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.title = "Calibrate \(district) raster"
        let view = CalibratorView(district: district, pngPath: pngPath)
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

struct CalibratorView: View {
    let district: String
    let pngPath: String
    @State private var corners: [CLLocationCoordinate2D] = [
        .init(latitude: 39.135, longitude: 117.190),
        .init(latitude: 39.135, longitude: 117.220),
        .init(latitude: 39.115, longitude: 117.220),
        .init(latitude: 39.115, longitude: 117.190),
    ]
    @State private var rasterAlpha: Double = 0.5

    var body: some View {
        VStack(spacing: 8) {
            CalibratorMap(corners: $corners, pngPath: pngPath, alpha: rasterAlpha)
            HStack {
                Text("Alpha")
                Slider(value: $rasterAlpha, in: 0.0...1.0)
                Button("Save") { save() }
            }.padding(.horizontal)
            Text("Drag the 4 red dots so the raster overlays the actual streets.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    func save() {
        let path = "../../reports/extracted/zones.json"
        guard let data = FileManager.default.contents(atPath: path),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var items = root["items"] as? [[String: Any]]
        else { print("ERROR: cannot read \(path)"); return }

        var saved = 0
        for i in items.indices {
            guard let d = items[i]["district"] as? String, d == district else { continue }
            items[i]["geometry_stage"] = "raster"
            items[i]["geometry"] = [
                "image": "\(district)学片.png",
                "corners": corners.map { [$0.latitude, $0.longitude] }
            ]
            saved += 1
        }
        root["items"] = items
        let out = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try! out.write(to: URL(fileURLWithPath: path))
        print("✓ saved \(saved) zones for \(district)")
    }
}

struct CalibratorMap: NSViewRepresentable {
    @Binding var corners: [CLLocationCoordinate2D]
    let pngPath: String
    let alpha: Double

    func makeNSView(context: Context) -> MKMapView {
        let v = MKMapView()
        v.mapType = .mutedStandard
        v.setRegion(MKCoordinateRegion(
            center: .init(latitude: 39.125, longitude: 117.205),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ), animated: false)
        // TODO: overlay raster, draggable corner annotations
        // (full impl: ~120 lines; below shows minimal scaffold)
        return v
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {}
}
```

**Note:** The calibrator's interactive draggable-corner UI is non-trivial (~120 lines). The scaffold above gets you to a working map view; complete the corner overlay + drag handling in [Task 8.2] below.

- [ ] **Step 3: Smoke test the scaffold**

Run: `cd scripts/calibrate_raster && swift run Calibrator 和平区`
Expected: window opens with a Tianjin map, alpha slider, Save button. (Raster + draggable corners are pending.)

- [ ] **Step 4: Commit scaffold**

```bash
git add scripts/calibrate_raster/
git commit -m "feat(tooling): calibrate_raster standalone Swift Package scaffold"
```

---

### Task 8.2: Calibrator — raster overlay + draggable corners

**Files:**
- Modify: `scripts/calibrate_raster/Sources/Calibrator/CalibratorApp.swift`

- [ ] **Step 1: Add `RasterOverlay` and 4 draggable annotations**

Replace the body of `CalibratorMap` and add helpers:

```swift
class CornerPin: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    let index: Int
    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate; self.index = index
    }
}

class CalibratorCoordinator: NSObject, MKMapViewDelegate {
    var binding: Binding<[CLLocationCoordinate2D]>!
    var pngPath: String!
    var alpha: Double = 0.5
    var rasterOverlay: RasterImageOverlay?

    func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let p = annotation as? CornerPin else { return nil }
        let v = MKMarkerAnnotationView(annotation: p, reuseIdentifier: "corner")
        v.markerTintColor = .systemRed
        v.isDraggable = true
        return v
    }

    func mapView(_ mv: MKMapView, annotationView v: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState old: MKAnnotationView.DragState) {
        guard let p = v.annotation as? CornerPin, newState == .ending || newState == .dragging else { return }
        var arr = binding.wrappedValue
        arr[p.index] = p.coordinate
        binding.wrappedValue = arr
        rasterOverlay?.setCorners(arr)
        mv.removeOverlays(mv.overlays); if let o = rasterOverlay { mv.addOverlay(o) }
    }

    func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let o = overlay as? RasterImageOverlay else { return MKOverlayRenderer(overlay: overlay) }
        return RasterImageOverlayRenderer(overlay: o, alpha: CGFloat(alpha))
    }
}

class RasterImageOverlay: NSObject, MKOverlay {
    let image: NSImage
    var corners: [CLLocationCoordinate2D]
    var coordinate: CLLocationCoordinate2D { corners.first ?? .init() }
    var boundingMapRect: MKMapRect {
        let pts = corners.map { MKMapPoint($0) }
        let xs = pts.map(\.x), ys = pts.map(\.y)
        return MKMapRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
    init(image: NSImage, corners: [CLLocationCoordinate2D]) { self.image = image; self.corners = corners }
    func setCorners(_ c: [CLLocationCoordinate2D]) { self.corners = c }
}

class RasterImageOverlayRenderer: MKOverlayRenderer {
    let img: NSImage
    let alpha: CGFloat
    init(overlay: RasterImageOverlay, alpha: CGFloat) {
        self.img = overlay.image; self.alpha = alpha
        super.init(overlay: overlay)
    }
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard let raster = overlay as? RasterImageOverlay,
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let mapPts = raster.corners.map { MKMapPoint($0) }
        let cgPts = mapPts.map { self.point(for: $0) }
        // Affine: map image quad (0,0)-(w,h) to cgPts[0..3] approximated as a parallelogram via 3-pt mapping
        let (tl, tr, bl) = (cgPts[0], cgPts[1], cgPts[3])
        let dx1 = (tr.x - tl.x) / CGFloat(cg.width)
        let dy1 = (tr.y - tl.y) / CGFloat(cg.width)
        let dx2 = (bl.x - tl.x) / CGFloat(cg.height)
        let dy2 = (bl.y - tl.y) / CGFloat(cg.height)
        let transform = CGAffineTransform(a: dx1, b: dy1, c: dx2, d: dy2, tx: tl.x, ty: tl.y)
        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.concatenate(transform)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        ctx.restoreGState()
    }
}

extension CalibratorMap {
    func makeCoordinator() -> CalibratorCoordinator {
        let c = CalibratorCoordinator()
        c.binding = $corners
        c.pngPath = pngPath
        c.alpha = alpha
        return c
    }
}
```

Then update `makeNSView` to:
1. Set `v.delegate = context.coordinator`
2. Add 4 `CornerPin` annotations for the 4 corners
3. Load PNG from `pngPath` (NSImage) and add a `RasterImageOverlay` with those 4 corners
4. In `updateNSView`, on alpha or corners change, refresh the overlay

```swift
func makeNSView(context: Context) -> MKMapView {
    let v = MKMapView()
    v.delegate = context.coordinator
    v.mapType = .mutedStandard
    v.setRegion(MKCoordinateRegion(
        center: .init(latitude: 39.125, longitude: 117.205),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ), animated: false)
    let pins = corners.enumerated().map { CornerPin(coordinate: $0.element, index: $0.offset) }
    v.addAnnotations(pins)
    if let img = NSImage(contentsOfFile: pngPath) {
        let overlay = RasterImageOverlay(image: img, corners: corners)
        context.coordinator.rasterOverlay = overlay
        v.addOverlay(overlay)
    }
    return v
}

func updateNSView(_ nsView: MKMapView, context: Context) {
    context.coordinator.alpha = alpha
    context.coordinator.rasterOverlay?.setCorners(corners)
    nsView.removeOverlays(nsView.overlays)
    if let o = context.coordinator.rasterOverlay { nsView.addOverlay(o) }
}
```

- [ ] **Step 2: Test interactively with `和平区` raster**

Place a sample PNG at `PropertyAtlas/PropertyAtlas/Resources/StudioRasters/raw/和平区学片.png` (PDF page export). Run:
`cd scripts/calibrate_raster && swift run Calibrator 和平区 ../../PropertyAtlas/PropertyAtlas/Resources/StudioRasters/raw/和平区学片.png`
Expected: image overlays the map, drag the red dots to align, press Save → `zones.json` updates.

- [ ] **Step 3: Validate JSON**

Run: `python3 scripts/validate.py`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/calibrate_raster/Sources/Calibrator/CalibratorApp.swift
git commit -m "feat(tooling): calibrator raster overlay + draggable corners"
```

---

### Task 9: Bundle StudioRasters resources

**Files:**
- Modify: `PropertyAtlas/PropertyAtlas.xcodeproj` (add resource folder ref)
- Create: `PropertyAtlas/Resources/StudioRasters/.gitkeep`

- [ ] **Step 1: Create directory**

```bash
mkdir -p /Users/fujie/projects/天津买房/PropertyAtlas/PropertyAtlas/Resources/StudioRasters/raw
touch /Users/fujie/projects/天津买房/PropertyAtlas/PropertyAtlas/Resources/StudioRasters/.gitkeep
```

- [ ] **Step 2: Add folder reference to Xcode project**

In Xcode → File → Add Files to "PropertyAtlas" → select `Resources/StudioRasters` as folder reference (blue). Target: PropertyAtlas. This makes any `.png` inside accessible via `Bundle.main.url(forResource:withExtension:subdirectory:)`.

- [ ] **Step 3: Verify build still passes**

Run: `xcodebuild ... -destination 'platform=macOS,variant=Mac Catalyst' build`
Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlas.xcodeproj PropertyAtlas/PropertyAtlas/Resources/StudioRasters/.gitkeep
git commit -m "feat(studio): bundle StudioRasters resource folder ref"
```

---

### Task 10: `CalibratedImageOverlay` + `Renderer` in app

**Files:**
- Create: `PropertyAtlas/Studio/RasterAlignment/CalibratedImageOverlay.swift`
- Create: `PropertyAtlas/Studio/RasterAlignment/CalibratedImageOverlayRenderer.swift`
- Create: `PropertyAtlasTests/Studio/CalibratedImageOverlayTests.swift`

- [ ] **Step 1: Write failing test**

Create `PropertyAtlasTests/Studio/CalibratedImageOverlayTests.swift`:

```swift
#if targetEnvironment(macCatalyst)
import Testing
import CoreLocation
import MapKit
@testable import PropertyAtlas

@Suite("CalibratedImageOverlay")
struct CalibratedImageOverlayTests {
    @Test("boundingMapRect covers all 4 corners")
    func bounds() {
        let corners = [
            CLLocationCoordinate2D(latitude: 39.135, longitude: 117.190),
            CLLocationCoordinate2D(latitude: 39.135, longitude: 117.220),
            CLLocationCoordinate2D(latitude: 39.115, longitude: 117.220),
            CLLocationCoordinate2D(latitude: 39.115, longitude: 117.190),
        ]
        let overlay = CalibratedImageOverlay(image: UIImage(), corners: corners)
        let r = overlay.boundingMapRect
        for c in corners {
            #expect(r.contains(MKMapPoint(c)))
        }
    }
}
#endif
```

- [ ] **Step 2: Run to verify fail**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/CalibratedImageOverlayTests`
Expected: FAIL — type not defined.

- [ ] **Step 3: Implement**

Create `PropertyAtlas/Studio/RasterAlignment/CalibratedImageOverlay.swift`:

```swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit
import UIKit

final class CalibratedImageOverlay: NSObject, MKOverlay {
    let image: UIImage
    let corners: [CLLocationCoordinate2D]

    init(image: UIImage, corners: [CLLocationCoordinate2D]) {
        precondition(corners.count == 4, "corners must be exactly 4 (TL,TR,BR,BL)")
        self.image = image
        self.corners = corners
    }

    var coordinate: CLLocationCoordinate2D { corners.first ?? CLLocationCoordinate2D() }

    var boundingMapRect: MKMapRect {
        let pts = corners.map { MKMapPoint($0) }
        let xs = pts.map(\.x); let ys = pts.map(\.y)
        return MKMapRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }
}
#endif
```

Create `PropertyAtlas/Studio/RasterAlignment/CalibratedImageOverlayRenderer.swift`:

```swift
#if targetEnvironment(macCatalyst)
import CoreGraphics
import MapKit
import UIKit

final class CalibratedImageOverlayRenderer: MKOverlayRenderer {
    let img: UIImage
    let baseAlpha: CGFloat

    init(overlay: CalibratedImageOverlay, baseAlpha: CGFloat = 0.35) {
        self.img = overlay.image
        self.baseAlpha = baseAlpha
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard let raster = overlay as? CalibratedImageOverlay,
              let cg = img.cgImage else { return }
        let cgPts = raster.corners.map { self.point(for: MKMapPoint($0)) }
        // 3-point affine mapping image (TL, TR, BL) → (cgPts[0], cgPts[1], cgPts[3])
        let (tl, tr, bl) = (cgPts[0], cgPts[1], cgPts[3])
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let transform = CGAffineTransform(
            a: (tr.x - tl.x) / w,
            b: (tr.y - tl.y) / w,
            c: (bl.x - tl.x) / h,
            d: (bl.y - tl.y) / h,
            tx: tl.x, ty: tl.y
        )
        // Zoom-based alpha taper: full at zoom 1, fade to 0.1 past zoom 5
        let zoomFactor = max(0.1, min(1.0, 1.0 - Double(log2(zoomScale)) * 0.2))
        ctx.saveGState()
        ctx.setAlpha(baseAlpha * CGFloat(zoomFactor))
        ctx.concatenate(transform)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()
    }
}
#endif
```

- [ ] **Step 4: Run test, verify pass**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/CalibratedImageOverlayTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/Studio/RasterAlignment/ PropertyAtlasTests/Studio/CalibratedImageOverlayTests.swift
git commit -m "feat(studio): CalibratedImageOverlay + Renderer (Mac Catalyst)"
```

---

### Task 11: `ZoneGeometryImporter` dispatches by stage

**Files:**
- Create: `PropertyAtlas/Studio/Layers/ZoneGeometryImporter.swift`
- Modify: `PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift` (add dispatch test)

- [ ] **Step 1: Append failing dispatch test**

In `PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift`:

```swift
#if targetEnvironment(macCatalyst)
import MapKit

extension SchoolZoneGeometryStageTests {
    @Test("importer returns CalibratedImageOverlay for raster stage")
    func dispatchesRaster() throws {
        let z = SchoolZone(name: "x", primaryDistrict: "和平区",
            geometry: #"{"image":"和平区学片.png","corners":[[39.13,117.20],[39.13,117.22],[39.12,117.22],[39.12,117.20]]}"#,
            geometryStage: "raster")
        let overlay = try ZoneGeometryImporter.makeOverlay(for: z, imageProvider: { _ in UIImage() })
        #expect(overlay is CalibratedImageOverlay)
    }

    @Test("importer returns MKPolygon for hull stage")
    func dispatchesHull() throws {
        let z = SchoolZone(name: "x", primaryDistrict: "和平区",
            geometry: #"{"type":"Polygon","coordinates":[[[117.20,39.13],[117.22,39.13],[117.22,39.12],[117.20,39.12],[117.20,39.13]]]}"#,
            geometryStage: "hull")
        let overlay = try ZoneGeometryImporter.makeOverlay(for: z, imageProvider: { _ in UIImage() })
        #expect(overlay is MKPolygon)
    }
}
#endif
```

- [ ] **Step 2: Run, expect fail**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/SchoolZoneGeometryStageTests`
Expected: FAIL — `ZoneGeometryImporter` not defined.

- [ ] **Step 3: Implement**

Create `PropertyAtlas/Studio/Layers/ZoneGeometryImporter.swift`:

```swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit
import UIKit

enum ZoneGeometryImporter {
    enum ImporterError: Error { case unsupportedStage(String), imageMissing(String) }

    static func makeOverlay(for zone: SchoolZone,
                            imageProvider: (String) -> UIImage?) throws -> MKOverlay {
        switch zone.geometryStage {
        case "raster":
            let r = try SchoolZone.decodeRaster(zone.geometry)
            guard let img = imageProvider(r.image) else { throw ImporterError.imageMissing(r.image) }
            return CalibratedImageOverlay(image: img, corners: r.corners)
        case "hull", "geojson":
            let coords = try GeoJSONHelper.decodePolygon(zone.geometry)
            return MKPolygon(coordinates: coords, count: coords.count)
        default:
            throw ImporterError.unsupportedStage(zone.geometryStage)
        }
    }

    static func bundledImage(named: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: named.replacingOccurrences(of: ".png", with: ""),
                                        withExtension: "png",
                                        subdirectory: "StudioRasters") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
#endif
```

- [ ] **Step 4: Run test, expect pass**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/SchoolZoneGeometryStageTests`
Expected: PASS (all 4 tests in suite).

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/Studio/Layers/ZoneGeometryImporter.swift PropertyAtlasTests/Studio/ZoneGeometryImporterTests.swift
git commit -m "feat(studio): ZoneGeometryImporter dispatches raster/hull/geojson"
```

---

## Phase 4 — Stage B convex/alpha hull pipeline

### Task 12: `scripts/build_zone_hulls.py`

**Files:**
- Create: `scripts/build_zone_hulls.py`
- Create: `scripts/tests/test_build_zone_hulls.py`

- [ ] **Step 1: Write failing test**

Create `scripts/tests/test_build_zone_hulls.py`:

```python
import json, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def test_build_hulls_basic(tmp_path):
    schools = {"version": 1, "source": "test", "count": 4, "items": [
        {"id": "sch_a", "name": "A", "district": "和平区", "level": "primary", "source": "JM-PDF",
         "zone_id": "zon_a", "is_private": False, "is_jiunian": False, "is_market_key": False,
         "lat": 39.13, "lon": 117.20},
        {"id": "sch_b", "name": "B", "district": "和平区", "level": "primary", "source": "JM-PDF",
         "zone_id": "zon_a", "is_private": False, "is_jiunian": False, "is_market_key": False,
         "lat": 39.14, "lon": 117.21},
        {"id": "sch_c", "name": "C", "district": "和平区", "level": "primary", "source": "JM-PDF",
         "zone_id": "zon_a", "is_private": False, "is_jiunian": False, "is_market_key": False,
         "lat": 39.13, "lon": 117.22},
        {"id": "sch_d", "name": "D", "district": "和平区", "level": "primary", "source": "JM-PDF",
         "zone_id": "zon_a", "is_private": False, "is_jiunian": False, "is_market_key": False,
         "lat": 39.12, "lon": 117.21},
    ]}
    zones = {"version": 1, "source": "test", "count": 1, "items": [
        {"id": "zon_a", "district": "和平区", "zone_name": "第一学片"}
    ]}
    (tmp_path / "schools.json").write_text(json.dumps(schools, ensure_ascii=False))
    (tmp_path / "zones.json").write_text(json.dumps(zones, ensure_ascii=False))
    r = subprocess.run([sys.executable, str(ROOT/"scripts"/"build_zone_hulls.py"),
                        "--schools", str(tmp_path/"schools.json"),
                        "--zones", str(tmp_path/"zones.json")],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    out = json.loads((tmp_path / "zones.json").read_text())
    item = out["items"][0]
    assert item["geometry_stage"] == "hull"
    assert item["geometry"]["type"] == "Polygon"
    assert len(item["geometry"]["coordinates"][0]) >= 4
```

- [ ] **Step 2: Run, expect fail**

Run: `pytest scripts/tests/test_build_zone_hulls.py -v`
Expected: FAIL — script not found.

- [ ] **Step 3: Implement**

Create `scripts/build_zone_hulls.py`:

```python
#!/usr/bin/env python3
"""Compute convex/alpha hull for each zone from its schools' lat/lon.

Usage:
    python3 scripts/build_zone_hulls.py
    python3 scripts/build_zone_hulls.py --schools path --zones path
"""
import argparse, json, sys
from pathlib import Path

try:
    from shapely.geometry import MultiPoint, Polygon
except ImportError:
    print("Install shapely: pip install shapely alphashape", file=sys.stderr); sys.exit(1)

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SCHOOLS = ROOT / "reports" / "extracted" / "schools.json"
DEFAULT_ZONES   = ROOT / "reports" / "extracted" / "zones.json"

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--schools", default=str(DEFAULT_SCHOOLS))
    ap.add_argument("--zones",   default=str(DEFAULT_ZONES))
    ap.add_argument("--alpha",   type=float, default=0.0, help="0=convex; >0 tries alphashape")
    args = ap.parse_args()

    schools_path = Path(args.schools); zones_path = Path(args.zones)
    schools = json.loads(schools_path.read_text())
    zones = json.loads(zones_path.read_text())
    by_zone: dict[str, list[tuple[float, float]]] = {}
    for s in schools["items"]:
        zid = s.get("zone_id")
        if not zid or s.get("lat") is None or s.get("lon") is None: continue
        by_zone.setdefault(zid, []).append((s["lon"], s["lat"]))

    upgraded = 0; skipped = 0
    for z in zones["items"]:
        # Preserve existing raster geometry if no schools to hull
        pts = by_zone.get(z["id"], [])
        if len(pts) < 3:
            skipped += 1; continue
        hull = compute_hull(pts, alpha=args.alpha)
        if hull is None or hull.area == 0:
            skipped += 1; continue
        coords = list(hull.exterior.coords)
        z["geometry_stage"] = "hull"
        z["geometry"] = {"type": "Polygon", "coordinates": [[[x, y] for x, y in coords]]}
        upgraded += 1

    zones_path.write_text(json.dumps(zones, ensure_ascii=False, indent=2))
    print(f"hulls: {upgraded} upgraded, {skipped} skipped")
    return 0

def compute_hull(pts, alpha: float) -> "Polygon | None":
    if alpha > 0:
        try:
            import alphashape
            shape = alphashape.alphashape(pts, alpha)
            if isinstance(shape, Polygon) and shape.area > 0: return shape
        except Exception:
            pass
    return MultiPoint(pts).convex_hull if len(pts) >= 3 else None

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test, expect pass**

Run: `pytest scripts/tests/test_build_zone_hulls.py -v`
Expected: PASS.

- [ ] **Step 5: Run on real data**

Run: `python3 scripts/build_zone_hulls.py && python3 scripts/validate.py`
Expected: hulls upgraded for zones whose schools have lat/lon; validate exits 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/build_zone_hulls.py scripts/tests/test_build_zone_hulls.py reports/extracted/zones.json
git commit -m "feat(data): convex/alpha hull → zones.json geometry_stage=hull"
```

---

## Phase 5 — MapKit wiring + base layers

### Task 13: `MapKitView` UIViewRepresentable + replace `MapContainerView` placeholder

**Files:**
- Create: `PropertyAtlas/Map/MapKitView.swift`
- Modify: `PropertyAtlas/Map/MapContainerView.swift`

- [ ] **Step 1: Implement `MapKitView`**

Create `PropertyAtlas/Map/MapKitView.swift`:

```swift
import MapKit
import SwiftUI

struct MapKitView: UIViewRepresentable {
    @Binding var camera: MKMapCamera
    var overlays: [MKOverlay] = []
    var annotations: [MKAnnotation] = []
    var configure: (MKMapView) -> Void = { _ in }
    var coordinator: Coordinator = Coordinator()

    func makeCoordinator() -> Coordinator { coordinator }

    func makeUIView(context: Context) -> MKMapView {
        let v = MKMapView()
        v.delegate = context.coordinator
        v.mapType = .mutedStandard
        v.pointOfInterestFilter = .excludingAll
        v.showsBuildings = false
        v.showsCompass = false
        v.showsScale = false
        v.setCamera(camera, animated: false)
        configure(v)
        return v
    }

    func updateUIView(_ v: MKMapView, context: Context) {
        v.setCamera(camera, animated: true)
        let desiredIds = Set(overlays.map { ObjectIdentifier($0) })
        let toRemove = v.overlays.filter { !desiredIds.contains(ObjectIdentifier($0)) }
        v.removeOverlays(toRemove)
        let existingIds = Set(v.overlays.map { ObjectIdentifier($0) })
        let toAdd = overlays.filter { !existingIds.contains(ObjectIdentifier($0)) }
        v.addOverlays(toAdd)
        v.removeAnnotations(v.annotations)
        v.addAnnotations(annotations)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            #if targetEnvironment(macCatalyst)
            if let raster = overlay as? CalibratedImageOverlay {
                return CalibratedImageOverlayRenderer(overlay: raster)
            }
            #endif
            if let poly = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: poly)
                r.fillColor = UIColor.systemTeal.withAlphaComponent(0.35)
                r.strokeColor = UIColor.systemTeal
                r.lineWidth = 1.5
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
```

- [ ] **Step 2: Replace `MapContainerView` placeholder**

Modify `PropertyAtlas/Map/MapContainerView.swift`:

```swift
import MapKit
import SwiftUI

struct MapContainerView: View {
    @State private var camera = MKMapCamera(
        lookingAtCenter: .init(latitude: 39.125, longitude: 117.205),
        fromDistance: 12000, pitch: 0, heading: 0
    )

    var body: some View {
        MapKitView(camera: $camera)
    }
}
```

- [ ] **Step 3: Manual smoke test**

Run: `xcodebuild ... -destination 'platform=macOS,variant=Mac Catalyst' build && open ...app or run from Xcode`
Expected: App opens with a muted-style MapKit view centered on Tianjin.

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/Map/MapKitView.swift PropertyAtlas/Map/MapContainerView.swift
git commit -m "feat(map): MKMapView wrapper replaces placeholder, muted basemap"
```

---

### Task 14: Wire Studio mode to read zones + push overlays/annotations

**Files:**
- Create: `PropertyAtlas/Studio/Layers/ZoneCentroidAnnotation.swift`
- Create: `PropertyAtlas/Studio/Layers/SchoolAnnotation.swift`
- Modify: `PropertyAtlas/RootView.swift` (StudioRootView pushes overlays to MapKitView)
- Modify: `PropertyAtlas/Map/MapContainerView.swift` (accept overlays/annotations params)

- [ ] **Step 1: `SchoolAnnotation` + view**

Create `PropertyAtlas/Studio/Layers/SchoolAnnotation.swift`:

```swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit
import UIKit

final class SchoolAnnotation: NSObject, MKAnnotation {
    let id: UUID
    let name: String
    let level: String   // "primary" / "middle" / "jiunian"
    let isMarketKey: Bool
    let tier: String
    dynamic var coordinate: CLLocationCoordinate2D
    init(school: School) {
        self.id = school.id
        self.name = school.name
        self.level = school.type
        self.isMarketKey = false  // wire to real field if available
        self.tier = school.tier
        self.coordinate = .init(latitude: school.lat ?? 0, longitude: school.lon ?? 0)
    }
    var title: String? { name }
}
#endif
```

Create `PropertyAtlas/Studio/Layers/ZoneCentroidAnnotation.swift`:

```swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit

final class ZoneCentroidAnnotation: NSObject, MKAnnotation {
    let zoneId: UUID
    let name: String
    let tier: String
    dynamic var coordinate: CLLocationCoordinate2D
    init(zone: SchoolZone, centroid: CLLocationCoordinate2D) {
        self.zoneId = zone.id; self.name = zone.name; self.tier = zone.tier
        self.coordinate = centroid
    }
    var title: String? { name }
}
#endif
```

- [ ] **Step 2: Extend coordinator to render school/centroid annotations**

In `MapKitView.Coordinator`, add:

```swift
func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    #if targetEnvironment(macCatalyst)
    if let s = annotation as? SchoolAnnotation {
        let v = MKMarkerAnnotationView(annotation: s, reuseIdentifier: "school")
        v.markerTintColor = colorForTier(s.tier)
        v.glyphText = s.level == "primary" ? "小" : (s.level == "middle" ? "中" : "九")
        v.displayPriority = .required
        v.titleVisibility = .visible
        return v
    }
    if let z = annotation as? ZoneCentroidAnnotation {
        let v = MKMarkerAnnotationView(annotation: z, reuseIdentifier: "zone")
        v.markerTintColor = colorForTier(z.tier)
        v.glyphImage = nil
        v.titleVisibility = .visible
        return v
    }
    #endif
    return nil
}

private func colorForTier(_ t: String) -> UIColor {
    switch t {
    case "顶尖": return UIColor(red: 201/255, green: 155/255, blue: 44/255, alpha: 1)
    case "优质": return UIColor(red: 91/255, green: 124/255, blue: 156/255, alpha: 1)
    case "薄弱": return UIColor(red: 184/255, green: 115/255, blue: 107/255, alpha: 1)
    default:    return UIColor(red: 156/255, green: 150/255, blue: 139/255, alpha: 1)
    }
}
```

- [ ] **Step 3: Add overlay/annotation params to `MapContainerView`**

Replace `MapContainerView` body:

```swift
struct MapContainerView: View {
    @State private var camera = MKMapCamera(
        lookingAtCenter: .init(latitude: 39.125, longitude: 117.205),
        fromDistance: 12000, pitch: 0, heading: 0
    )
    var overlays: [MKOverlay] = []
    var annotations: [MKAnnotation] = []

    var body: some View {
        MapKitView(camera: $camera, overlays: overlays, annotations: annotations)
    }
}
```

- [ ] **Step 4: `StudioRootView` queries SwiftData and pushes overlays**

Modify `StudioRootView` (in `RootView.swift`):

```swift
#if targetEnvironment(macCatalyst)
import MapKit
import SwiftData

struct StudioRootView: View {
    @Query private var zones: [SchoolZone]
    @Query private var schools: [School]

    var body: some View {
        let overlays = zones.compactMap { try? ZoneGeometryImporter.makeOverlay(for: $0, imageProvider: ZoneGeometryImporter.bundledImage(named:)) }
        let pins = schools
            .filter { $0.lat != nil && $0.lon != nil }
            .map { SchoolAnnotation(school: $0) }

        ZStack {
            MapContainerView(overlays: overlays, annotations: pins).ignoresSafeArea()
            // StudioOverlay added in Task 17
        }
    }
}
#endif
```

- [ ] **Step 5: Manual smoke test**

Run on Mac Catalyst. Toggle to Studio mode (via dev shortcut from Task 25, or temporarily flip `AppMode` default to `.studio`).
Expected: School pins appear over Tianjin. If raster PNG present + a zone calibrated, raster overlays draw.

- [ ] **Step 6: Commit**

```bash
git add PropertyAtlas/Studio/Layers/ PropertyAtlas/Map/MapKitView.swift PropertyAtlas/Map/MapContainerView.swift PropertyAtlas/RootView.swift
git commit -m "feat(studio): wire zones+schools into MapKit overlays/annotations"
```

---

## Phase 6 — Studio overlay UI

### Task 15: `StudioTitleCard`, `StudioLegend`, `StudioWatermark`

**Files:**
- Create: `PropertyAtlas/Studio/StudioTitleCard.swift`
- Create: `PropertyAtlas/Studio/StudioLegend.swift`
- Create: `PropertyAtlas/Studio/StudioWatermark.swift`

- [ ] **Step 1: TitleCard**

Create `PropertyAtlas/Studio/StudioTitleCard.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioTitleCard: View {
    @Binding var title: String
    @Binding var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("标题", text: $title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 181/255, green: 112/255, blue: 58/255))
                .textFieldStyle(.plain)
            TextField("副标题", text: $subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
#endif
```

- [ ] **Step 2: Legend**

Create `PropertyAtlas/Studio/StudioLegend.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioLegend: View {
    let tiers: [(name: String, color: Color)] = [
        ("顶尖", Color(red: 201/255, green: 155/255, blue: 44/255)),
        ("优质", Color(red: 91/255, green: 124/255, blue: 156/255)),
        ("普通", Color(red: 156/255, green: 150/255, blue: 139/255)),
        ("薄弱", Color(red: 184/255, green: 115/255, blue: 107/255)),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("学校梯队").font(.system(size: 14, weight: .semibold))
            ForEach(tiers, id: \.name) { t in
                HStack(spacing: 6) {
                    Circle().fill(t.color).frame(width: 12, height: 12)
                    Text(t.name).font(.system(size: 13))
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
#endif
```

- [ ] **Step 3: Watermark**

Create `PropertyAtlas/Studio/StudioWatermark.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioWatermark: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.black.opacity(0.4))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.white.opacity(0.6), in: Capsule())
    }
}
#endif
```

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/Studio/StudioTitleCard.swift PropertyAtlas/Studio/StudioLegend.swift PropertyAtlas/Studio/StudioWatermark.swift
git commit -m "feat(studio): title card + legend + watermark components"
```

---

### Task 16: `CameraPresets` seed data

**Files:**
- Create: `PropertyAtlas/Studio/CameraPresets.swift`
- Create: `PropertyAtlasTests/Studio/CameraPresetsTests.swift`

- [ ] **Step 1: Write failing test**

Create `PropertyAtlasTests/Studio/CameraPresetsTests.swift`:

```swift
#if targetEnvironment(macCatalyst)
import Testing
import CoreLocation
@testable import PropertyAtlas

@Suite("CameraPresets")
struct CameraPresetsTests {
    @Test("seed contains all 6 inner districts")
    func sixDistricts() {
        let names = CameraPresets.seed.map(\.name)
        for d in ["和平区", "河西区", "南开区", "河东区", "河北区", "红桥区"] {
            #expect(names.contains(d))
        }
    }

    @Test("all preset centers within Tianjin bbox")
    func bboxValid() {
        for p in CameraPresets.seed {
            #expect((38.5...40.3).contains(p.center.latitude))
            #expect((116.7...118.0).contains(p.center.longitude))
        }
    }
}
#endif
```

- [ ] **Step 2: Run, expect fail**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/CameraPresetsTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `PropertyAtlas/Studio/CameraPresets.swift`:

```swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit

struct CameraPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let center: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let pitch: CGFloat
    let heading: CLLocationDirection
    var camera: MKMapCamera {
        MKMapCamera(lookingAtCenter: center, fromDistance: distance, pitch: pitch, heading: heading)
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (l: CameraPreset, r: CameraPreset) -> Bool { l.id == r.id }
}

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude); hasher.combine(longitude)
    }
    public static func == (l: CLLocationCoordinate2D, r: CLLocationCoordinate2D) -> Bool {
        l.latitude == r.latitude && l.longitude == r.longitude
    }
}

enum CameraPresets {
    static let seed: [CameraPreset] = [
        .init(id: "和平区",  name: "和平区",  center: .init(latitude: 39.125, longitude: 117.205), distance: 12000, pitch: 0, heading: 0),
        .init(id: "河西区",  name: "河西区",  center: .init(latitude: 39.110, longitude: 117.225), distance: 18000, pitch: 0, heading: 0),
        .init(id: "南开区",  name: "南开区",  center: .init(latitude: 39.130, longitude: 117.150), distance: 18000, pitch: 0, heading: 0),
        .init(id: "河东区",  name: "河东区",  center: .init(latitude: 39.125, longitude: 117.235), distance: 18000, pitch: 0, heading: 0),
        .init(id: "河北区",  name: "河北区",  center: .init(latitude: 39.155, longitude: 117.205), distance: 18000, pitch: 0, heading: 0),
        .init(id: "红桥区",  name: "红桥区",  center: .init(latitude: 39.165, longitude: 117.155), distance: 18000, pitch: 0, heading: 0),
    ]
}
#endif
```

- [ ] **Step 4: Run, expect pass**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/CameraPresetsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/Studio/CameraPresets.swift PropertyAtlasTests/Studio/CameraPresetsTests.swift
git commit -m "feat(studio): 6 district CameraPresets (101-zone presets pending)"
```

---

### Task 17: `StudioOverlay` composing title/legend/watermark + assembly into `StudioRootView`

**Files:**
- Create: `PropertyAtlas/Studio/StudioOverlay.swift`
- Modify: `PropertyAtlas/RootView.swift`

- [ ] **Step 1: Implement overlay**

Create `PropertyAtlas/Studio/StudioOverlay.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI

struct StudioOverlay: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var watermark: String
    var includeToolbar: Bool = true

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    StudioTitleCard(title: $title, subtitle: $subtitle)
                    Spacer()
                    StudioLegend()
                }.padding(16)
                Spacer()
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    StudioWatermark(text: watermark)
                }.padding(16)
            }
            // StudioToolbar added in Task 21
        }
    }
}
#endif
```

- [ ] **Step 2: Wire into `StudioRootView`**

Modify `StudioRootView` (in `RootView.swift`):

```swift
#if targetEnvironment(macCatalyst)
struct StudioRootView: View {
    @Query private var zones: [SchoolZone]
    @Query private var schools: [School]
    @State private var title: String = "天津学区地图"
    @State private var subtitle: String = "2026 招生季"
    @State private var watermark: String = "@公众号名 · PropertyAtlas"

    var body: some View {
        let overlays = zones.compactMap { try? ZoneGeometryImporter.makeOverlay(for: $0, imageProvider: ZoneGeometryImporter.bundledImage(named:)) }
        let pins = schools.filter { $0.lat != nil && $0.lon != nil }.map { SchoolAnnotation(school: $0) }

        ZStack {
            MapContainerView(overlays: overlays, annotations: pins).ignoresSafeArea()
            StudioOverlay(title: $title, subtitle: $subtitle, watermark: $watermark)
        }
    }
}
#endif
```

- [ ] **Step 3: Build + visual smoke**

Run: `xcodebuild ... -destination 'platform=macOS,variant=Mac Catalyst' build`
Expected: builds. Launch the app, toggle to Studio mode (Task 25 wires the shortcut; until then default `.studio` for visual check).

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/Studio/StudioOverlay.swift PropertyAtlas/RootView.swift
git commit -m "feat(studio): StudioOverlay composes title/legend/watermark"
```

---

## Phase 7 — Snapshot export

### Task 18: `CanvasAspect` enum

**Files:**
- Create: `PropertyAtlas/Studio/Snapshot/CanvasAspect.swift`

- [ ] **Step 1: Implement**

Create `PropertyAtlas/Studio/Snapshot/CanvasAspect.swift`:

```swift
#if targetEnvironment(macCatalyst)
import CoreGraphics

enum CanvasAspect: String, CaseIterable, Identifiable {
    case ratio16x9 = "16:9"
    case ratio1x1  = "1:1"
    case ratio4x5  = "4:5"
    case ratio9x16 = "9:16"
    case ratio3x4  = "3:4"
    case ratio2x1  = "2:1"
    var id: String { rawValue }

    /// Returns pixel size for the chosen aspect at "4K-ish" sizing (long edge 3840).
    var pixelSize: CGSize {
        switch self {
        case .ratio16x9: return CGSize(width: 3840, height: 2160)
        case .ratio1x1:  return CGSize(width: 2560, height: 2560)
        case .ratio4x5:  return CGSize(width: 2560, height: 3200)
        case .ratio9x16: return CGSize(width: 2160, height: 3840)
        case .ratio3x4:  return CGSize(width: 2560, height: 3413)
        case .ratio2x1:  return CGSize(width: 3840, height: 1920)
        }
    }
}
#endif
```

- [ ] **Step 2: Commit**

```bash
git add PropertyAtlas/Studio/Snapshot/CanvasAspect.swift
git commit -m "feat(studio): CanvasAspect enum (6 aspects, long edge 3840)"
```

---

### Task 19: `SnapshotExporter`

**Files:**
- Create: `PropertyAtlas/Studio/Snapshot/SnapshotExporter.swift`
- Create: `PropertyAtlasTests/Studio/SnapshotExporterTests.swift`

- [ ] **Step 1: Write failing test**

Create `PropertyAtlasTests/Studio/SnapshotExporterTests.swift`:

```swift
#if targetEnvironment(macCatalyst)
import Testing
@testable import PropertyAtlas

@Suite("SnapshotExporter")
struct SnapshotExporterTests {
    @Test("file name pattern includes district + timestamp")
    func filename() {
        let name = SnapshotExporter.makeFilename(district: "和平区", date: Date(timeIntervalSince1970: 1716700000))
        #expect(name.hasPrefix("和平区学片图_"))
        #expect(name.hasSuffix(".png"))
    }

    @Test("aspect 16:9 → 3840x2160")
    func aspectSize() {
        #expect(CanvasAspect.ratio16x9.pixelSize.width == 3840)
        #expect(CanvasAspect.ratio16x9.pixelSize.height == 2160)
    }
}
#endif
```

- [ ] **Step 2: Run, expect fail**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/SnapshotExporterTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `PropertyAtlas/Studio/Snapshot/SnapshotExporter.swift`:

```swift
#if targetEnvironment(macCatalyst)
import MapKit
import SwiftUI
import UIKit

enum SnapshotExporter {
    static func makeFilename(district: String, date: Date = Date()) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmm"
        return "\(district)学片图_\(df.string(from: date)).png"
    }

    static func outputDirectory() -> URL {
        let dir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PropertyAtlas", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Snapshots the given map view + SwiftUI overlay into one image, writes to ~/Pictures/PropertyAtlas/.
    static func export(camera: MKMapCamera,
                       overlays: [MKOverlay],
                       annotations: [MKAnnotation],
                       aspect: CanvasAspect,
                       overlayView: some View,
                       district: String,
                       completion: @escaping (Result<URL, Error>) -> Void) {
        let opts = MKMapSnapshotter.Options()
        opts.camera = camera
        opts.size = aspect.pixelSize
        opts.mapType = .mutedStandard
        let snapshotter = MKMapSnapshotter(options: opts)
        snapshotter.start { snapshot, err in
            guard let snap = snapshot else { completion(.failure(err ?? NSError(domain: "snap", code: 0))); return }
            UIGraphicsBeginImageContextWithOptions(snap.image.size, true, 1.0)
            snap.image.draw(at: .zero)
            // TODO: render annotations + raster overlays into context (Map snapshotter does NOT render custom overlays)
            // For Studio MVP, this is acceptable — pins and raster overlay will be re-drawn via a second pass below
            // (Documented limitation; iterate in v0.2)
            // Render SwiftUI overlay using ImageRenderer
            let renderer = ImageRenderer(content: overlayView.frame(width: snap.image.size.width, height: snap.image.size.height))
            renderer.scale = 1.0
            if let uiImage = renderer.uiImage {
                uiImage.draw(at: .zero, blendMode: .normal, alpha: 1.0)
            }
            let combined = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            guard let combined, let data = combined.pngData() else {
                completion(.failure(NSError(domain: "snap", code: 1)))
                return
            }
            let url = outputDirectory().appendingPathComponent(makeFilename(district: district))
            do { try data.write(to: url); completion(.success(url)) }
            catch { completion(.failure(error)) }
        }
    }
}
#endif
```

**Note for engineer:** `MKMapSnapshotter` does **not** render custom `MKOverlay` subclasses (CalibratedImageOverlay) or `MKAnnotationView`s. For Stage A raster + pins to appear in the snapshot, a second pass is needed: re-draw raster + pins onto the combined context using the same coordinate conversion as the live map. This is acceptable to defer to v0.2 — the MVP snapshot will include basemap + SwiftUI overlay correctly; raster/pins TBD.

- [ ] **Step 4: Run test, expect pass**

Run: `xcodebuild ... test -only-testing:PropertyAtlasTests/SnapshotExporterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/Studio/Snapshot/SnapshotExporter.swift PropertyAtlasTests/Studio/SnapshotExporterTests.swift
git commit -m "feat(studio): SnapshotExporter (basemap + SwiftUI overlay; raster/pins v0.2)"
```

---

## Phase 8 — Toolbar + actions wiring

### Task 20: `StudioToolbar` (preset / layers / canvas / snapshot)

**Files:**
- Create: `PropertyAtlas/Studio/StudioToolbar.swift`
- Modify: `PropertyAtlas/Studio/StudioOverlay.swift` (add toolbar)
- Modify: `PropertyAtlas/RootView.swift` (`StudioRootView` holds toolbar state + wires snapshot)

- [ ] **Step 1: Implement toolbar**

Create `PropertyAtlas/Studio/StudioToolbar.swift`:

```swift
#if targetEnvironment(macCatalyst)
import SwiftUI
import MapKit

struct StudioToolbar: View {
    @Binding var selectedPreset: CameraPreset
    @Binding var aspect: CanvasAspect
    @Binding var showZoneFill: Bool
    @Binding var showSchoolPins: Bool
    @Binding var showSchoolLabels: Bool
    @Binding var granularity: SchoolGranularity
    let onSnapshot: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu("🎯 \(selectedPreset.name)") {
                ForEach(CameraPresets.seed) { p in
                    Button(p.name) { selectedPreset = p }
                }
            }
            Divider().frame(height: 20)
            Menu("🗺️ 图层") {
                Toggle("学片色块", isOn: $showZoneFill)
                Toggle("学校 Pin", isOn: $showSchoolPins)
                Toggle("学校名", isOn: $showSchoolLabels)
            }
            Menu("🎚️ \(granularity.label)") {
                ForEach(SchoolGranularity.allCases) { g in
                    Button(g.label) { granularity = g }
                }
            }
            Menu("📐 \(aspect.rawValue)") {
                ForEach(CanvasAspect.allCases) { a in
                    Button(a.rawValue) { aspect = a }
                }
            }
            Divider().frame(height: 20)
            Button { onSnapshot() } label: { Text("📸 截屏") }
                .keyboardShortcut("e", modifiers: .command)
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

enum SchoolGranularity: String, CaseIterable, Identifiable {
    case all = "all", marketKey = "marketKey", middleOnly = "middle", primaryOnly = "primary"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "全部"
        case .marketKey: return "仅市重点"
        case .middleOnly: return "仅中学"
        case .primaryOnly: return "仅小学"
        }
    }
}
#endif
```

- [ ] **Step 2: Wire into overlay**

Modify `StudioOverlay`:

```swift
#if targetEnvironment(macCatalyst)
struct StudioOverlay: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var watermark: String
    @Binding var selectedPreset: CameraPreset
    @Binding var aspect: CanvasAspect
    @Binding var showZoneFill: Bool
    @Binding var showSchoolPins: Bool
    @Binding var showSchoolLabels: Bool
    @Binding var granularity: SchoolGranularity
    let onSnapshot: () -> Void

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    StudioTitleCard(title: $title, subtitle: $subtitle)
                    Spacer()
                    StudioLegend()
                }.padding(16)
                Spacer()
            }
            VStack {
                Spacer()
                StudioToolbar(
                    selectedPreset: $selectedPreset, aspect: $aspect,
                    showZoneFill: $showZoneFill, showSchoolPins: $showSchoolPins,
                    showSchoolLabels: $showSchoolLabels, granularity: $granularity,
                    onSnapshot: onSnapshot
                )
                .padding(.bottom, 24)
            }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    StudioWatermark(text: watermark)
                }.padding(16)
            }
        }
    }
}
#endif
```

- [ ] **Step 3: Wire `StudioRootView` to drive state + snapshot**

```swift
#if targetEnvironment(macCatalyst)
struct StudioRootView: View {
    @Query private var zones: [SchoolZone]
    @Query private var schools: [School]
    @State private var title: String = "和平区学区分布图"
    @State private var subtitle: String = "2026 招生季"
    @State private var watermark: String = "@公众号名 · PropertyAtlas"
    @State private var selectedPreset: CameraPreset = CameraPresets.seed[0]
    @State private var aspect: CanvasAspect = .ratio16x9
    @State private var showZoneFill = true
    @State private var showSchoolPins = true
    @State private var showSchoolLabels = true
    @State private var granularity: SchoolGranularity = .all

    var body: some View {
        let filteredSchools = filter(schools)
        let overlays: [MKOverlay] = showZoneFill
            ? zones.compactMap { try? ZoneGeometryImporter.makeOverlay(for: $0, imageProvider: ZoneGeometryImporter.bundledImage(named:)) }
            : []
        let pins: [MKAnnotation] = showSchoolPins
            ? filteredSchools.filter { $0.lat != nil && $0.lon != nil }.map { SchoolAnnotation(school: $0) }
            : []

        ZStack {
            MapContainerView(overlays: overlays, annotations: pins).ignoresSafeArea()
            StudioOverlay(
                title: $title, subtitle: $subtitle, watermark: $watermark,
                selectedPreset: $selectedPreset, aspect: $aspect,
                showZoneFill: $showZoneFill, showSchoolPins: $showSchoolPins,
                showSchoolLabels: $showSchoolLabels, granularity: $granularity,
                onSnapshot: snapshot
            )
        }
    }

    private func filter(_ items: [School]) -> [School] {
        switch granularity {
        case .all: return items
        case .marketKey: return items.filter { $0.tier == "顶尖" || $0.tier == "优质" }
        case .middleOnly: return items.filter { $0.type == "中学" || $0.type == "九年一贯" }
        case .primaryOnly: return items.filter { $0.type == "小学" }
        }
    }

    private func snapshot() {
        let overlayView = StudioOverlay(
            title: .constant(title), subtitle: .constant(subtitle),
            watermark: .constant(watermark),
            selectedPreset: .constant(selectedPreset), aspect: .constant(aspect),
            showZoneFill: .constant(showZoneFill), showSchoolPins: .constant(showSchoolPins),
            showSchoolLabels: .constant(showSchoolLabels), granularity: .constant(granularity),
            onSnapshot: {}
        )
        SnapshotExporter.export(
            camera: selectedPreset.camera,
            overlays: [],   // raster/pins TBD in v0.2 (see SnapshotExporter note)
            annotations: [],
            aspect: aspect,
            overlayView: overlayView,
            district: selectedPreset.name
        ) { result in
            switch result {
            case .success(let url): print("✓ saved \(url.path)")
            case .failure(let e):   print("✗ snapshot failed: \(e)")
            }
        }
    }
}
#endif
```

- [ ] **Step 4: Build + smoke**

Run: `xcodebuild ... -destination 'platform=macOS,variant=Mac Catalyst' build`
Expected: builds, toolbar visible in Studio mode.

- [ ] **Step 5: Commit**

```bash
git add PropertyAtlas/Studio/StudioToolbar.swift PropertyAtlas/Studio/StudioOverlay.swift PropertyAtlas/RootView.swift
git commit -m "feat(studio): toolbar — preset/layers/aspect/granularity/snapshot"
```

---

## Phase 9 — Keyboard shortcuts + menu commands

### Task 21: `⌘⇧S` toggle + `⌘1..⌘6` district jumps

**Files:**
- Modify: `PropertyAtlas/PropertyAtlasApp.swift`
- Modify: `PropertyAtlas/RootView.swift`

- [ ] **Step 1: Add menu commands to App scene**

Modify `PropertyAtlas/PropertyAtlasApp.swift`:

```swift
var body: some Scene {
    WindowGroup {
        Group {
            if seedDone {
                RootView().environment(selectionState).environment(appMode)
            } else {
                SeedProgressView(onComplete: { seedDone = true })
            }
        }
    }
    .modelContainer(container)
    .commands {
        CommandMenu("View") {
            Button("Studio Mode") { appMode.toggle() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        #if targetEnvironment(macCatalyst)
        CommandMenu("Studio") {
            ForEach(Array(CameraPresets.seed.prefix(6).enumerated()), id: \.offset) { (i, p) in
                Button(p.name) {
                    NotificationCenter.default.post(name: .studioPresetSelected, object: p)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(i+1)")), modifiers: .command)
            }
        }
        #endif
    }
}
```

Add at file top:

```swift
extension Notification.Name {
    static let studioPresetSelected = Notification.Name("studioPresetSelected")
}
```

- [ ] **Step 2: `StudioRootView` listens for preset selection**

In `StudioRootView`, add:

```swift
.onReceive(NotificationCenter.default.publisher(for: .studioPresetSelected)) { note in
    if let p = note.object as? CameraPreset { selectedPreset = p }
}
```

- [ ] **Step 3: Build + manual test of shortcuts**

Run: app in Mac Catalyst. Test `⌘⇧S` toggle, `⌘1..⌘6` jumps, `⌘E` snapshot.
Expected: all shortcuts work.

- [ ] **Step 4: Commit**

```bash
git add PropertyAtlas/PropertyAtlasApp.swift PropertyAtlas/RootView.swift
git commit -m "feat(studio): keyboard shortcuts ⌘⇧S / ⌘1..6 / ⌘E"
```

---

## Phase 10 — Wrap

### Task 22: Update CLAUDE.md with Studio pipeline

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Append Studio section**

Add to `CLAUDE.md` after the "完整数据重建流水线" subsection:

```markdown
## Studio Mode (Mac Catalyst)

Studio Mode produces high-fidelity screenshots of school-district maps for content creation. Triggered by `⌘⇧S`. Mac Catalyst only — iPad/iPhone builds skip the Studio module entirely via `#if targetEnvironment(macCatalyst)`.

### Data prerequisites
- `schools.json` items must have `lat/lon` — run `swift scripts/geocode_schools.swift` once.
- `zones.json` items must have `geometry_stage` + `geometry`:
  - Stage A (raster, hand-aligned): `swift run Calibrator <district>` in `scripts/calibrate_raster/`
  - Stage B (convex/alpha hull): `python3 scripts/build_zone_hulls.py`
  - Stage C (street-level GeoJSON): future

### Studio output
- 4K PNG snapshots → `~/Pictures/PropertyAtlas/<district>学片图_<YYYYMMDD_HHmm>.png`
- 6 canvas aspects: 16:9 / 1:1 / 4:5 / 9:16 / 3:4 / 2:1

### Spec
`docs/superpowers/specs/2026-05-26-studio-mode-design.md`

### Plan
`docs/superpowers/plans/2026-05-26-studio-mode.md`
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude): document Studio Mode pipeline + prerequisites"
```

---

### Task 23: Manual acceptance test checklist (run + sign off)

**Files:** none (manual)

- [ ] **Step 1: Run through this checklist on Mac Catalyst build**

```
[ ] App opens in Explore mode by default (iPad-style layout)
[ ] ⌘⇧S toggles Studio mode (full-screen map + floating overlay)
[ ] ⌘1 jumps to 和平区; ⌘2..⌘6 jump to other inner districts
[ ] Toolbar appears at bottom; menus open
[ ] Aspect selector cycles through 6 ratios (no visible change to live view; affects snapshot only)
[ ] Layer toggles hide/show zone fills, school pins, school labels
[ ] Granularity filter narrows the visible pin set
[ ] ⌘E (or 📸 button) writes a PNG to ~/Pictures/PropertyAtlas/<district>学片图_*.png
[ ] PNG opens; contains basemap + SwiftUI overlay (title/legend/watermark) at correct aspect pixel size
[ ] iPad build still launches in Explore mode and has no Studio code paths
[ ] Switching modes does not crash, lose ModelContainer state, or trigger CloudKit sync churn
```

- [ ] **Step 2: Capture results in a one-line commit**

```bash
git commit --allow-empty -m "test(studio): manual acceptance checklist passed (or note exceptions)"
```

---

## Summary

Total tasks: **23** (including 1 sub-task in Phase 3 calibrator UI).
Estimated effort: **~10 working days** per spec §10.

**Out of MVP** (deferred):
- 95 remaining `CameraPreset` entries for the 101 zones (only 6 districts seeded; full 101-zone seed = a later script)
- Snapshot rendering of `CalibratedImageOverlay` and `MKAnnotationView` (see Task 19 note)
- Stage C street-level GeoJSON
- 楼盘 pins (图层 E)
- 集团连线 (图层 C)
- 中考梯队热力 (图层 D)
- 居委会划片 (图层 F)
- 楼盘 geocoding script (parallel; not blocking MVP)
- 18 district raster PNG asset preparation (manual PDF export, ~1.5 days outside this code plan)
