import AppKit
import Foundation
import MapKit
import SwiftUI

enum CalibratorApp {
    static func launch(district: String, pngPath: String, zonesPath: String) {
        let app = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1200, height: 800),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Calibrate \(district) raster"
        let view = CalibratorView(district: district, pngPath: pngPath, zonesPath: zonesPath)
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

struct CalibratorView: View {
    let district: String
    let pngPath: String
    let zonesPath: String

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
            }
            .padding(.horizontal)
            Text("拖 4 个红点对齐街道，调透明度后按 Save 写入 zones.json")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    func save() {
        let path = zonesPath
        guard let data = FileManager.default.contents(atPath: path),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var items = root["items"] as? [[String: Any]]
        else {
            print("ERROR: cannot read \(path)")
            return
        }
        var saved = 0
        for i in items.indices {
            guard let d = items[i]["district"] as? String, d == district else { continue }
            items[i]["geometry_stage"] = "raster"
            items[i]["geometry"] = [
                "image": "\(district)学片.png",
                "corners": corners.map { [$0.latitude, $0.longitude] },
            ]
            saved += 1
        }
        root["items"] = items
        let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let out = try! JSONSerialization.data(withJSONObject: root, options: opts)
        try! out.write(to: URL(fileURLWithPath: path))
        print("✓ saved \(saved) zones for \(district)")
    }
}

final class CornerPin: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let index: Int
    init(coordinate: CLLocationCoordinate2D, index: Int) {
        self.coordinate = coordinate
        self.index = index
    }
}

final class CalibratorCoordinator: NSObject, MKMapViewDelegate {
    var binding: Binding<[CLLocationCoordinate2D]>!
    var pngPath: String!
    var alpha: Double = 0.5
    var rasterOverlay: RasterImageOverlay?

    func mapView(_ mv: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let p = annotation as? CornerPin else { return nil }
        let v = MKMarkerAnnotationView(annotation: p, reuseIdentifier: "corner")
        v.markerTintColor = .systemRed
        v.isDraggable = true
        v.glyphText = "\(p.index + 1)"
        return v
    }

    func mapView(
        _ mv: MKMapView,
        annotationView v: MKAnnotationView,
        didChange newState: MKAnnotationView.DragState,
        fromOldState old: MKAnnotationView.DragState
    ) {
        guard let p = v.annotation as? CornerPin,
              newState == .ending || newState == .dragging else { return }
        var arr = binding.wrappedValue
        arr[p.index] = p.coordinate
        binding.wrappedValue = arr
        rasterOverlay?.setCorners(arr)
        mv.removeOverlays(mv.overlays)
        if let o = rasterOverlay { mv.addOverlay(o) }
    }

    func mapView(_ mv: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let o = overlay as? RasterImageOverlay else { return MKOverlayRenderer(overlay: overlay) }
        return RasterImageOverlayRenderer(overlay: o, alpha: CGFloat(alpha))
    }
}

final class RasterImageOverlay: NSObject, MKOverlay {
    let image: NSImage
    var corners: [CLLocationCoordinate2D]
    var coordinate: CLLocationCoordinate2D {
        corners.first ?? .init()
    }

    var boundingMapRect: MKMapRect {
        let pts = corners.map { MKMapPoint($0) }
        let xs = pts.map(\.x)
        let ys = pts.map(\.y)
        return MKMapRect(
            x: xs.min()!, y: ys.min()!,
            width: xs.max()! - xs.min()!,
            height: ys.max()! - ys.min()!
        )
    }

    init(image: NSImage, corners: [CLLocationCoordinate2D]) {
        self.image = image
        self.corners = corners
    }

    func setCorners(_ c: [CLLocationCoordinate2D]) {
        self.corners = c
    }
}

final class RasterImageOverlayRenderer: MKOverlayRenderer {
    let img: NSImage
    let drawAlpha: CGFloat
    init(overlay: RasterImageOverlay, alpha: CGFloat) {
        self.img = overlay.image
        self.drawAlpha = alpha
        super.init(overlay: overlay)
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in ctx: CGContext) {
        guard let raster = overlay as? RasterImageOverlay,
              let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let mapPts = raster.corners.map { MKMapPoint($0) }
        let cgPts = mapPts.map { self.point(for: $0) }
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
        ctx.saveGState()
        ctx.setAlpha(drawAlpha)
        ctx.concatenate(transform)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()
    }
}

struct CalibratorMap: NSViewRepresentable {
    @Binding var corners: [CLLocationCoordinate2D]
    let pngPath: String
    let alpha: Double

    func makeCoordinator() -> CalibratorCoordinator {
        let c = CalibratorCoordinator()
        c.binding = $corners
        c.pngPath = pngPath
        c.alpha = alpha
        return c
    }

    func makeNSView(context: Context) -> MKMapView {
        let v = MKMapView()
        v.delegate = context.coordinator
        v.mapType = .mutedStandard
        v.setRegion(
            MKCoordinateRegion(
                center: .init(latitude: 39.125, longitude: 117.205),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ),
            animated: false
        )
        let pins = corners.enumerated().map { CornerPin(coordinate: $0.element, index: $0.offset) }
        v.addAnnotations(pins)
        if let img = NSImage(contentsOfFile: pngPath) {
            let overlay = RasterImageOverlay(image: img, corners: corners)
            context.coordinator.rasterOverlay = overlay
            v.addOverlay(overlay)
        } else {
            print("⚠ PNG not found at \(pngPath) — pins only")
        }
        return v
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        context.coordinator.alpha = alpha
        context.coordinator.rasterOverlay?.setCorners(corners)
        nsView.removeOverlays(nsView.overlays)
        if let o = context.coordinator.rasterOverlay { nsView.addOverlay(o) }
    }
}
