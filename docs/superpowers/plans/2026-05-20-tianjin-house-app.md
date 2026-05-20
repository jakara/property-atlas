# 北漂天津置业地图 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iPad-first SwiftUI property research app for Beijing expats buying in Tianjin — school district polygon map, visit recording wizard, CloudKit sync.

**Architecture:** Golden-ratio split (61.8% MapKit left / 38.2% drawer right). Three drawer tabs: Schools / Visits / Zones. Public data (compounds, schools, school-zone polygons) loaded from bundled JSON on first launch. Private data (visits, marks, user areas) syncs via CloudKit Private DB. No in-app editing of public data — updates go through offline SeedExtractor tool + re-bundle.

**Tech Stack:** SwiftUI, MapKit (iOS 17+ native API), SwiftData + CloudKit Private DB, Swift Testing, turf-swift (Douglas-Peucker polygon simplification), iOS 17+

---

## File Map

```
TianjinHouse/
├── TianjinHouseApp.swift           App entry, ModelContainer init
├── RootView.swift                  ZStack: full-screen map + floating toolbar + drawer overlays
├── Extensions/
│   └── Color+Hex.swift             Color(hex:) initializer used across all tier/status colors
├── Models/
│   ├── Public/
│   │   ├── SchoolZone.swift        @Model: zone polygon + tier
│   │   ├── Compound.swift          @Model: compound + zoneId + primarySchoolId
│   │   ├── School.swift            @Model: school + zoneId
│   │   ├── SchoolScore.swift       @Model: annual exam ranking
│   │   ├── AdmissionDoc.swift      @Model: policy document reference
│   │   └── BuiltinTag.swift        @Model: preset tag library
│   ├── User/
│   │   ├── PropertyMark.swift      @Model: compound bookmark + status
│   │   ├── Visit.swift             @Model: visit record + ratings
│   │   ├── Photo.swift             @Model: visit photo (CKAsset)
│   │   ├── TagExtension.swift      @Model: user-created tags
│   │   ├── VisitTag.swift          @Model: visit ↔ tag join
│   │   ├── UserArea.swift          @Model: user-drawn polygon
│   │   └── ShareSubmission.swift   @Model: future contribution queue
│   └── Local/
│       └── AppSettings.swift       UserDefaults wrapper (no CloudKit)
├── Map/
│   ├── MapContainerView.swift      Map + overlays + camera binding
│   ├── SchoolZoneOverlay.swift     MapPolygon per zone, tier-colored
│   ├── CompoundAnnotationView.swift Pin dot, color by PropertyMark status
│   ├── MapFiltersView.swift        Layer toggle popover
│   └── PolygonEditorView.swift     Tap-to-add vertex → UserArea
├── Drawer/
│   ├── DrawerContainerView.swift   Tab switcher + search bar
│   ├── SchoolTabView.swift         School card list
│   ├── VisitTabView.swift          Visit card list (grouped by status)
│   ├── ZoneTabView.swift           UserArea list
│   └── SearchResultsView.swift     Filtered results in drawer
├── Detail/
│   ├── CompoundDetailView.swift    POI detail (zone, school, marks)
│   ├── SchoolDetailView.swift      School + zone info + score history
│   └── VisitWizardView.swift       4-step visit form (in drawer)
├── Components/
│   ├── TagPickerView.swift         Category-grouped tag chips
│   ├── StarRatingView.swift        Tappable 1-5 star row
│   └── EmptyStateView.swift        Reusable icon+title+subtitle+CTA
├── States/
│   ├── SeedProgressView.swift      First-launch fullscreen seed progress
│   ├── CloudKitGateView.swift      iCloud-not-signed-in overlay on drawer
│   └── OfflineBannerView.swift     Map-top pill when offline
├── Seed/
│   ├── SeedImporter.swift          JSON → SwiftData on first launch
│   └── SeedData/                   Bundled JSON files (see Task 5)
└── ViewModels/
    └── MapSelectionState.swift     @Observable shared map↔drawer state

TianjinHouseTests/
├── GeoJSONTests.swift
├── SeedImporterTests.swift
├── SchoolZoneQueryTests.swift
└── PolygonSimplificationTests.swift

Scripts/SeedExtractor/             Separate Swift CLI — Task 5
├── Package.swift
└── Sources/SeedExtractor/main.swift
```

---

## Task 1: Xcode Project + Dependencies

**Files:**
- Create: Xcode project `TianjinHouse.xcodeproj` (via Xcode UI)
- Create: `TianjinHouseTests/` test target

- [ ] **Step 1: Create project**

In Xcode → File → New → Project:
- Template: App
- Product Name: `TianjinHouse`
- Bundle ID: `com.yourname.tianjinhouse`
- Interface: SwiftUI
- Language: Swift
- Storage: ✅ SwiftData
- ✅ Include Tests

- [ ] **Step 2: Add iCloud + CloudKit capability**

In Xcode → TianjinHouse target → Signing & Capabilities:
- Click `+` → iCloud → check **CloudKit**
- Under Containers: add `iCloud.com.yourname.tianjinhouse`
- Click `+` → **Push Notifications** (required by CloudKit sync)

- [ ] **Step 3: Add turf-swift SPM dependency**

File → Add Package Dependencies:
URL: `https://github.com/mapbox/turf-swift`
Version: Up to Next Major from `2.0.0`
Add to TianjinHouse target.

- [ ] **Step 4: Add Info.plist keys**

In TianjinHouse target → Info, add:
```
NSLocationWhenInUseUsageDescription  → "定位用于在地图上显示当前位置"
NSCameraUsageDescription             → "拍摄看房照片"
NSPhotoLibraryUsageDescription       → "从相册选取看房照片"
NSUbiquitousKeyValueStoreUsageDescription → "同步应用设置"
```

- [ ] **Step 5: Verify build**

Run: `Cmd+B`
Expected: Build Succeeded, 0 errors.

- [ ] **Step 6: Commit**
```bash
git init
git add .
git commit -m "feat: initial Xcode project with CloudKit + turf-swift"
```

---

## Task 2: Public @Model Entities

**Files:**
- Create: `TianjinHouse/Models/Public/SchoolZone.swift`
- Create: `TianjinHouse/Models/Public/School.swift`
- Create: `TianjinHouse/Models/Public/Compound.swift`
- Create: `TianjinHouse/Models/Public/SchoolScore.swift`
- Create: `TianjinHouse/Models/Public/AdmissionDoc.swift`
- Create: `TianjinHouse/Models/Public/BuiltinTag.swift`
- Create: `TianjinHouseTests/GeoJSONTests.swift`

- [ ] **Step 1: Write failing GeoJSON test**

```swift
// TianjinHouseTests/GeoJSONTests.swift
import Testing
import CoreLocation

struct GeoJSONTests {
    @Test func polygonCoordinatesRoundtrip() throws {
        let geojson = """
        {"type":"Polygon","coordinates":[[[117.15,39.10],[117.16,39.10],[117.16,39.11],[117.15,39.10]]]}
        """
        let coords = try GeoJSONHelper.decodePolygon(geojson)
        #expect(coords.count == 4)
        #expect(abs(coords[0].longitude - 117.15) < 0.0001)
        #expect(abs(coords[0].latitude - 39.10) < 0.0001)
    }
}
```

- [ ] **Step 2: Run test — expect FAIL** (GeoJSONHelper not defined)

- [ ] **Step 3: Create SchoolZone.swift**

```swift
// TianjinHouse/Models/Public/SchoolZone.swift
import SwiftData
import CoreLocation

@Model
final class SchoolZone {
    var id: UUID = UUID()
    var name: String = ""
    var tier: String = "普通"          // 顶尖/优质/普通/薄弱
    var primaryDistrict: String = ""
    var geometry: String = ""          // GeoJSON Polygon string
    var geometrySimplified: String?
    var residencyYears: Int?
    var strokeColorHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), name: String, tier: String = "普通",
         primaryDistrict: String, geometry: String) {
        self.id = id
        self.name = name
        self.tier = tier
        self.primaryDistrict = primaryDistrict
        self.geometry = geometry
    }

    var decodedCoordinates: [CLLocationCoordinate2D] {
        (try? GeoJSONHelper.decodePolygon(geometry)) ?? []
    }
}

// GeoJSONHelper lives here — used by SchoolZone + UserArea
enum GeoJSONHelper {
    static func decodePolygon(_ geojson: String) throws -> [CLLocationCoordinate2D] {
        guard let data = geojson.data(using: .utf8) else {
            throw GeoJSONError.invalidUTF8
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let coords = dict["coordinates"] as? [[[Double]]],
              let ring = coords.first else {
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

- [ ] **Step 4: Create School.swift**

```swift
// TianjinHouse/Models/Public/School.swift
import SwiftData

@Model
final class School {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = "小学"           // 小学/初中
    var zoneId: UUID?                   // FK → SchoolZone.id
    var district: String = ""
    var tier: String = "普通"
    var motto: String?
    var websiteUrl: String?
    var foundedYear: Int?
    var isPublicSchool: Bool = true
    var notes: String?
    var sourceUrl: String?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), name: String, type: String,
         zoneId: UUID? = nil, district: String, tier: String = "普通") {
        self.id = id; self.name = name; self.type = type
        self.zoneId = zoneId; self.district = district; self.tier = tier
    }
}
```

- [ ] **Step 5: Create Compound.swift**

```swift
// TianjinHouse/Models/Public/Compound.swift
import SwiftData

@Model
final class Compound {
    var id: UUID = UUID()
    var amapPoiId: String?
    var name: String = ""
    var aliases: [String] = []
    var district: String = ""
    var streetBlock: String?
    var address: String = ""
    var latitude: Double = 39.1
    var longitude: Double = 117.2
    var zoneId: UUID?                   // FK → SchoolZone.id
    var primarySchoolId: UUID?          // FK → School.id (小学 single assignment)
    var buildYear: Int?
    var developer: String?
    var propertyMgmt: String?
    var totalBuildings: Int?
    var greeningRatio: Double?
    var parkingRatio: Double?
    var propertyFeeCents: Int?
    var landYears: Int?
    var sourceUrl: String?
    var contributedBy: String?
    var verifiedAt: Date?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), name: String, district: String,
         latitude: Double, longitude: Double) {
        self.id = id; self.name = name; self.district = district
        self.latitude = latitude; self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
```

- [ ] **Step 6: Create remaining pub_* models**

```swift
// TianjinHouse/Models/Public/SchoolScore.swift
import SwiftData

@Model final class SchoolScore {
    var id: UUID = UUID()
    var schoolId: UUID = UUID()
    var year: Int = 2024
    var rankCity: Int?
    var topPercentile: Double?
    var rawJson: String?
    var createdAt: Date = Date()

    init(id: UUID = UUID(), schoolId: UUID, year: Int) {
        self.id = id; self.schoolId = schoolId; self.year = year
    }
}

// TianjinHouse/Models/Public/AdmissionDoc.swift
@Model final class AdmissionDoc {
    var id: UUID = UUID()
    var title: String = ""
    var district: String = ""
    var year: Int = 2024
    var docType: String = "招生简章"    // 招生简章/学区图/政策文件
    var sourceUrl: String?
    var ocrText: String?
    var createdAt: Date = Date()

    init(id: UUID = UUID(), title: String, district: String, year: Int) {
        self.id = id; self.title = title; self.district = district; self.year = year
    }
}

// TianjinHouse/Models/Public/BuiltinTag.swift
@Model final class BuiltinTag {
    var id: UUID = UUID()
    var category: String = ""          // 采光/噪音/气味/物业/邻里/装修
    var label: String = ""
    var polarity: String = "中"        // 正/负/中
    var sortOrder: Int = 0
    var version: Int = 1

    init(id: UUID = UUID(), category: String, label: String, polarity: String = "中") {
        self.id = id; self.category = category; self.label = label; self.polarity = polarity
    }
}
```

- [ ] **Step 7: Run GeoJSON test — expect PASS**

Run: `Cmd+U` → filter to `GeoJSONTests`
Expected: `polygonCoordinatesRoundtrip` → PASS ✓

- [ ] **Step 8: Commit**
```bash
git add TianjinHouse/Models/Public/ TianjinHouseTests/GeoJSONTests.swift
git commit -m "feat: pub_* @Model entities + GeoJSONHelper"
```

---

## Task 3: User + Local @Model Entities + Query Logic Tests

**Files:**
- Create: `TianjinHouse/Models/User/PropertyMark.swift`
- Create: `TianjinHouse/Models/User/Visit.swift`
- Create: `TianjinHouse/Models/User/Photo.swift`
- Create: `TianjinHouse/Models/User/TagExtension.swift`
- Create: `TianjinHouse/Models/User/VisitTag.swift`
- Create: `TianjinHouse/Models/User/UserArea.swift`
- Create: `TianjinHouse/Models/User/ShareSubmission.swift`
- Create: `TianjinHouse/Models/Local/AppSettings.swift`
- Create: `TianjinHouseTests/SchoolZoneQueryTests.swift`

- [ ] **Step 1: Write failing query tests**

```swift
// TianjinHouseTests/SchoolZoneQueryTests.swift
import Testing
import SwiftData

@MainActor
struct SchoolZoneQueryTests {
    var container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: SchoolZone.self, School.self, Compound.self,
                                   configurations: config)
    }()

    @Test func primarySchoolLookup() throws {
        let ctx = container.mainContext
        let zone = SchoolZone(name: "和平一区", tier: "顶尖", primaryDistrict: "和平区",
                              geometry: #"{"type":"Polygon","coordinates":[[[117.2,39.1],[117.3,39.1],[117.3,39.2],[117.2,39.1]]]}"#)
        let school = School(name: "实验小学", type: "小学", zoneId: zone.id, district: "和平区", tier: "顶尖")
        let compound = Compound(name: "珑璟台", district: "和平区", latitude: 39.15, longitude: 117.25)
        compound.zoneId = zone.id
        compound.primarySchoolId = school.id
        ctx.insert(zone); ctx.insert(school); ctx.insert(compound)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<School>(
            predicate: #Predicate { $0.id == compound.primarySchoolId! }
        ))
        #expect(fetched.first?.name == "实验小学")
    }

    @Test func middleSchoolsInZone() throws {
        let ctx = container.mainContext
        let zone = SchoolZone(name: "南开一区", tier: "优质", primaryDistrict: "南开区",
                              geometry: #"{"type":"Polygon","coordinates":[[[117.1,39.0],[117.2,39.0],[117.2,39.1],[117.1,39.0]]]}"#)
        let ms1 = School(name: "南开中学", type: "初中", zoneId: zone.id, district: "南开区", tier: "顶尖")
        let ms2 = School(name: "实验中学", type: "初中", zoneId: zone.id, district: "南开区", tier: "优质")
        let ps  = School(name: "万全道小学", type: "小学", zoneId: zone.id, district: "南开区")
        ctx.insert(zone); ctx.insert(ms1); ctx.insert(ms2); ctx.insert(ps)
        try ctx.save()

        let middles = try ctx.fetch(FetchDescriptor<School>(
            predicate: #Predicate { $0.zoneId == zone.id && $0.type == "初中" }
        ))
        #expect(middles.count == 2)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL** (models not yet in container)

- [ ] **Step 3: Create User models**

```swift
// TianjinHouse/Models/User/PropertyMark.swift
import SwiftData

@Model final class PropertyMark {
    var id: UUID = UUID()
    var compoundId: UUID = UUID()
    var status: String = "想看"         // 想看/看过/排除/已购
    var priority: Int?
    var privateNotes: String?
    var askPriceMinWan: Int?
    var askPriceMaxWan: Int?
    var firstSeenAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(compoundId: UUID, status: String = "想看") {
        self.compoundId = compoundId; self.status = status; self.firstSeenAt = Date()
    }
}

// TianjinHouse/Models/User/Visit.swift
@Model final class Visit {
    var id: UUID = UUID()
    var compoundId: UUID = UUID()
    var visitDate: Date = Date()
    var ratingOverall: Int?
    var ratingLight: Int?
    var ratingNoise: Int?
    var ratingLayout: Int?
    var ratingProperty: Int?
    var floorNumber: Int?
    var totalFloors: Int?
    var areaM2: Double?
    var askPriceWan: Int?
    var layout: String?
    var agentName: String?
    var agentPhone: String?
    var freeText: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(compoundId: UUID, visitDate: Date = Date()) {
        self.compoundId = compoundId; self.visitDate = visitDate
    }
}

// TianjinHouse/Models/User/Photo.swift
@Model final class Photo {
    var id: UUID = UUID()
    var visitId: UUID?
    var compoundId: UUID?
    var kind: String = "visit"          // visit/compound/document
    var imageData: Data?
    var caption: String?
    var takenAt: Date?
    var width: Int?
    var height: Int?
    var createdAt: Date = Date()

    init(visitId: UUID? = nil, compoundId: UUID? = nil, kind: String = "visit") {
        self.visitId = visitId; self.compoundId = compoundId; self.kind = kind
    }
}

// TianjinHouse/Models/User/TagExtension.swift
@Model final class TagExtension {
    var id: UUID = UUID()
    var category: String = ""
    var label: String = ""
    var polarity: String = "中"
    var createdAt: Date = Date()

    init(category: String, label: String, polarity: String = "中") {
        self.category = category; self.label = label; self.polarity = polarity
    }
}

// TianjinHouse/Models/User/VisitTag.swift
@Model final class VisitTag {
    var id: UUID = UUID()
    var visitId: UUID = UUID()
    var tagId: UUID = UUID()
    var tagSource: String = "builtin"   // builtin/extension

    init(visitId: UUID, tagId: UUID, tagSource: String = "builtin") {
        self.visitId = visitId; self.tagId = tagId; self.tagSource = tagSource
    }
}

// TianjinHouse/Models/User/UserArea.swift
@Model final class UserArea {
    var id: UUID = UUID()
    var name: String = ""
    var kind: String = "custom"         // custom/school_zone_alt/commute/exclusion
    var geometry: String = ""           // GeoJSON
    var strokeColorHex: String = "#007AFF"
    var fillColorHex: String = "#007AFF"
    var fillOpacity: Double = 0.15
    var referenceZoneId: UUID?
    var areaDescription: String?
    var isVisible: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(name: String, kind: String = "custom", geometry: String) {
        self.name = name; self.kind = kind; self.geometry = geometry
    }

    var decodedCoordinates: [CLLocationCoordinate2D] {
        (try? GeoJSONHelper.decodePolygon(geometry)) ?? []
    }
}

// TianjinHouse/Models/User/ShareSubmission.swift
@Model final class ShareSubmission {
    var id: UUID = UUID()
    var sourceTable: String = ""
    var sourceId: UUID = UUID()
    var targetPubTable: String = ""
    var payloadJson: String = ""
    var userNote: String?
    var status: String = "draft"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(sourceTable: String, sourceId: UUID, targetPubTable: String, payloadJson: String) {
        self.sourceTable = sourceTable; self.sourceId = sourceId
        self.targetPubTable = targetPubTable; self.payloadJson = payloadJson
    }
}
```

- [ ] **Step 4: Create AppSettings.swift**

```swift
// TianjinHouse/Models/Local/AppSettings.swift
import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var defaultMapStyle: String {
        didSet { defaults.set(defaultMapStyle, forKey: "defaultMapStyle") }
    }
    @Published var showZoneTiers: Set<String> {
        didSet { defaults.set(Array(showZoneTiers), forKey: "showZoneTiers") }
    }

    private init() {
        self.defaultMapStyle = defaults.string(forKey: "defaultMapStyle") ?? "standard"
        let tiers = defaults.stringArray(forKey: "showZoneTiers") ?? ["顶尖", "优质", "普通", "薄弱"]
        self.showZoneTiers = Set(tiers)
    }
}
```

- [ ] **Step 5: Run query tests — expect PASS**

`Cmd+U` → filter `SchoolZoneQueryTests`
Expected: both tests PASS ✓

- [ ] **Step 6: Commit**
```bash
git add TianjinHouse/Models/ TianjinHouseTests/SchoolZoneQueryTests.swift
git commit -m "feat: usr_* and loc_* models + zone query tests"
```

---

## Task 4: ModelContainer + App Entry

**Files:**
- Modify: `TianjinHouse/TianjinHouseApp.swift`
- Create: `TianjinHouse/RootView.swift`
- Create: `TianjinHouse/ViewModels/MapSelectionState.swift`

- [ ] **Step 1: Create MapSelectionState**

```swift
// TianjinHouse/ViewModels/MapSelectionState.swift
import SwiftUI
import MapKit

@Observable
final class MapSelectionState {
    var selectedCompoundId: UUID?
    var selectedZoneId: UUID?
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.1, longitude: 117.2),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    var searchQuery: String = ""
    var isSearching: Bool = false
    var activeDrawerTab: DrawerTab = .schools

    enum DrawerTab { case schools, visits, zones }
}
```

- [ ] **Step 2: Write TianjinHouseApp.swift**

```swift
// TianjinHouse/TianjinHouseApp.swift
import SwiftUI
import SwiftData

@main
struct TianjinHouseApp: App {
    let container: ModelContainer
    @State private var selectionState = MapSelectionState()
    @State private var seedDone = false

    init() {
        do {
            let schema = Schema([
                SchoolZone.self, Compound.self, School.self,
                SchoolScore.self, AdmissionDoc.self, BuiltinTag.self,
                PropertyMark.self, Visit.self, Photo.self,
                TagExtension.self, VisitTag.self, UserArea.self, ShareSubmission.self
            ])
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.yourname.tianjinhouse")
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
                } else {
                    SeedProgressView(onComplete: { seedDone = true })
                }
            }
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 3: Write RootView.swift**

Chrome is floating glass cards above the full-screen map — NOT a rigid HStack split.
z-order: map(0) < drawer(5) < wizard(12) < toolbar(30).

```swift
// TianjinHouse/RootView.swift
import SwiftUI

struct RootView: View {
    @Environment(MapSelectionState.self) private var selection

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Full-screen map, underneath everything
                MapContainerView()
                    .ignoresSafeArea()

                // Floating toolbar: top 40pt, inset 16pt H, height 52pt, blur 24pt, r 16pt
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

                // Floating drawer: right side, 38.2% − 16pt wide, top 108pt
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

// Stub — replaced in Task 8
struct ToolbarView: View {
    var body: some View { Color.clear }
}
```

- [ ] **Step 4: Add stub views so it builds**

```swift
// TianjinHouse/Map/MapContainerView.swift (stub)
import SwiftUI
struct MapContainerView: View {
    var body: some View { Color.gray.opacity(0.2) }
}

// TianjinHouse/Drawer/DrawerContainerView.swift (stub)
import SwiftUI
struct DrawerContainerView: View {
    var body: some View { Color.blue.opacity(0.05) }
}

// TianjinHouse/States/SeedProgressView.swift (stub)
import SwiftUI
struct SeedProgressView: View {
    var onComplete: () -> Void
    var body: some View {
        Button("Skip Seed (dev)") { onComplete() }
    }
}
```

- [ ] **Step 5: Build + run on iPad Simulator**

`Cmd+R` on iPad Air (5th gen) simulator.
Expected: Grey left panel, blue-tint right panel, tap "Skip Seed" → same layout persists.

- [ ] **Step 6: Commit**
```bash
git add TianjinHouse/
git commit -m "feat: ModelContainer, app entry, root golden-ratio split"
```

---

## Task 5: SeedExtractor Mac CLI Tool

**Files:**
- Create: `Scripts/SeedExtractor/Package.swift`
- Create: `Scripts/SeedExtractor/Sources/SeedExtractor/main.swift`
- Create: `Scripts/SeedExtractor/Sources/SeedExtractor/Models.swift`
- Create: `TianjinHouse/Seed/SeedData/schools.json` (sample, 3 records)
- Create: `TianjinHouse/Seed/SeedData/school_zones.json` (sample, 1 zone)
- Create: `TianjinHouse/Seed/SeedData/compounds.json` (sample, 3 records)

- [ ] **Step 1: Create Package.swift**

```swift
// Scripts/SeedExtractor/Package.swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SeedExtractor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SeedExtractor",
            path: "Sources/SeedExtractor"
        )
    ]
)
```

- [ ] **Step 2: Create Models.swift**

```swift
// Scripts/SeedExtractor/Sources/SeedExtractor/Models.swift
import Foundation

struct SeedSchoolZone: Codable {
    var id: String
    var name: String
    var tier: String
    var primaryDistrict: String
    var geometry: String             // GeoJSON Polygon string
    var residencyYears: Int?
    var version: Int = 1
}

struct SeedSchool: Codable {
    var id: String
    var name: String
    var type: String                 // 小学/初中
    var zoneId: String?
    var district: String
    var tier: String
    var version: Int = 1
}

struct SeedCompound: Codable {
    var id: String
    var name: String
    var district: String
    var latitude: Double
    var longitude: Double
    var zoneId: String?
    var primarySchoolId: String?
    var address: String
    var version: Int = 1
}
```

- [ ] **Step 3: Create main.swift**

```swift
// Scripts/SeedExtractor/Sources/SeedExtractor/main.swift
import Foundation

// Usage: swift run SeedExtractor <markdown-path> <output-dir>
// For now outputs hardcoded sample data.
// Extend this to parse reports/ markdown for real data.

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

// Sample data (replace with real parsed data from reports/)
let zones = [
    SeedSchoolZone(
        id: "11111111-0000-0000-0000-000000000001",
        name: "和平区第一学区",
        tier: "顶尖",
        primaryDistrict: "和平区",
        geometry: #"{"type":"Polygon","coordinates":[[[117.19,39.12],[117.23,39.12],[117.23,39.15],[117.19,39.15],[117.19,39.12]]]}"#,
        residencyYears: 3
    )
]

let schools = [
    SeedSchool(id: "22222222-0000-0000-0000-000000000001",
               name: "实验小学", type: "小学",
               zoneId: "11111111-0000-0000-0000-000000000001",
               district: "和平区", tier: "顶尖"),
    SeedSchool(id: "22222222-0000-0000-0000-000000000002",
               name: "实验中学", type: "初中",
               zoneId: "11111111-0000-0000-0000-000000000001",
               district: "和平区", tier: "顶尖"),
]

let compounds = [
    SeedCompound(id: "33333333-0000-0000-0000-000000000001",
                 name: "珑璟台", district: "和平区",
                 latitude: 39.135, longitude: 117.208,
                 zoneId: "11111111-0000-0000-0000-000000000001",
                 primarySchoolId: "22222222-0000-0000-0000-000000000001",
                 address: "和平区南京路1号"),
]

func write<T: Encodable>(_ items: [T], to filename: String) throws {
    let data = try encoder.encode(items)
    let url = URL(fileURLWithPath: "\(outputDir)/\(filename)")
    try data.write(to: url)
    print("Wrote \(items.count) items to \(filename)")
}

try write(zones,     to: "school_zones.json")
try write(schools,   to: "schools.json")
try write(compounds, to: "compounds.json")
print("Done.")
```

- [ ] **Step 4: Run the tool to generate JSON**

```bash
cd Scripts/SeedExtractor
swift run SeedExtractor ../../TianjinHouse/Seed/SeedData
```

Expected output:
```
Wrote 1 items to school_zones.json
Wrote 2 items to schools.json
Wrote 1 items to compounds.json
Done.
```

- [ ] **Step 5: Add generated JSON to Xcode target**

In Xcode, right-click `TianjinHouse/Seed/SeedData` → Add Files → select all three JSON files → Add to TianjinHouse target.

- [ ] **Step 6: Commit**
```bash
git add Scripts/SeedExtractor/ TianjinHouse/Seed/SeedData/
git commit -m "feat: SeedExtractor CLI + sample seed JSON files"
```

---

## Task 6: SeedImporter + SeedProgressView

**Files:**
- Create: `TianjinHouse/Extensions/Color+Hex.swift`
- Create: `TianjinHouse/Seed/SeedImporter.swift`
- Modify: `TianjinHouse/States/SeedProgressView.swift`
- Create: `TianjinHouseTests/SeedImporterTests.swift`

- [ ] **Step 1: Create Color+Hex.swift**

```swift
// TianjinHouse/Extensions/Color+Hex.swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// Design token constants (from hi-fi prototype colors_and_type.css + map.jsx)
extension Color {
    // Tier colors (school zone quality)
    static let tierTop     = Color(hex: "#C99B2C")   // 顶尖 — warm gold
    static let tierGood    = Color(hex: "#5B7C9C")   // 优质 — steel blue
    static let tierNormal  = Color(hex: "#9C968B")   // 普通 — warm grey
    static let tierWeak    = Color(hex: "#B8736B")   // 薄弱 — brick red

    // Compound pin status colors
    static let statusUnvisited = Color(hex: "#9C968B")  // 未看
    static let statusWant      = Color(hex: "#5B7C9C")  // 想看
    static let statusVisited   = Color(hex: "#7A9A7E")  // 看过
    static let statusExcluded  = Color(hex: "#A85040")  // 排除

    // Brand accent
    static let accent500 = Color(hex: "#B5703A")         // 暖橙
}
```

- [ ] **Step 2: Write failing SeedImporter test**

```swift
// TianjinHouseTests/SeedImporterTests.swift
import Testing
import SwiftData

@MainActor
struct SeedImporterTests {
    @Test func importCreatesZonesAndSchools() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SchoolZone.self, School.self, Compound.self,
                BuiltinTag.self, SchoolScore.self, AdmissionDoc.self,
            configurations: config
        )
        let ctx = container.mainContext
        var progress: [(String, Double)] = []

        let importer = SeedImporter()
        try await importer.importIfNeeded(context: ctx) { label, pct in
            progress.append((label, pct))
        }

        let zones = try ctx.fetch(FetchDescriptor<SchoolZone>())
        let schools = try ctx.fetch(FetchDescriptor<School>())
        #expect(zones.count >= 1)
        #expect(schools.count >= 2)
        #expect(!progress.isEmpty)
    }

    @Test func importIsIdempotent() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SchoolZone.self, School.self, Compound.self,
                BuiltinTag.self, SchoolScore.self, AdmissionDoc.self,
            configurations: config
        )
        let ctx = container.mainContext
        let importer = SeedImporter()
        try await importer.importIfNeeded(context: ctx) { _, _ in }
        let countAfterFirst = try ctx.fetch(FetchDescriptor<School>()).count
        // Second import should be a no-op (uses UUID upsert)
        try await importer.importIfNeeded(context: ctx) { _, _ in }
        let countAfterSecond = try ctx.fetch(FetchDescriptor<School>()).count
        #expect(countAfterFirst == countAfterSecond)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL** (SeedImporter not defined)

- [ ] **Step 3: Create SeedImporter.swift**

```swift
// TianjinHouse/Seed/SeedImporter.swift
import SwiftData
import Foundation

struct SeedSchoolZoneDTO: Codable {
    let id: String; let name: String; let tier: String
    let primaryDistrict: String; let geometry: String
    let residencyYears: Int?; let version: Int
}
struct SeedSchoolDTO: Codable {
    let id: String; let name: String; let type: String
    let zoneId: String?; let district: String; let tier: String
    let version: Int
}
struct SeedCompoundDTO: Codable {
    let id: String; let name: String; let district: String
    let latitude: Double; let longitude: Double
    let zoneId: String?; let primarySchoolId: String?
    let address: String; let version: Int
}

@MainActor
final class SeedImporter {
    private let seedVersionKey = "seedImported.v1"

    func importIfNeeded(
        context: ModelContext,
        progress: (String, Double) -> Void
    ) async throws {
        // Idempotency: check existing count instead of UserDefaults for tests
        let existingZones = try context.fetch(FetchDescriptor<SchoolZone>())
        if !existingZones.isEmpty { return }

        progress("学区边界", 0.1)
        let zones: [SeedSchoolZoneDTO] = try loadJSON("school_zones")
        for dto in zones {
            let zone = SchoolZone(
                id: UUID(uuidString: dto.id) ?? UUID(),
                name: dto.name, tier: dto.tier,
                primaryDistrict: dto.primaryDistrict, geometry: dto.geometry
            )
            zone.residencyYears = dto.residencyYears
            zone.version = dto.version
            context.insert(zone)
        }
        try context.save()

        progress("学校数据", 0.35)
        let schools: [SeedSchoolDTO] = try loadJSON("schools")
        for dto in schools {
            let school = School(
                id: UUID(uuidString: dto.id) ?? UUID(),
                name: dto.name, type: dto.type,
                zoneId: dto.zoneId.flatMap(UUID.init),
                district: dto.district, tier: dto.tier
            )
            school.version = dto.version
            context.insert(school)
        }
        try context.save()

        progress("小区数据", 0.6)
        let compounds: [SeedCompoundDTO] = try loadJSON("compounds")
        for dto in compounds {
            let c = Compound(
                id: UUID(uuidString: dto.id) ?? UUID(),
                name: dto.name, district: dto.district,
                latitude: dto.latitude, longitude: dto.longitude
            )
            c.address = dto.address
            c.zoneId = dto.zoneId.flatMap(UUID.init)
            c.primarySchoolId = dto.primarySchoolId.flatMap(UUID.init)
            c.version = dto.version
            context.insert(c)
        }
        try context.save()

        progress("内置标签", 0.85)
        insertBuiltinTags(context: context)
        try context.save()

        progress("完成", 1.0)
        UserDefaults.standard.set(true, forKey: seedVersionKey)
    }

    private func loadJSON<T: Decodable>(_ name: String) throws -> [T] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw SeedError.fileNotFound(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([T].self, from: data)
    }

    private func insertBuiltinTags(context: ModelContext) {
        let tags: [(String, String, String)] = [
            ("采光","南北通透","正"),("采光","全朝南","正"),("采光","西晒","负"),
            ("采光","北向","负"),("采光","楼层遮挡","负"),
            ("噪音","安静","正"),("噪音","临街主干道","负"),("噪音","高架旁","负"),
            ("气味","无异味","中"),("气味","电梯异味","负"),("气味","潮湿霉味","负"),
            ("装修","新装精装","正"),("装修","次新整洁","正"),("装修","陈旧","负"),
            ("物业","物业积极","正"),("物业","物业散漫","负"),("物业","电梯老旧","负"),
            ("邻里","楼道整洁","正"),("邻里","杂物堆积","负"),
        ]
        for (i, (cat, label, pol)) in tags.enumerated() {
            let tag = BuiltinTag(category: cat, label: label, polarity: pol)
            tag.sortOrder = i
            context.insert(tag)
        }
    }

    enum SeedError: Error {
        case fileNotFound(String)
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

Note: The idempotency test uses context-level check (zone count), not UserDefaults — works in-memory.

- [ ] **Step 5: Build real SeedProgressView**

```swift
// TianjinHouse/States/SeedProgressView.swift
import SwiftUI
import SwiftData

struct SeedProgressView: View {
    var onComplete: () -> Void
    @Environment(\.modelContext) private var context

    @State private var progressLabel = "准备中…"
    @State private var progressValue: Double = 0
    @State private var steps: [(label: String, done: Bool)] = [
        ("学区边界", false), ("学校数据", false),
        ("小区数据", false), ("内置标签", false)
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1c1c2e"), Color(hex: "#2d2d44")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("🗺️").font(.system(size: 56))
                Text("北漂天津置业").font(.largeTitle.bold()).foregroundStyle(.white)
                Text("正在初始化地图数据").font(.subheadline).foregroundStyle(.white.opacity(0.5))

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(steps.indices, id: \.self) { i in
                        HStack(spacing: 10) {
                            if steps[i].done {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if progressLabel.contains(steps[i].label) {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Circle().fill(.white.opacity(0.2)).frame(width: 18, height: 18)
                            }
                            Text(steps[i].label)
                                .foregroundStyle(steps[i].done ? .white.opacity(0.4) : .white)
                        }
                    }
                }
                .frame(width: 260, alignment: .leading)

                VStack(spacing: 6) {
                    ProgressView(value: progressValue)
                        .frame(width: 260)
                        .tint(.blue)
                    HStack {
                        Text(progressLabel).font(.caption).foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text("\(Int(progressValue * 100))%").font(.caption).foregroundStyle(.white.opacity(0.4))
                    }.frame(width: 260)
                }
            }
        }
        .task { await runImport() }
    }

    private func runImport() async {
        let importer = SeedImporter()
        do {
            try await importer.importIfNeeded(context: context) { label, pct in
                Task { @MainActor in
                    progressLabel = label; progressValue = pct
                    for i in steps.indices {
                        if pct > Double(i + 1) / Double(steps.count) { steps[i].done = true }
                    }
                }
            }
            try await Task.sleep(for: .milliseconds(400))
            onComplete()
        } catch {
            progressLabel = "导入失败: \(error.localizedDescription)"
        }
    }
}

// Color(hex:) is defined in TianjinHouse/Extensions/Color+Hex.swift (Task 6 Step 1)
```

- [ ] **Step 7: Run on simulator — verify seed screen then auto-advances**

`Cmd+R` → Dark seed screen shows, items tick off, advances to grey/blue layout.

- [ ] **Step 8: Commit**
```bash
git add TianjinHouse/Extensions/Color+Hex.swift TianjinHouse/Seed/ TianjinHouse/States/SeedProgressView.swift TianjinHouseTests/SeedImporterTests.swift
git commit -m "feat: SeedImporter with progress + SeedProgressView + Color+Hex extension"
```

---

## Task 7: Map Container + School Zone Polygons

**Files:**
- Modify: `TianjinHouse/Map/MapContainerView.swift`
- Create: `TianjinHouse/Map/SchoolZoneOverlay.swift`

- [ ] **Step 1: Write MapContainerView**

```swift
// TianjinHouse/Map/MapContainerView.swift
import SwiftUI
import MapKit
import SwiftData

struct MapContainerView: View {
    @Environment(MapSelectionState.self) private var selection
    @Query(filter: #Predicate<SchoolZone> { !$0.deleted },
           sort: \.name) private var zones: [SchoolZone]
    @Query(filter: #Predicate<Compound> { !$0.deleted },
           sort: \.name) private var compounds: [Compound]
    @Query private var marks: [PropertyMark]

    @Bindable private var bindableSelection: MapSelectionState
    init() { _bindableSelection = .init() }  // injected via environment

    var body: some View {
        @Bindable var sel = selection
        Map(position: $sel.cameraPosition) {
            ForEach(zones) { zone in
                SchoolZoneOverlay(zone: zone, isSelected: zone.id == selection.selectedZoneId)
            }
            ForEach(compounds) { compound in
                let mark = marks.first { $0.compoundId == compound.id }
                Annotation("", coordinate: compound.coordinate) {
                    CompoundPinView(compound: compound, mark: mark)
                        .onTapGesture {
                            selection.selectedCompoundId = compound.id
                        }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard)
        .overlay(alignment: .top) {
            OfflineBannerView()
        }
        .overlay(alignment: .topLeading) {
            MapFiltersView()
                .padding(12)
        }
    }
}

// Stub pin view (fully built in Task 9)
struct CompoundPinView: View {
    let compound: Compound
    let mark: PropertyMark?
    var body: some View {
        Circle()
            .fill(pinColor)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
    }
    var pinColor: Color {
        switch mark?.status {
        case "想看": return .statusWant
        case "看过": return .statusVisited
        case "排除": return .statusExcluded
        case "已购": return .accent500
        default:    return .statusUnvisited
        }
    }
}

// Stubs (implemented in later tasks)
struct OfflineBannerView: View { var body: some View { EmptyView() } }
struct MapFiltersView: View { var body: some View { EmptyView() } }
```

- [ ] **Step 2: Create SchoolZoneOverlay.swift**

```swift
// TianjinHouse/Map/SchoolZoneOverlay.swift
import SwiftUI
import MapKit

struct SchoolZoneOverlay: MapContent {
    let zone: SchoolZone
    let isSelected: Bool

    var body: some MapContent {
        let coords = zone.decodedCoordinates
        if !coords.isEmpty {
            MapPolygon(coordinates: coords)
                .foregroundStyle(tierColor.opacity(isSelected ? 0.35 : 0.18))
                .stroke(tierColor, lineWidth: isSelected ? 2.5 : 1.5)
        }
    }

    private var tierColor: Color {
        switch zone.tier {
        case "顶尖": return .tierTop
        case "优质": return .tierGood
        case "普通": return .tierNormal
        case "薄弱": return .tierWeak
        default:    return .tierNormal
        }
    }
}
```

- [ ] **Step 3: Build + run on simulator**

`Cmd+R` → After seed screen, map should show with blue-outline polygon for 和平区第一学区, and a grey pin for 珑璟台.

- [ ] **Step 4: Commit**
```bash
git add TianjinHouse/Map/
git commit -m "feat: MapContainerView + school zone polygon overlay"
```

---

## Task 8: DrawerContainerView (3-Tab Shell + Search)

**Files:**
- Modify: `TianjinHouse/Drawer/DrawerContainerView.swift`
- Create: `TianjinHouse/Drawer/SearchResultsView.swift`
- Create: `TianjinHouse/Drawer/SchoolTabView.swift` (stub)
- Create: `TianjinHouse/Drawer/VisitTabView.swift` (stub)
- Create: `TianjinHouse/Drawer/ZoneTabView.swift` (stub)

- [ ] **Step 1: Build DrawerContainerView**

```swift
// TianjinHouse/Drawer/DrawerContainerView.swift
import SwiftUI

struct DrawerContainerView: View {
    @Environment(MapSelectionState.self) private var selection

    var body: some View {
        @Bindable var sel = selection
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(MapSelectionState.DrawerTab.allCases, id: \.self) { tab in
                    Button {
                        sel.activeDrawerTab = tab
                        sel.isSearching = false
                        sel.searchQuery = ""
                    } label: {
                        VStack(spacing: 4) {
                            Text(tab.label)
                                .font(.system(size: 14, weight: sel.activeDrawerTab == tab ? .semibold : .regular))
                                .foregroundStyle(sel.activeDrawerTab == tab ? Color.accentColor : .secondary)
                            Rectangle()
                                .fill(sel.activeDrawerTab == tab ? Color.accentColor : .clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)
            .background(Color(.systemBackground))

            Divider()

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.footnote)
                TextField("搜索学校、小区…", text: $sel.searchQuery)
                    .font(.system(size: 14))
                    .onSubmit { sel.isSearching = !sel.searchQuery.isEmpty }
                    .onChange(of: sel.searchQuery) { _, new in sel.isSearching = !new.isEmpty }
                if !sel.searchQuery.isEmpty {
                    Button { sel.searchQuery = ""; sel.isSearching = false } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            Divider()

            // Content
            Group {
                if sel.isSearching {
                    SearchResultsView()
                } else {
                    switch sel.activeDrawerTab {
                    case .schools: SchoolTabView()
                    case .visits:  VisitTabView()
                    case .zones:   ZoneTabView()
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

extension MapSelectionState.DrawerTab: CaseIterable {
    var label: String {
        switch self { case .schools: "学校" case .visits: "看房" case .zones: "区域" }
    }
}
```

- [ ] **Step 2: Add stub tab views + SearchResultsView**

```swift
// TianjinHouse/Drawer/SchoolTabView.swift (stub)
import SwiftUI
struct SchoolTabView: View {
    var body: some View { contentPlaceholder("学校列表") }
}

// TianjinHouse/Drawer/VisitTabView.swift (stub)
struct VisitTabView: View {
    var body: some View { contentPlaceholder("看房记录") }
}

// TianjinHouse/Drawer/ZoneTabView.swift (stub)
struct ZoneTabView: View {
    var body: some View { contentPlaceholder("我的区域") }
}

private func contentPlaceholder(_ title: String) -> some View {
    VStack { Spacer(); Text(title).foregroundStyle(.secondary); Spacer() }
}

// TianjinHouse/Drawer/SearchResultsView.swift
import SwiftUI
import SwiftData

struct SearchResultsView: View {
    @Environment(MapSelectionState.self) private var selection
    @Query private var compounds: [Compound]
    @Query private var schools: [School]

    private var filteredCompounds: [Compound] {
        guard !selection.searchQuery.isEmpty else { return [] }
        return compounds.filter { $0.name.localizedCaseInsensitiveContains(selection.searchQuery) || ($0.aliases.contains { $0.localizedCaseInsensitiveContains(selection.searchQuery) }) }
    }
    private var filteredSchools: [School] {
        guard !selection.searchQuery.isEmpty else { return [] }
        return schools.filter { $0.name.localizedCaseInsensitiveContains(selection.searchQuery) }
    }

    var body: some View {
        if filteredCompounds.isEmpty && filteredSchools.isEmpty {
            emptyState
        } else {
            List {
                if !filteredCompounds.isEmpty {
                    Section("小区") {
                        ForEach(filteredCompounds) { c in
                            Button { selection.selectedCompoundId = c.id } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name).font(.system(size: 14, weight: .semibold))
                                    Text(c.district + " · " + c.address).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if !filteredSchools.isEmpty {
                    Section("学校") {
                        ForEach(filteredSchools) { s in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(.system(size: 14, weight: .semibold))
                                    Text(s.type + " · " + s.district).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(s.tier).font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(tierColor(s.tier).opacity(0.15))
                                    .foregroundStyle(tierColor(s.tier))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass").font(.system(size: 40)).foregroundStyle(.quaternary)
            Text("未找到「\(selection.searchQuery)」").font(.headline)
            Text("尝试其他名称").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier { case "顶尖": .orange case "优质": .blue default: .gray }
    }
}
```

- [ ] **Step 3: Run on simulator — verify tab switching + search**

`Cmd+R` → tap tabs → content switches. Type in search bar → SearchResultsView shows or empty state.

- [ ] **Step 4: Commit**
```bash
git add TianjinHouse/Drawer/
git commit -m "feat: DrawerContainerView with 3-tab shell and search"
```

---

## Task 9: School Tab + School Detail

**Files:**
- Modify: `TianjinHouse/Drawer/SchoolTabView.swift`
- Create: `TianjinHouse/Detail/SchoolDetailView.swift`

- [ ] **Step 1: Build SchoolTabView**

```swift
// TianjinHouse/Drawer/SchoolTabView.swift
import SwiftUI
import SwiftData

struct SchoolTabView: View {
    @Environment(MapSelectionState.self) private var selection
    @Query(filter: #Predicate<School> { !$0.deleted }, sort: \.tier) private var schools: [School]
    @Query private var zones: [SchoolZone]
    @State private var selectedSchool: School?

    var body: some View {
        if schools.isEmpty {
            EmptyStateView(
                icon: "building.columns",
                title: "暂无学校数据",
                subtitle: "Seed 数据导入后自动显示",
                ctaTitle: nil, ctaAction: nil
            )
        } else {
            List(schools) { school in
                Button {
                    selectedSchool = school
                    if let zoneId = school.zoneId {
                        selection.selectedZoneId = zoneId
                    }
                } label: {
                    SchoolCardView(school: school, zone: zones.first { $0.id == school.zoneId })
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .sheet(item: $selectedSchool) { school in
                SchoolDetailView(school: school,
                                 zone: zones.first { $0.id == school.zoneId })
            }
        }
    }
}

struct SchoolCardView: View {
    let school: School
    let zone: SchoolZone?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(school.name).font(.system(size: 15, weight: .semibold))
                Spacer()
                tierBadge(school.tier)
            }
            HStack(spacing: 8) {
                Label(school.type, systemImage: school.type == "小学" ? "pencil" : "graduationcap")
                    .font(.caption).foregroundStyle(.secondary)
                if let zone = zone {
                    Text("·").foregroundStyle(.secondary)
                    Text(zone.name).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func tierBadge(_ tier: String) -> some View {
        let c: Color = tier == "顶尖" ? .orange : tier == "优质" ? .blue : .gray
        return Text(tier).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
            .background(c.opacity(0.15)).foregroundStyle(c).clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Create SchoolDetailView**

```swift
// TianjinHouse/Detail/SchoolDetailView.swift
import SwiftUI
import SwiftData

struct SchoolDetailView: View {
    let school: School
    let zone: SchoolZone?
    @Query private var scores: [SchoolScore]
    @Environment(\.dismiss) private var dismiss

    private var myScores: [SchoolScore] {
        scores.filter { $0.schoolId == school.id }.sorted { $0.year > $1.year }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("类型", value: school.type)
                    LabeledContent("行政区", value: school.district)
                    LabeledContent("等级", value: school.tier)
                    if let zone = zone {
                        LabeledContent("所属学区", value: zone.name)
                        if let years = zone.residencyYears {
                            LabeledContent("落户年限", value: "\(years) 年")
                        }
                    }
                } header: { Text("基本信息") }

                if !myScores.isEmpty {
                    Section("中考成绩排名") {
                        ForEach(myScores) { score in
                            HStack {
                                Text("\(score.year)年")
                                Spacer()
                                if let rank = score.rankCity {
                                    Text("全市第 \(rank) 名").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if school.type == "小学", let zone = zone {
                    Section("初中摇号说明") {
                        Text("购买该学区小区后，子女可在\(zone.name)内所有初中参与摇号入学。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(school.name)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
        }
    }
}
```

- [ ] **Step 3: Create EmptyStateView component**

```swift
// TianjinHouse/Components/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let ctaTitle: String?
    let ctaAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(.quaternary)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let title = ctaTitle, let action = ctaAction {
                Button(title, action: action)
                    .buttonStyle(.borderedProminent).padding(.top, 4)
            }
            Spacer()
        }
        .padding(24)
    }
}
```

- [ ] **Step 4: Run on simulator**

Schools tab shows list of 实验小学 / 实验中学. Tap card → sheet with detail. Map zone polygon highlights.

- [ ] **Step 5: Commit**
```bash
git add TianjinHouse/Drawer/SchoolTabView.swift TianjinHouse/Detail/SchoolDetailView.swift TianjinHouse/Components/EmptyStateView.swift
git commit -m "feat: school tab list + school detail sheet"
```

---

## Task 10: Visit Tab + Compound Detail

**Files:**
- Modify: `TianjinHouse/Drawer/VisitTabView.swift`
- Create: `TianjinHouse/Detail/CompoundDetailView.swift`
- Create: `TianjinHouse/Components/StarRatingView.swift`

- [ ] **Step 1: Build VisitTabView**

```swift
// TianjinHouse/Drawer/VisitTabView.swift
import SwiftUI
import SwiftData

struct VisitTabView: View {
    @Environment(MapSelectionState.self) private var selection
    @Query(sort: \Visit.visitDate, order: .reverse) private var visits: [Visit]
    @Query private var marks: [PropertyMark]
    @Query private var compounds: [Compound]
    @State private var showWizard = false

    private var grouped: [(status: String, marks: [PropertyMark])] {
        let statuses = ["想看", "看过", "已购", "排除"]
        return statuses.compactMap { s in
            let filtered = marks.filter { $0.status == s }
            return filtered.isEmpty ? nil : (status: s, marks: filtered)
        }
    }

    var body: some View {
        Group {
            if marks.isEmpty {
                EmptyStateView(
                    icon: "house",
                    title: "还没有看房记录",
                    subtitle: "点击地图上的小区，或在此新建记录",
                    ctaTitle: "+ 新建看房记录",
                    ctaAction: { showWizard = true }
                )
            } else {
                List {
                    ForEach(grouped, id: \.status) { group in
                        Section(group.status) {
                            ForEach(group.marks) { mark in
                                if let compound = compounds.first(where: { $0.id == mark.compoundId }) {
                                    VisitCardView(
                                        compound: compound, mark: mark,
                                        visits: visits.filter { $0.compoundId == compound.id }
                                    )
                                    .onTapGesture { selection.selectedCompoundId = compound.id }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showWizard = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showWizard) {
            VisitWizardView(preselectedCompoundId: selection.selectedCompoundId)
        }
    }
}

struct VisitCardView: View {
    let compound: Compound
    let mark: PropertyMark
    let visits: [Visit]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(compound.name).font(.system(size: 15, weight: .semibold))
                Spacer()
                statusBadge(mark.status)
            }
            HStack(spacing: 8) {
                Text(compound.district).font(.caption).foregroundStyle(.secondary)
                if let last = visits.sorted(by: { $0.visitDate > $1.visitDate }).first {
                    Text("·").foregroundStyle(.secondary)
                    Text("最近看房 \(last.visitDate.formatted(.dateTime.month().day()))").font(.caption).foregroundStyle(.secondary)
                    if let r = last.ratingOverall {
                        Text("·").foregroundStyle(.secondary)
                        StarRatingView(rating: r, maxStars: 5, size: 10, interactive: false)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ s: String) -> some View {
        let c: Color = s == "想看" ? .blue : s == "看过" ? .green : s == "已购" ? .purple : .red
        return Text(s).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
            .background(c.opacity(0.15)).foregroundStyle(c).clipShape(Capsule())
    }
}
```

- [ ] **Step 2: Create StarRatingView**

```swift
// TianjinHouse/Components/StarRatingView.swift
import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Int
    var maxStars: Int = 5
    var size: CGFloat = 24
    var interactive: Bool = true

    init(rating: Binding<Int>, maxStars: Int = 5, size: CGFloat = 24, interactive: Bool = true) {
        _rating = rating; self.maxStars = maxStars; self.size = size; self.interactive = interactive
    }
    init(rating: Int, maxStars: Int = 5, size: CGFloat = 24, interactive: Bool = false) {
        _rating = .constant(rating); self.maxStars = maxStars; self.size = size; self.interactive = interactive
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxStars, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(i <= rating ? .yellow : .quaternary)
                    .onTapGesture { if interactive { rating = i } }
            }
        }
    }
}
```

- [ ] **Step 3: Create CompoundDetailView stub**

```swift
// TianjinHouse/Detail/CompoundDetailView.swift
import SwiftUI
import SwiftData

struct CompoundDetailView: View {
    let compound: Compound
    @Query private var zones: [SchoolZone]
    @Query private var schools: [School]
    @Query private var marks: [PropertyMark]
    @Query private var visits: [Visit]
    @Environment(\.modelContext) private var context
    @Environment(MapSelectionState.self) private var selection
    @State private var showWizard = false

    private var zone: SchoolZone? { zones.first { $0.id == compound.zoneId } }
    private var primarySchool: School? { schools.first { $0.id == compound.primarySchoolId } }
    private var mark: PropertyMark? { marks.first { $0.compoundId == compound.id } }
    private var myVisits: [Visit] { visits.filter { $0.compoundId == compound.id }.sorted { $0.visitDate > $1.visitDate } }

    var body: some View {
        NavigationStack {
            List {
                Section("学区信息") {
                    if let z = zone {
                        LabeledContent("所属学区", value: z.name)
                        LabeledContent("学区等级", value: z.tier)
                        if let yrs = z.residencyYears { LabeledContent("落户年限", value: "\(yrs)年") }
                    }
                    if let ps = primarySchool {
                        LabeledContent("对口小学", value: ps.name)
                        LabeledContent("小学等级", value: ps.tier)
                    }
                }
                Section("基本信息") {
                    LabeledContent("行政区", value: compound.district)
                    LabeledContent("地址", value: compound.address)
                    if let yr = compound.buildYear { LabeledContent("建成年份", value: "\(yr)") }
                    if let dev = compound.developer { LabeledContent("开发商", value: dev) }
                }
                if !myVisits.isEmpty {
                    Section("看房记录") {
                        ForEach(myVisits) { v in
                            HStack {
                                Text(v.visitDate.formatted(.dateTime.month().day()))
                                Spacer()
                                if let r = v.ratingOverall { StarRatingView(rating: r, size: 12, interactive: false) }
                            }
                        }
                    }
                }
                Section {
                    Button("开始看房记录") { showWizard = true }
                        .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle(compound.name)
        }
        .sheet(isPresented: $showWizard) {
            VisitWizardView(preselectedCompoundId: compound.id)
        }
    }
}
```

- [ ] **Step 4: Run on simulator**

Visit tab shows empty state with CTA. Tap `+` → wizard sheet (stub). Once a PropertyMark is created via wizard, cards appear grouped by status.

- [ ] **Step 5: Commit**
```bash
git add TianjinHouse/Drawer/VisitTabView.swift TianjinHouse/Detail/ TianjinHouse/Components/StarRatingView.swift
git commit -m "feat: visit tab with grouping + compound detail"
```

---

## Task 11: Visit Wizard (4-Step Form in Drawer)

**Files:**
- Create: `TianjinHouse/Detail/VisitWizardView.swift`
- Create: `TianjinHouse/Components/TagPickerView.swift`

- [ ] **Step 1: Create TagPickerView**

```swift
// TianjinHouse/Components/TagPickerView.swift
import SwiftUI
import SwiftData

struct TagPickerView: View {
    @Binding var selectedTagIds: Set<UUID>
    @Query(sort: \BuiltinTag.sortOrder) private var builtinTags: [BuiltinTag]

    private var grouped: [(category: String, tags: [BuiltinTag])] {
        let cats = ["采光","噪音","气味","装修","物业","邻里"]
        return cats.map { cat in (cat, builtinTags.filter { $0.category == cat }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(grouped, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.category).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(group.tags) { tag in
                                TagChip(tag: tag, selected: selectedTagIds.contains(tag.id)) {
                                    if selectedTagIds.contains(tag.id) { selectedTagIds.remove(tag.id) }
                                    else { selectedTagIds.insert(tag.id) }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct TagChip: View {
    let tag: BuiltinTag
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(tag.label)
                .font(.system(size: 13))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selected ? polarityColor(tag.polarity) : Color(.tertiarySystemBackground))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? .clear : Color(.separator), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
    private func polarityColor(_ p: String) -> Color {
        switch p { case "正": return .green case "负": return .red default: return .blue }
    }
}

// Simple flow layout for tag chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(width: proposal.width ?? 300, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.maxHeight + spacing } - spacing
        return CGSize(width: proposal.width ?? 300, height: max(height, 0))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for sv in row.views {
                let s = sv.sizeThatFits(.unspecified)
                sv.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += s.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }
    private func computeRows(width: CGFloat, subviews: Subviews) -> [(views: [LayoutSubview], maxHeight: CGFloat)] {
        var rows: [(views: [LayoutSubview], maxHeight: CGFloat)] = []
        var row: [LayoutSubview] = []; var rowW: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if rowW + s.width > width && !row.isEmpty {
                rows.append((row, rowH)); row = []; rowW = 0; rowH = 0
            }
            row.append(sv); rowW += s.width + spacing; rowH = max(rowH, s.height)
        }
        if !row.isEmpty { rows.append((row, rowH)) }
        return rows
    }
}
```

- [ ] **Step 2: Create VisitWizardView**

```swift
// TianjinHouse/Detail/VisitWizardView.swift
import SwiftUI
import SwiftData
import PhotosUI

struct VisitWizardView: View {
    var preselectedCompoundId: UUID?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var compounds: [Compound]

    @State private var step = 1
    @State private var selectedCompoundId: UUID?
    @State private var visitDate = Date()
    @State private var floorCategory = "中层"     // 低层/中层/高层
    @State private var totalFloors: Int?
    @State private var areaM2: Double = 90
    @State private var askPriceWan: Int = 300
    @State private var layout = ""
    @State private var agentName = ""

    @State private var ratingOverall = 3
    @State private var ratingLight = 3
    @State private var ratingNoise = 3
    @State private var ratingLayout = 3
    @State private var ratingProperty = 3

    @State private var selectedTagIds = Set<UUID>()
    @State private var freeText = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photos: [UIImage] = []

    private var compound: Compound? {
        compounds.first { $0.id == (selectedCompoundId ?? preselectedCompoundId) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if !photos.isEmpty {
                    PhotoMosaicBackground(images: photos)
                }
                VStack(spacing: 0) {
                    // Step indicator
                    HStack(spacing: 4) {
                        ForEach(1...4, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? Color.accentColor : Color(.tertiarySystemBackground))
                                .frame(height: 4)
                        }
                    }.padding(.horizontal).padding(.top, 8)

                    Text("步骤 \(step) / 4").font(.caption).foregroundStyle(.secondary).padding(.top, 6)

                    ScrollView {
                        switch step {
                        case 1: stepBasicInfo
                        case 2: stepRatings
                        case 3: stepTags
                        default: stepPhotoText
                        }
                    }
                    .scrollContentBackground(.hidden)

                    Divider()
                    HStack {
                        if step > 1 {
                            Button("上一步") { step -= 1 }.buttonStyle(.bordered)
                        }
                        Spacer()
                        if step < 4 {
                            Button("下一步") { step += 1 }
                                .buttonStyle(.borderedProminent)
                                .disabled(selectedCompoundId == nil && preselectedCompoundId == nil)
                        } else {
                            Button("保存") { save() }.buttonStyle(.borderedProminent)
                        }
                    }.padding()
                }
                .background(.regularMaterial)
            }
            .navigationTitle("记录看房")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }

    // ── Step 1 ──
    private var stepBasicInfo: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("小区") {
                if let c = compound {
                    Text(c.name).font(.headline)
                } else {
                    Picker("选择小区", selection: $selectedCompoundId) {
                        Text("请选择…").tag(Optional<UUID>.none)
                        ForEach(compounds) { c in Text(c.name).tag(Optional(c.id)) }
                    }
                    .pickerStyle(.menu)
                }
            }
            GroupBox("日期") { DatePicker("", selection: $visitDate, displayedComponents: .date).labelsHidden() }
            GroupBox("楼层") {
                Picker("楼层", selection: $floorCategory) {
                    Text("低层 (1–3)").tag("低层")
                    Text("中层 (4–9)").tag("中层")
                    Text("高层 (10+)").tag("高层")
                }
                .pickerStyle(.segmented)
            }
            GroupBox("面积 \(Int(areaM2))㎡") {
                Slider(value: $areaM2, in: 40...250, step: 5)
            }
            GroupBox("报价 \(askPriceWan)万") {
                Stepper("", value: $askPriceWan, in: 50...5000, step: 5).labelsHidden()
            }
        }
        .padding()
    }

    // ── Step 2 ──
    private var stepRatings: some View {
        VStack(alignment: .leading, spacing: 16) {
            ratingRow("总评", rating: $ratingOverall)
            ratingRow("采光", rating: $ratingLight)
            ratingRow("噪音", rating: $ratingNoise, note: "(5=最静)")
            ratingRow("户型", rating: $ratingLayout)
            ratingRow("物业", rating: $ratingProperty)
        }
        .padding()
    }
    private func ratingRow(_ label: String, rating: Binding<Int>, note: String = "") -> some View {
        HStack {
            Text(label + note).frame(width: 80, alignment: .leading)
            StarRatingView(rating: rating, size: 28, interactive: true)
        }
    }

    // ── Step 3 ──
    private var stepTags: some View {
        TagPickerView(selectedTagIds: $selectedTagIds)
    }

    // ── Step 4 ──
    private var stepPhotoText: some View {
        VStack(alignment: .leading, spacing: 16) {
            PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                Label("选择照片", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity).padding()
                    .background(Color(.tertiarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .onChange(of: photoItems) { _, items in
                Task {
                    photos = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            photos.append(img)
                        }
                    }
                }
            }
            if !photos.isEmpty {
                Text("\(photos.count) 张已选").font(.caption).foregroundStyle(.secondary)
            }
            GroupBox("备注（可选）") {
                TextField("自由记录…", text: $freeText, axis: .vertical)
                    .lineLimit(4...8)
            }
        }
        .padding()
    }

    private func save() {
        guard let cid = selectedCompoundId ?? preselectedCompoundId else { return }
        let visit = Visit(compoundId: cid, visitDate: visitDate)
        visit.ratingOverall = ratingOverall
        visit.ratingLight = ratingLight
        visit.ratingNoise = ratingNoise
        visit.ratingLayout = ratingLayout
        visit.ratingProperty = ratingProperty
        visit.freeText = freeText.isEmpty ? nil : freeText
        visit.areaM2 = areaM2
        visit.askPriceWan = askPriceWan
        context.insert(visit)

        for tagId in selectedTagIds {
            context.insert(VisitTag(visitId: visit.id, tagId: tagId))
        }
        for img in photos {
            let photo = Photo(visitId: visit.id, compoundId: cid)
            photo.imageData = img.jpegData(compressionQuality: 0.8)
            context.insert(photo)
        }

        if (try? context.fetch(FetchDescriptor<PropertyMark>(
            predicate: #Predicate { $0.compoundId == cid }
        )).first) == nil {
            let mark = PropertyMark(compoundId: cid, status: "看过")
            context.insert(mark)
        } else {
            let existing = (try? context.fetch(FetchDescriptor<PropertyMark>(
                predicate: #Predicate { $0.compoundId == cid }
            )).first)
            existing?.status = "看过"
        }

        try? context.save()
        dismiss()
    }
}

struct PhotoMosaicBackground: View {
    let images: [UIImage]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
            ForEach(images.indices, id: \.self) { i in
                Image(uiImage: images[i]).resizable().scaledToFill()
                    .frame(height: 120).clipped()
            }
        }
        .overlay(Color.black.opacity(0.45))
        .ignoresSafeArea()
    }
}
```

- [ ] **Step 3: Build and verify**

`Cmd+B` → no errors. Run on simulator → tap `+` in Visit tab → wizard sheet opens with 4 steps. Photo picker on step 4 shows mosaic background once photos selected. Save creates Visit + marks compound as "看过".

- [ ] **Step 4: Commit**
```bash
git add TianjinHouse/Detail/VisitWizardView.swift TianjinHouse/Components/TagPickerView.swift
git commit -m "feat: 4-step visit wizard with photo mosaic background + tag picker"
```

---

## Task 12: Zone Tab + PolygonEditor

**Files:**
- Modify: `TianjinHouse/Drawer/ZoneTabView.swift`
- Modify: `TianjinHouse/Map/PolygonEditorView.swift`

- [ ] **Step 1: Build ZoneTabView**

```swift
// TianjinHouse/Drawer/ZoneTabView.swift
import SwiftUI
import SwiftData

struct ZoneTabView: View {
    @Query(sort: \UserArea.createdAt, order: .reverse) private var areas: [UserArea]
    @Environment(MapSelectionState.self) private var selection
    @State private var showEditor = false
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if areas.isEmpty {
                EmptyStateView(
                    icon: "pencil.and.outline",
                    title: "还没有自定义区域",
                    subtitle: "手动圈定感兴趣的地块",
                    ctaTitle: "+ 绘制新区域",
                    ctaAction: { showEditor = true }
                )
            } else {
                List {
                    ForEach(areas) { area in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(hex: area.fillColorHex).opacity(0.5))
                                .frame(width: 24, height: 24)
                            VStack(alignment: .leading) {
                                Text(area.name).font(.system(size: 14, weight: .semibold))
                                Text(area.kind).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { area.isVisible },
                                set: { area.isVisible = $0; try? context.save() }
                            )).labelsHidden()
                        }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(areas[i]) }
                        try? context.save()
                    }
                }
                .listStyle(.insetGrouped)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showEditor = true } label: { Image(systemName: "plus") }
                    }
                }
            }
        }
        .sheet(isPresented: $showEditor) { PolygonEditorView() }
    }
}
```

- [ ] **Step 2: Build PolygonEditorView**

```swift
// TianjinHouse/Map/PolygonEditorView.swift
import SwiftUI
import MapKit
import SwiftData

struct PolygonEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vertices: [CLLocationCoordinate2D] = []
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.1, longitude: 117.2),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    @State private var areaName = ""
    @State private var areaKind = "custom"
    @State private var showNameSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    if vertices.count >= 3 {
                        MapPolygon(coordinates: vertices + [vertices[0]])
                            .foregroundStyle(Color.accentColor.opacity(0.2))
                            .stroke(Color.accentColor, lineWidth: 2)
                    }
                    ForEach(vertices.indices, id: \.self) { i in
                        Annotation("", coordinate: vertices[i]) {
                            Circle()
                                .fill(.white)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                                .gesture(DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        let region = MKCoordinateRegion(center: vertices[i], span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001))
                                        _ = region  // drag handled via tap-replacement
                                    }
                                )
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .onTapGesture { location in
                    // Convert screen point to coordinate using MapReader
                    // This needs MapReader proxy — see MapReader note below
                }

                // Crosshair for precise tapping
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "plus").font(.title2).foregroundStyle(.accentColor)
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            .safeAreaInset(edge: .bottom) {
                editorControls
            }
            .navigationTitle("绘制区域")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .sheet(isPresented: $showNameSheet) { namingSheet }
    }

    private var editorControls: some View {
        HStack(spacing: 12) {
            Button { if !vertices.isEmpty { vertices.removeLast() } } label: {
                Label("撤销", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered).disabled(vertices.isEmpty)

            Button { vertices = [] } label: {
                Label("清空", systemImage: "trash")
            }
            .buttonStyle(.bordered).disabled(vertices.isEmpty)

            Spacer()

            Text("\(vertices.count) 个点")
                .font(.caption).foregroundStyle(.secondary)

            Button("完成") { showNameSheet = true }
                .buttonStyle(.borderedProminent)
                .disabled(vertices.count < 3)
        }
        .padding()
        .background(.regularMaterial)
    }

    private var namingSheet: some View {
        NavigationStack {
            Form {
                TextField("区域名称", text: $areaName)
                Picker("类型", selection: $areaKind) {
                    Text("自定义").tag("custom")
                    Text("通勤圈").tag("commute")
                    Text("排除区域").tag("exclusion")
                    Text("学区私版").tag("school_zone_alt")
                }
            }
            .navigationTitle("命名区域")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveArea() }.disabled(areaName.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { showNameSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveArea() {
        guard let geojson = try? GeoJSONHelper.encodePolygon(vertices) else { return }
        let area = UserArea(name: areaName, kind: areaKind, geometry: geojson)
        context.insert(area)
        try? context.save()
        dismiss()
    }
}
```

> **PolygonEditor tap note:** The `Map` view's `.onTapGesture` receives a `CGPoint` in view space. To convert to `CLLocationCoordinate2D`, wrap the Map in `MapReader { proxy in Map(...).onTapGesture { loc in let coord = proxy.convert(loc, from: .local) } }`. The `MapReader` API is available in iOS 17+.

- [ ] **Step 3: Apply MapReader fix**

Replace the `Map(position: $cameraPosition)` and its `.onTapGesture` with:

```swift
MapReader { proxy in
    Map(position: $cameraPosition) { /* overlays as above */ }
        .onTapGesture { location in
            if let coord = proxy.convert(location, from: .local) {
                vertices.append(coord)
            }
        }
}
```

- [ ] **Step 4: Build + verify**

`Cmd+R` → Zone tab shows empty state. Tap `+ 绘制新区域` → editor opens. Tap map to add points → polygon draws. 3+ points → "完成" enabled → name sheet → save → appears in Zone tab list.

- [ ] **Step 5: Commit**
```bash
git add TianjinHouse/Drawer/ZoneTabView.swift TianjinHouse/Map/PolygonEditorView.swift
git commit -m "feat: zone tab + polygon editor with tap-to-add vertices"
```

---

## Task 13: Error + Offline States

**Files:**
- Modify: `TianjinHouse/States/OfflineBannerView.swift`
- Create: `TianjinHouse/States/CloudKitGateView.swift`
- Modify: `TianjinHouse/Drawer/DrawerContainerView.swift` (add gate overlay)
- Modify: `TianjinHouse/TianjinHouseApp.swift` (monitor CloudKit status)

- [ ] **Step 1: Build OfflineBannerView**

```swift
// TianjinHouse/States/OfflineBannerView.swift
import SwiftUI
import Network

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    var isConnected = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.isConnected = path.status == .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "network.monitor"))
    }
}

struct OfflineBannerView: View {
    @State private var network = NetworkMonitor.shared

    var body: some View {
        if !network.isConnected {
            HStack(spacing: 6) {
                Circle().fill(.orange).frame(width: 7, height: 7)
                Text("离线 · 缓存地图 · 同步暂停").font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(.black.opacity(0.7)).clipShape(Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: network.isConnected)
        }
    }
}
```

- [ ] **Step 2: Build CloudKitGateView**

```swift
// TianjinHouse/States/CloudKitGateView.swift
import SwiftUI
import CloudKit

@Observable
final class CloudKitStatusMonitor {
    static let shared = CloudKitStatusMonitor()
    var accountStatus: CKAccountStatus = .couldNotDetermine

    private init() { Task { await refresh() } }

    func refresh() async {
        accountStatus = (try? await CKContainer.default().accountStatus()) ?? .couldNotDetermine
    }
}

struct CloudKitGateView<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var monitor = CloudKitStatusMonitor.shared
    @State private var localOnly = false

    var body: some View {
        ZStack {
            content.opacity(needsGate && !localOnly ? 0.15 : 1)
            if needsGate && !localOnly {
                VStack(spacing: 16) {
                    Text("☁️").font(.system(size: 52))
                    Text("需要 iCloud 账户").font(.title2.bold())
                    Text("你的看房记录需要 iCloud 存储。\n请在「设置 › Apple ID」中登录。")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("前往设置") {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("仅本地使用") { localOnly = true }
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("本地数据不会丢失").font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
        }
        .task { await monitor.refresh() }
    }

    private var needsGate: Bool {
        monitor.accountStatus == .noAccount || monitor.accountStatus == .restricted
    }
}
```

- [ ] **Step 3: Apply gate to DrawerContainerView**

Wrap the drawer `VStack` content in `CloudKitGateView`:

```swift
// In DrawerContainerView.body, wrap the entire VStack:
CloudKitGateView {
    VStack(spacing: 0) {
        // ... existing tab bar, search, content
    }
}
```

- [ ] **Step 4: Commit**
```bash
git add TianjinHouse/States/
git commit -m "feat: offline banner + CloudKit gate overlay on drawer"
```

---

## Task 14: Map-Drawer Selection Sync + Compound Detail Sheet

**Files:**
- Modify: `TianjinHouse/Map/MapContainerView.swift` (handle tap → show detail)
- Modify: `TianjinHouse/RootView.swift` (overlay detail sheet)

- [ ] **Step 1: Add compound detail presentation to RootView**

```swift
// TianjinHouse/RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(MapSelectionState.self) private var selection
    @Query private var compounds: [Compound]

    private var selectedCompound: Compound? {
        compounds.first { $0.id == selection.selectedCompoundId }
    }

    var body: some View {
        @Bindable var sel = selection
        GeometryReader { geo in
            HStack(spacing: 0) {
                MapContainerView()
                    .frame(width: geo.size.width * 0.618)
                Divider()
                DrawerContainerView()
                    .frame(width: geo.size.width * 0.382)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .ignoresSafeArea()
        .sheet(item: Binding(
            get: { selectedCompound },
            set: { if $0 == nil { sel.selectedCompoundId = nil } }
        )) { compound in
            CompoundDetailView(compound: compound)
        }
    }
}
```

- [ ] **Step 2: Build + end-to-end verify**

`Cmd+R` → tap a grey pin on map → `CompoundDetailView` sheet opens showing 珑璟台 with zone and school info. Dismiss → tap visit tab card → same sheet opens. School tab card → zone polygon highlights on map.

- [ ] **Step 3: Final regression pass**

Manual checklist:
- [ ] First launch: seed progress screen, then main UI
- [ ] Map shows zone polygon in gold/blue
- [ ] Compound pin shows on map; tap → detail sheet
- [ ] School tab: list, tier badges, tap → school detail sheet
- [ ] Visit tab: empty state → `+` → 4-step wizard → save → card appears
- [ ] Zone tab: empty → `+ 绘制` → polygon editor → name → save → list
- [ ] Search: type in drawer → results filter
- [ ] Offline: airplane mode → banner appears on map top

- [ ] **Step 4: Commit**
```bash
git add TianjinHouse/RootView.swift TianjinHouse/Map/MapContainerView.swift
git commit -m "feat: map↔drawer selection sync + compound detail sheet"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered in task |
|---|---|
| Golden ratio 61.8/38.2 split | Task 4 (RootView) |
| School zone polygons (tier-colored) | Task 2 (SchoolZone model) + Task 7 |
| Compound ↔ zone ↔ school query logic | Task 3 (tests) + Task 2 (models) |
| Seed Pipeline (offline CLI) | Task 5 |
| First-launch seed import progress screen | Task 6 |
| Drawer 3 tabs (学校/看房/区域) | Task 8 |
| Search in drawer | Task 8 |
| Visit Wizard in drawer (photo mosaic bg) | Task 11 |
| Tag picker (category chips) | Task 11 |
| Compound detail | Task 10 |
| School detail | Task 9 |
| PolygonEditor (user areas) | Task 12 |
| CloudKit Private DB sync | Task 4 (ModelContainer) |
| Offline banner | Task 13 |
| CloudKit not-signed-in gate | Task 13 |
| Empty states (per tab) | Tasks 9, 10, 12 |
| StarRatingView | Task 10 |
| BuiltinTag seed | Task 6 (SeedImporter inserts tags) |

**Placeholder scan:** No TBDs found. All steps include actual Swift code.

**Type consistency check:**
- `GeoJSONHelper.decodePolygon` defined in Task 2, used in Task 2 (SchoolZone) and Task 3 (UserArea) ✓
- `MapSelectionState.DrawerTab` defined in Task 4, used in Task 8 ✓
- `EmptyStateView` defined in Task 9, used in Tasks 10, 12 ✓
- `StarRatingView` init with `Binding<Int>` and with plain `Int` both defined in Task 10 ✓
- `SeedImporter` in Task 6 matches `SeedImporterTests` in Task 6 ✓
- `Color(hex:)` extension defined in Task 6 `SeedProgressView`, used throughout — move to a shared Extensions file to avoid duplication (**fix:** add `TianjinHouse/Extensions/Color+Hex.swift` and remove inline definition from SeedProgressView in Task 6)
