import SwiftUI

#if targetEnvironment(macCatalyst)
import MapKit
import SwiftData
#endif

struct RootView: View {
    @Environment(AppMode.self) private var appMode

    var body: some View {
        switch appMode.value {
        case .explore: ExploreRootView()
        case .studio: StudioRootView()
        }
    }
}

struct ExploreRootView: View {
    @Environment(MapSelectionState.self) private var selection

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
    @Environment(\.modelContext) private var modelContext
    @Query private var zones: [SchoolZone]
    @Query private var schools: [School]

    @State private var title: String = "和平区学区分布图"
    @State private var subtitle: String = "2026 招生季"
    @State private var watermark: String = "@公众号名 · PropertyAtlas"
    @State private var selectedPreset: StudioCameraPreset = CameraPresets.seed[0]
    @State private var aspect: CanvasAspect = .ratio16x9
    @State private var showZoneFill = false // hull 不准, 默认关; pin 颜色已表达 zone 归属
    @State private var showSchoolPins = true
    @State private var showSchoolLabels = true
    @State private var filter = PinFilter()
    @State private var camera: MKMapCamera = CameraPresets.seed[0].camera
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedSchoolId: UUID?

    var body: some View {
        let filteredSchools = schools.filter { filter.includes(school: $0) }
        let overlays: [MKOverlay] = showZoneFill
            ? zones.compactMap {
                try? ZoneGeometryImporter.makeOverlay(
                    for: $0,
                    imageProvider: ZoneGeometryImporter.bundledImage(named:)
                )
            }
            : []
        let zoneNameById: [UUID: String] = Dictionary(
            uniqueKeysWithValues: zones.map { ($0.id, $0.name) }
        )
        let visibleZones = computeVisibleZones(
            schools: filteredSchools,
            zoneNameById: zoneNameById,
            region: visibleRegion
        )
        let zoneColorByName: [String: String] = Dictionary(
            uniqueKeysWithValues: visibleZones.map { ($0.name, $0.colorHex) }
        )
        let pins: [MKAnnotation] = showSchoolPins
            ? filteredSchools
            .filter { $0.lat != nil && $0.lon != nil }
            .map { school -> MKAnnotation in
                let zName = school.zoneId.flatMap { zoneNameById[$0] }
                let displayName: String? = zName.map {
                    ZoneShortLabel.displayName(district: school.district, zoneName: $0)
                }
                let hex = displayName.flatMap { zoneColorByName[$0] }
                return SchoolAnnotation(
                    school: school,
                    zoneName: zName,
                    zoneColorHex: hex,
                    showName: showSchoolLabels
                )
            }
            : []

        ZStack {
            MapContainerView(
                camera: $camera,
                overlays: overlays,
                annotations: pins,
                onRegionChange: { visibleRegion = $0 },
                onSchoolSelect: { selectedSchoolId = $0 }
            )
            .ignoresSafeArea()
            StudioOverlay(
                title: $title,
                subtitle: $subtitle,
                watermark: $watermark,
                selectedPreset: $selectedPreset,
                aspect: $aspect,
                showZoneFill: $showZoneFill,
                showSchoolPins: $showSchoolPins,
                showSchoolLabels: $showSchoolLabels,
                filter: $filter,
                visibleZones: visibleZones,
                selectedSchoolId: $selectedSchoolId,
                onSnapshot: snapshot
            )
        }
        .onChange(of: selectedPreset) { _, new in
            camera = new.camera
        }
        .onReceive(NotificationCenter.default.publisher(for: .studioPresetSelected)) { note in
            if let p = note.object as? StudioCameraPreset { selectedPreset = p }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadSeeds)) { _ in
            reloadSeeds()
        }
    }

    private func reloadSeeds() {
        do {
            try modelContext.delete(model: SchoolZone.self)
            try modelContext.delete(model: School.self)
            try modelContext.delete(model: Compound.self)
            try modelContext.save()
            try SeedImporter.runIfNeeded(into: modelContext)
            print("✓ 热更新完成: \(schools.count) schools, \(zones.count) zones")
        } catch {
            print("✗ 热更新失败: \(error)")
        }
    }

    private func computeVisibleZones(
        schools: [School],
        zoneNameById: [UUID: String],
        region: MKCoordinateRegion?
    ) -> [StudioLegend.VisibleZone] {
        guard let r = region else { return [] }
        let minLat = r.center.latitude - r.span.latitudeDelta / 2
        let maxLat = r.center.latitude + r.span.latitudeDelta / 2
        let minLon = r.center.longitude - r.span.longitudeDelta / 2
        let maxLon = r.center.longitude + r.span.longitudeDelta / 2

        // 1. 全 zone 统计 (不限 viewport): zoneId → school count (已过 filter)
        var countByZoneId: [UUID: Int] = [:]
        for s in schools {
            guard let zid = s.zoneId else { continue }
            countByZoneId[zid, default: 0] += 1
        }

        // 2. viewport 内出现过的 zone (display name + zoneId) — 唯一 + 排序
        var seenDisplay = Set<String>()
        var entries: [(display: String, zoneId: UUID)] = []
        for s in schools {
            guard let lat = s.lat, let lon = s.lon else { continue }
            if lat < minLat || lat > maxLat || lon < minLon || lon > maxLon { continue }
            guard let zid = s.zoneId,
                  let zname = zoneNameById[zid],
                  !zname.isEmpty,
                  !zname.contains("行政区域")
            else { continue }
            let display = ZoneShortLabel.displayName(district: s.district, zoneName: zname)
            if seenDisplay.insert(display).inserted {
                entries.append((display, zid))
            }
        }
        entries.sort { $0.display < $1.display }

        // 3. Index-based palette + count
        return entries.enumerated().map { i, e in
            let c = ZoneColorPalette.colors[i % ZoneColorPalette.colors.count]
            return StudioLegend.VisibleZone(
                name: e.display,
                colorHex: Self.hexOf(c),
                count: countByZoneId[e.zoneId] ?? 0
            )
        }
    }

    private static func hexOf(_ c: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }

    private func snapshot() {
        let snapView = StudioOverlay(
            title: .constant(title),
            subtitle: .constant(subtitle),
            watermark: .constant(watermark),
            selectedPreset: .constant(selectedPreset),
            aspect: .constant(aspect),
            showZoneFill: .constant(showZoneFill),
            showSchoolPins: .constant(showSchoolPins),
            showSchoolLabels: .constant(showSchoolLabels),
            filter: .constant(filter),
            visibleZones: computeVisibleZones(
                schools: schools.filter { filter.includes(school: $0) },
                zoneNameById: Dictionary(uniqueKeysWithValues: zones.map { ($0.id, $0.name) }),
                region: visibleRegion
            ),
            selectedSchoolId: .constant(nil),
            onSnapshot: {},
            showToolbar: false
        )
        SnapshotExporter.export(
            camera: selectedPreset.camera,
            aspect: aspect,
            overlayView: snapView,
            district: selectedPreset.name
        ) { result in
            switch result {
            case let .success(url): print("✓ saved \(url.path)")
            case let .failure(e): print("✗ snapshot failed: \(e)")
            }
        }
    }
}
#else
struct StudioRootView: View {
    var body: some View {
        Text("Studio Mode 仅在 Mac 端可用。")
    }
}
#endif

struct ToolbarView: View {
    var body: some View {
        Color.clear
    }
}

extension Notification.Name {
    static let studioPresetSelected = Notification.Name("studioPresetSelected")
    static let reloadSeeds = Notification.Name("reloadSeeds")
}
