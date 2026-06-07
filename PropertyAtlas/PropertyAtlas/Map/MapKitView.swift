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
    var onDoubleTapCoordinate: ((CLLocationCoordinate2D) -> Void)?
    /// 点击系统底图 POI(卫星/混合/标准全彩)→ 取 MKMapItem 详情 → 外部地点详情卡。
    var onSelectMapItem: ((MKMapItem) -> Void)?
    var mapStyle: StudioMapStyle = .mutedLight

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let v = MKMapView()
        v.delegate = context.coordinator
        v.preferredConfiguration = mapStyle.configuration
        v.overrideUserInterfaceStyle = mapStyle.interfaceStyle
        context.coordinator.lastMapStyle = mapStyle
        v.showsBuildings = false
        v.showsCompass = false
        v.showsScale = false
        v.selectableMapFeatures = [.pointsOfInterest]
        v.setCamera(camera, animated: false)
        configure(v)
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:))
        )
        v.addGestureRecognizer(longPress)
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator
        v.addGestureRecognizer(doubleTap)
        context.coordinator.myDoubleTap = doubleTap
        context.coordinator.suppressSystemDoubleTapZoom(on: v)
        context.coordinator.mapViewRef = v
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.onSchoolSelect = onSchoolSelect
        context.coordinator.onLongPressCoordinate = onLongPressCoordinate
        context.coordinator.onDoubleTapCoordinate = onDoubleTapCoordinate
        context.coordinator.onSelectMapItem = onSelectMapItem
        context.coordinator.rendererFor = rendererFor
        context.coordinator.cameraBinding = $camera
        context.coordinator.lastAppliedCamera = camera.copy() as? MKMapCamera
        return v
    }

    func updateUIView(_ v: MKMapView, context: Context) {
        context.coordinator.onRegionChange = onRegionChange
        context.coordinator.onSchoolSelect = onSchoolSelect
        context.coordinator.onLongPressCoordinate = onLongPressCoordinate
        context.coordinator.onDoubleTapCoordinate = onDoubleTapCoordinate
        context.coordinator.onSelectMapItem = onSelectMapItem
        context.coordinator.rendererFor = rendererFor
        context.coordinator.cameraBinding = $camera
        context.coordinator.suppressSystemDoubleTapZoom(on: v)
        if context.coordinator.lastMapStyle != mapStyle {
            context.coordinator.lastMapStyle = mapStyle
            v.preferredConfiguration = mapStyle.configuration
            v.overrideUserInterfaceStyle = mapStyle.interfaceStyle
        }
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
        // Annotations: 内容(id/坐标/样式/dim/highlight)未变则跳过全量拆/建。
        // 之前每次 body 重算都 removeAll+addAll → 重建数百个 annotation view +
        // 触发选中闪烁。pan / zoom 不跨层级时 pin 不变 → 现直接跳过,零 churn。
        let sig = Coordinator.annotationSignature(annotations)
        if sig != context.coordinator.lastAnnotationSig {
            context.coordinator.lastAnnotationSig = sig
            context.coordinator.isRefreshingAnnotations = true
            v.removeAnnotations(v.annotations)
            v.addAnnotations(annotations)
            context.coordinator.isRefreshingAnnotations = false
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var onRegionChange: ((MKCoordinateRegion) -> Void)?
        var onSchoolSelect: ((UUID?) -> Void)?
        var rendererFor: ((MKOverlay) -> MKOverlayRenderer?)?
        var cameraBinding: Binding<MKMapCamera>?
        var lastAppliedCamera: MKMapCamera?
        weak var mapViewRef: MKMapView?
        var onLongPressCoordinate: ((CLLocationCoordinate2D) -> Void)?
        var onDoubleTapCoordinate: ((CLLocationCoordinate2D) -> Void)?
        var onSelectMapItem: ((MKMapItem) -> Void)?
        weak var myDoubleTap: UITapGestureRecognizer?
        var lastMapStyle: StudioMapStyle?
        var isRefreshingAnnotations = false
        var lastAnnotationSig: Int?
        private var regionSettle: DispatchWorkItem?
        /// 低于此 zoom 隐藏所有文字标签(只留圆点)。城市概览 ~11-12,街区 ~15+。
        private static let labelMinZoom: Double = 13
        private var lastLabelsAllowed: Bool?

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            guard g.state == .began, let mv = mapViewRef else { return }
            let pt = g.location(in: mv)
            let coord = mv.convert(pt, toCoordinateFrom: mv)
            onLongPressCoordinate?(coord)
        }

        @objc func handleDoubleTap(_ g: UITapGestureRecognizer) {
            guard g.state == .ended, let mv = mapViewRef else { return }
            let pt = g.location(in: mv)
            let coord = mv.convert(pt, toCoordinateFrom: mv)
            onDoubleTapCoordinate?(coord)
        }

        /// 让系统自带的「双击缩放」手势等待我们的双击失败 → 双击只触发坐标查询,不缩放。
        /// MKMapView 的手势可能在自身或子视图上,递归处理;在 make/update 调用,require(toFail:) 幂等。
        func suppressSystemDoubleTapZoom(on view: UIView) {
            guard let mine = myDoubleTap else { return }
            func walk(_ target: UIView) {
                for recognizer in target.gestureRecognizers ?? [] {
                    if let tap = recognizer as? UITapGestureRecognizer,
                       tap.numberOfTapsRequired == 2, tap !== mine
                    {
                        tap.require(toFail: mine)
                    }
                }
                target.subviews.forEach(walk)
            }
            walk(view)
        }

        /// 允许与其它手势并存(长按/拖动/缩放),仅靠 require(toFail:) 抑制双击缩放。
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func mapView(_ mv: MKMapView, didSelect view: MKAnnotationView) {
            // 系统底图 POI:取 MKMapItem 详情后冒泡;立即取消选中(不留高亮)。
            if let feature = view.annotation as? MKMapFeatureAnnotation {
                let request = MKMapItemRequest(mapFeatureAnnotation: feature)
                request.getMapItem { [weak self] item, _ in
                    if let item { self?.onSelectMapItem?(item) }
                }
                mv.deselectAnnotation(feature, animated: false)
                return
            }
            #if targetEnvironment(macCatalyst)
            if let pin = view.annotation as? PinAnnotation {
                onSchoolSelect?(pin.entityId)
            }
            #endif
        }

        #if targetEnvironment(macCatalyst)
        func mapView(_ mv: MKMapView, didDeselect view: MKAnnotationView) {
            // Ignore deselect caused by our own annotation refresh (remove/re-add);
            // only a genuine user deselect should clear app selection.
            guard !isRefreshingAnnotations else { return }
            if view.annotation is PinAnnotation {
                onSchoolSelect?(nil)
            }
        }
        #endif

        func mapView(_ mv: MKMapView, regionDidChangeAnimated animated: Bool) {
            // regionDidChange 在拖/缩过程中连续高频触发。每次写回 @State 都会让上层 body
            // 全量重算 + 重建全部 annotation → 卡顿。改为 debounce:手势停稳后只写回一次。
            // 期间不更新 lastAppliedCamera,使任何 interim updateUIView 的 cameraEquals 仍为
            // true(old vs old)而不推送相机,避免覆盖用户拖动。
            let cam = (mv.camera.copy() as? MKMapCamera) ?? mv.camera
            let region = mv.region
            regionSettle?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.lastAppliedCamera = cam
                self.cameraBinding?.wrappedValue = cam
                self.updateLabelVisibility(region: region)
                self.onRegionChange?(region)
            }
            regionSettle = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }

        /// region settle 时按 zoom 跨阈值切换标签显隐。仅刷新当前可见的 pin view,不重建 annotation。
        private func updateLabelVisibility(region: MKCoordinateRegion) {
            #if targetEnvironment(macCatalyst)
            let allowed = ZoomLevel.from(region: region) >= Self.labelMinZoom
            guard allowed != lastLabelsAllowed else { return }
            lastLabelsAllowed = allowed
            PinAnnotationView.labelsAllowed = allowed
            guard let mv = mapViewRef else { return }
            for annotation in mv.annotations {
                (mv.view(for: annotation) as? PinAnnotationView)?.applyLabelVisibility()
            }
            #endif
        }

        // 内容签名:仅当 pin 集合或任一 pin 视觉属性变化才重建 annotation。
        static func annotationSignature(_ anns: [MKAnnotation]) -> Int {
            var hasher = Hasher()
            hasher.combine(anns.count)
            for ann in anns {
                #if targetEnvironment(macCatalyst)
                if let pin = ann as? PinAnnotation {
                    hasher.combine(pin.entityId)
                    hasher.combine(pin.coordinate.latitude)
                    hasher.combine(pin.coordinate.longitude)
                    hasher.combine(pin.style.fillHex)
                    hasher.combine(pin.style.strokeHex)
                    hasher.combine(pin.style.glyph)
                    hasher.combine(pin.style.glyphHex)
                    hasher.combine(pin.style.size)
                    hasher.combine(pin.style.labelVisible)
                    hasher.combine(String(describing: pin.style.shape))
                    hasher.combine(pin.name)
                    hasher.combine(pin.dimmed)
                    hasher.combine(pin.highlighted)
                    continue
                }
                #endif
                hasher.combine(ObjectIdentifier(ann))
            }
            return hasher.finalize()
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
