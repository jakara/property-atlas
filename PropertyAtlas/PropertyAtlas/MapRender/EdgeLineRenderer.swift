#if targetEnvironment(macCatalyst)
import MapKit
import UIKit

final class EdgeLineRenderer: MKPolylineRenderer {
    override init(polyline: MKPolyline) {
        super.init(polyline: polyline)
        strokeColor = UIColor.systemIndigo.withAlphaComponent(0.7)
        lineWidth = 2
        lineDashPattern = [4, 4]
    }
}
#endif
