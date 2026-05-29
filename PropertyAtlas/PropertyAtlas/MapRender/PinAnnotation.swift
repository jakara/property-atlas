#if targetEnvironment(macCatalyst)
import Foundation
import MapKit

final class PinAnnotation: NSObject, MKAnnotation {
    let entityId: UUID
    let entityType: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let style: PinStyle

    init(
        entityId: UUID,
        entityType: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        style: PinStyle
    ) {
        self.entityId = entityId
        self.entityType = entityType
        self.name = name
        self.coordinate = coordinate
        self.style = style
    }

    var title: String? {
        name
    }
}
#endif
