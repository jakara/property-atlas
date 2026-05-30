import MapKit
import SwiftUI

struct MapKitView: UIViewRepresentable {
    @Binding var camera: MKMapCamera
    var overlays: [MKOverlay] = []
    var annotations: [MKAnnotation] = []
    var configure: (MKMapView) -> Void = { _ in }
    var rendererFor: ((MKOverlay) -> MKOverlayRenderer?)?
    var onRegionChange: ((MKCoordinateRegion) -> Void)?
    var onSchoolSelect: ((UUID?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

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
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.onSchoolSelect = onSchoolSelect
        context.coordinator.rendererFor = rendererFor
        context.coordinator.cameraBinding = $camera
        context.coordinator.lastAppliedCamera = camera.copy() as? MKMapCamera
        return v
    }

    func updateUIView(_ v: MKMapView, context: Context) {
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.onSchoolSelect = onSchoolSelect
        context.coordinator.rendererFor = rendererFor
        context.coordinator.cameraBinding = $camera
        // Only push camera if it actually changed (preset 跳转); 否则用户拖动/缩放会被覆盖
        if !Coordinator.cameraEquals(context.coordinator.lastAppliedCamera, camera) {
            v.setCamera(camera, animated: true)
            context.coordinator.lastAppliedCamera = camera.copy() as? MKMapCamera
        }
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
        var onRegionChange: ((MKCoordinateRegion) -> Void)?
        var onSchoolSelect: ((UUID?) -> Void)?
        var rendererFor: ((MKOverlay) -> MKOverlayRenderer?)?
        var cameraBinding: Binding<MKMapCamera>?
        var lastAppliedCamera: MKMapCamera?

        #if targetEnvironment(macCatalyst)
        func mapView(_ mv: MKMapView, didSelect view: MKAnnotationView) {
            if let s = view.annotation as? SchoolAnnotation {
                onSchoolSelect?(s.schoolId)
            }
        }

        func mapView(_ mv: MKMapView, didDeselect view: MKAnnotationView) {
            if view.annotation is SchoolAnnotation {
                onSchoolSelect?(nil)
            }
        }
        #endif

        func mapView(_ mv: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 用户拖/缩 → 同步 mv.camera 回 binding, 防止下次 updateUIView 拿旧值覆盖
            let cam = (mv.camera.copy() as? MKMapCamera) ?? mv.camera
            lastAppliedCamera = cam
            cameraBinding?.wrappedValue = cam
            onRegionChange?(mv.region)
        }

        static func cameraEquals(_ a: MKMapCamera?, _ b: MKMapCamera) -> Bool {
            guard let a else { return false }
            return abs(a.centerCoordinate.latitude - b.centerCoordinate.latitude) < 1e-5
                && abs(a.centerCoordinate.longitude - b.centerCoordinate.longitude) < 1e-5
                && abs(a.altitude - b.altitude) < 1
                && abs(a.heading - b.heading) < 0.1
                && abs(a.pitch - b.pitch) < 0.1
        }

        func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let renderer = rendererFor?(overlay) {
                return renderer
            }
            #if targetEnvironment(macCatalyst)
            if let raster = overlay as? CalibratedImageOverlay {
                return CalibratedImageOverlayRenderer(overlay: raster)
            }
            #endif
            if let poly = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: poly)
                #if targetEnvironment(macCatalyst)
                let color = ZoneColorPalette.color(fromHex: poly.title ?? "")
                #else
                let color = UIColor.systemTeal
                #endif
                r.fillColor = color.withAlphaComponent(0.28)
                r.strokeColor = color.withAlphaComponent(0.85)
                r.lineWidth = 1.6
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        #if targetEnvironment(macCatalyst)
        func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let pin = annotation as? PinAnnotation {
                let v = (mv.dequeueReusableAnnotationView(withIdentifier: PinAnnotationView.reuseIdentifier) as? PinAnnotationView)
                    ?? PinAnnotationView(annotation: pin, reuseIdentifier: PinAnnotationView.reuseIdentifier)
                v.annotation = pin
                v.displayPriority = .required
                return v
            }
            if let s = annotation as? SchoolAnnotation {
                let v = (mv.dequeueReusableAnnotationView(withIdentifier: SchoolPinView.reuseIdentifier) as? SchoolPinView)
                    ?? SchoolPinView(annotation: s, reuseIdentifier: SchoolPinView.reuseIdentifier)
                v.annotation = s
                v.displayPriority = .required
                return v
            }
            if let z = annotation as? ZoneCentroidAnnotation {
                let v = MKMarkerAnnotationView(annotation: z, reuseIdentifier: "zone")
                v.markerTintColor = ZoneColorPalette.color(for: z.name)
                v.glyphText = "区"
                v.glyphTintColor = .white
                v.titleVisibility = .visible
                return v
            }
            return nil
        }

        /// 小学 = accent500 棕 (#B5703A); 中学/九年一贯 = 深靛 (#364E6B)
        static func colorForLevel(_ level: String) -> UIColor {
            if level.contains("小") {
                return UIColor(red: 0xB5 / 255.0, green: 0x70 / 255.0, blue: 0x3A / 255.0, alpha: 1)
            }
            return UIColor(red: 0x36 / 255.0, green: 0x4E / 255.0, blue: 0x6B / 255.0, alpha: 1)
        }

        /// Used when shortLabel empty (郊区 etc.) — fall back to level glyph.
        static func fallbackGlyph(_ level: String) -> String {
            if level.contains("小") { return "小" }
            if level.contains("九") { return "九" }
            if level.contains("中") || level.contains("初") { return "中" }
            return "校"
        }
        #endif
    }
}
