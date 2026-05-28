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
        let (tl, tr, bl) = (cgPts[0], cgPts[1], cgPts[3])
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let transform = CGAffineTransform(
            a: (tr.x - tl.x) / w,
            b: (tr.y - tl.y) / w,
            c: (bl.x - tl.x) / h,
            d: (bl.y - tl.y) / h,
            tx: tl.x,
            ty: tl.y
        )
        let zoomFactor = max(0.1, min(1.0, 1.0 - Double(log2(zoomScale)) * 0.2))
        ctx.saveGState()
        ctx.setAlpha(baseAlpha * CGFloat(zoomFactor))
        ctx.concatenate(transform)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()
    }
}
#endif
