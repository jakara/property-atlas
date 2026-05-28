import MapKit
import SwiftUI

struct MapContainerView: View {
    @Binding var camera: MKMapCamera
    var overlays: [MKOverlay] = []
    var annotations: [MKAnnotation] = []
    var onRegionChange: ((MKCoordinateRegion) -> Void)?
    var onSchoolSelect: ((UUID?) -> Void)?

    init(
        camera: Binding<MKMapCamera>? = nil,
        overlays: [MKOverlay] = [],
        annotations: [MKAnnotation] = [],
        onRegionChange: ((MKCoordinateRegion) -> Void)? = nil,
        onSchoolSelect: ((UUID?) -> Void)? = nil
    ) {
        if let camera {
            self._camera = camera
        } else {
            self._camera = .constant(
                MKMapCamera(
                    lookingAtCenter: CLLocationCoordinate2D(latitude: 39.125, longitude: 117.205),
                    fromDistance: 12000,
                    pitch: 0,
                    heading: 0
                )
            )
        }
        self.overlays = overlays
        self.annotations = annotations
        self.onRegionChange = onRegionChange
        self.onSchoolSelect = onSchoolSelect
    }

    var body: some View {
        MapKitView(
            camera: $camera,
            overlays: overlays,
            annotations: annotations,
            onRegionChange: onRegionChange,
            onSchoolSelect: onSchoolSelect
        )
    }
}
