#if targetEnvironment(macCatalyst)
import CoreLocation
import Foundation
import MapKit

final class ZoneCentroidAnnotation: NSObject, MKAnnotation {
    let zoneId: UUID
    let name: String
    let tier: String
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(zone: SchoolZone, centroid: CLLocationCoordinate2D) {
        self.zoneId = zone.id
        self.name = zone.name
        self.tier = zone.tier
        self.coordinate = centroid
    }

    var title: String? {
        name
    }
}
#endif
