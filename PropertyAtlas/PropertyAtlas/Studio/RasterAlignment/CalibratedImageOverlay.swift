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

    var coordinate: CLLocationCoordinate2D {
        corners.first ?? CLLocationCoordinate2D()
    }

    var boundingMapRect: MKMapRect {
        let pts = corners.map { MKMapPoint($0) }
        let xs = pts.map(\.x)
        let ys = pts.map(\.y)
        return MKMapRect(
            x: xs.min()!,
            y: ys.min()!,
            width: xs.max()! - xs.min()!,
            height: ys.max()! - ys.min()!
        )
    }
}
#endif
