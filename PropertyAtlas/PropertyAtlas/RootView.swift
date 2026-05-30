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
    @Query private var datasets: [Dataset]
    @Query private var compounds: [Compound]
    @Query private var schools: [School]
    @Query private var pois: [POI]
    @Query private var areas: [Area]
    @Query private var styleRules: [StyleRule]
    @Query private var palettes: [Palette]

    @State private var themeContext: ThemeContext?
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var watermark: String = "@公众号名 · PropertyAtlas"
    @State private var aspect: CanvasAspect = .ratio16x9
    @State private var camera: MKMapCamera = .init(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 39.125, longitude: 117.205),
        fromDistance: 12000, pitch: 0, heading: 0
    )
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedEntityId: UUID?

    var body: some View {
        let activeTheme = themeContext?.activeTheme
        let palettesById: [UUID: Palette] = Dictionary(uniqueKeysWithValues: palettes.map { ($0.id, $0) })
        let activeRuleIds = Set(activeTheme?.styleRuleIds ?? [])
        let rulesForTheme = styleRules.filter { activeRuleIds.contains($0.id) }
        let visibility = visibilityFromTheme(activeTheme)

        let pins: [MKAnnotation] = buildPins(
            compounds: visibility["compound"] == true ? compounds : [],
            schools: visibility["school"] == true ? schools : [],
            pois: visibility["poi"] == true ? pois : [],
            theme: activeTheme,
            rules: rulesForTheme,
            palettes: palettesById
        )
        let (overlays, styleMap) = visibility["area"] == true
            ? buildAreaOverlays(areas: areas, theme: activeTheme, rules: rulesForTheme, palettes: palettesById)
            : ([], [:])

        ZStack {
            MapContainerView(
                camera: $camera,
                overlays: overlays,
                annotations: pins,
                rendererFor: { overlay in
                    guard let polygon = overlay as? MKPolygon,
                          let style = styleMap[ObjectIdentifier(overlay)]
                    else { return nil }
                    return AreaOverlayRenderer(polygon: polygon, style: style)
                },
                onRegionChange: { visibleRegion = $0 },
                onSchoolSelect: { id in selectedEntityId = id }
            )
            .ignoresSafeArea()
            if let ctx = themeContext {
                StudioOverlay(
                    title: $title,
                    subtitle: $subtitle,
                    watermark: $watermark,
                    aspect: $aspect,
                    themeContext: ctx
                )
            }
        }
        .onAppear { ensureThemeContext() }
        .onChange(of: datasets.first?.id) { _, _ in ensureThemeContext() }
    }

    private func ensureThemeContext() {
        guard themeContext == nil, let ds = datasets.first(where: { !$0.deleted }) else { return }
        themeContext = ThemeContext(dataset: ds, modelContext: modelContext)
        title = themeContext?.activeTheme?.copyTitle ?? ""
        subtitle = themeContext?.activeTheme?.copySubtitle ?? ""
    }

    private func visibilityFromTheme(_ theme: Theme?) -> [String: Bool] {
        guard let theme,
              let data = theme.visibilityJSON.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Bool]
        else {
            return ["compound": true, "school": true, "poi": true, "area": true]
        }
        return obj
    }

    private func buildPins(
        compounds: [Compound],
        schools: [School],
        pois: [POI],
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette]
    ) -> [MKAnnotation] {
        var result: [MKAnnotation] = []
        for c in compounds where !c.deleted && (c.latitude != 0 || c.longitude != 0) {
            let style = StyleResolver.resolvePin(entity: c.styleEntity, theme: theme, rules: rules, palettes: palettes)
            result.append(PinAnnotation(
                entityId: c.id, entityType: "compound", name: c.name,
                coordinate: c.coordinate, style: style
            ))
        }
        for s in schools where !s.deleted && (s.latitude != 0 || s.longitude != 0) {
            let style = StyleResolver.resolvePin(entity: s.styleEntity, theme: theme, rules: rules, palettes: palettes)
            result.append(PinAnnotation(
                entityId: s.id, entityType: "school", name: s.name,
                coordinate: s.coordinate, style: style
            ))
        }
        for p in pois where !p.deleted && (p.latitude != 0 || p.longitude != 0) {
            let style = StyleResolver.resolvePin(entity: p.styleEntity, theme: theme, rules: rules, palettes: palettes)
            result.append(PinAnnotation(
                entityId: p.id, entityType: "poi", name: p.name,
                coordinate: p.coordinate, style: style
            ))
        }
        return result
    }

    private func buildAreaOverlays(
        areas: [Area],
        theme: Theme?,
        rules: [StyleRule],
        palettes: [UUID: Palette]
    ) -> ([MKOverlay], [ObjectIdentifier: AreaStyle]) {
        var overlays: [MKOverlay] = []
        var map: [ObjectIdentifier: AreaStyle] = [:]
        for a in areas where !a.deleted {
            let style = StyleResolver.resolveArea(entity: a.styleEntity, theme: theme, rules: rules, palettes: palettes)
            if let r = AreaOverlayFactory.makeOverlay(for: a, style: style) {
                overlays.append(r.overlay)
                map[ObjectIdentifier(r.overlay)] = r.style
            }
        }
        return (overlays, map)
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
