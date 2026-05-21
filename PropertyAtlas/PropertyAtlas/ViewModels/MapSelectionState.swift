import MapKit
import SwiftUI

@Observable
final class MapSelectionState {
    var selectedCompoundId: UUID?
    var selectedZoneId: UUID?
    var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.1, longitude: 117.2),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    var searchQuery: String = ""
    var isSearching: Bool = false
    var activeDrawerTab: DrawerTab = .schools

    enum DrawerTab { case schools, visits, zones }
}
