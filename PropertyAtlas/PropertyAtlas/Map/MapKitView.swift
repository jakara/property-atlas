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
    var onLongPressCoordinate: ((CLLocationCoordinate2D) -> Void)?

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
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:))
        )
        v.addGestureRecognizer(longPress)
        context.coordinator.mapViewRef = v
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.onSchoolSelect = onSchoolSelect
        context.coordinator.onLongPressCoordinate = onLongPressCoordinate
        context.coordinator.rendererFor = rendererFor
        context.coordinator.cameraBinding = $camera
        context.coordinator.lastAppliedCamera = camera.copy() as? MKMapCamera
        return v
    }

    func updateUIView(_ v: MKMapView, context: Context) {
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.onSchoolSelect = onSchoolSelect
        context.coordinator.onLongPressCoordinate = onLongPressCoordinate
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
        weak var mapViewRef: MKMapView?
        var onLongPressCoordinate: ((CLLocationCoordinate2D) -> Void)?

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began, let mv = mapViewRef else { return }
            let pt = g.location(in: mv)
            let coord = mv.convert(pt, toCoordinateFrom: mv)
            onLongPressCoordinate?(coord)
        }

        #if targetEnvironment(macCatalyst)
        func mapView(_ mv: MKMapView, didSelect view: MKAnnotationView) {
            if let pin = view.annotation as? PinAnnotation {
                onSchoolSelect?(pin.entityId)
            }
        }

        func mapView(_ mv: MKMapView, didDeselect view: MKAnnotationView) {
            if view.annotation is PinAnnotation {
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
            if let line = overlay as? MKPolyline {
                return EdgeLineRenderer(polyline: line)
            }
            #endif
            #if targetEnvironment(macCatalyst)
            if let raster = overlay as? CalibratedImageOverlay {
                return CalibratedImageOverlayRenderer(overlay: raster)
            }
            #endif
            if let poly = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: poly)
                let color = UIColor.systemTeal
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
            return nil
        }
        #endif
    }
}
