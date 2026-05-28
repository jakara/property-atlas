#if targetEnvironment(macCatalyst)
import CoreLocation
import Foundation
import MapKit
import Testing
import UIKit
@testable import PropertyAtlas

@Suite("CalibratedImageOverlay")
struct CalibratedImageOverlayTests {
    @Test("boundingMapRect covers all 4 corners")
    func bounds() {
        let corners = [
            CLLocationCoordinate2D(latitude: 39.135, longitude: 117.190),
            CLLocationCoordinate2D(latitude: 39.135, longitude: 117.220),
            CLLocationCoordinate2D(latitude: 39.115, longitude: 117.220),
            CLLocationCoordinate2D(latitude: 39.115, longitude: 117.190),
        ]
        let overlay = CalibratedImageOverlay(image: UIImage(), corners: corners)
        let r = overlay.boundingMapRect
        for c in corners {
            #expect(r.contains(MKMapPoint(c)))
        }
    }
}
#endif
