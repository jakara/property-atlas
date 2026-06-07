import MapKit
import SwiftUI

struct MapContainerView: View {
    @Binding var camera: MKMapCamera
    var overlays: [MKOverlay] = []
    var annotations: [MKAnnotation] = []
    var rendererFor: ((MKOverlay) -> MKOverlayRenderer?)?
    var onRegionChange: ((MKCoordinateRegion) -> Void)?
    var onSchoolSelect: ((UUID?) -> Void)?
    var onLongPressCoordinate: ((CLLocationCoordinate2D) -> Void)?
    var onDoubleTapCoordinate: ((CLLocationCoordinate2D) -> Void)?

    init(
        camera: Binding<MKMapCamera>? = nil,
        overlays: [MKOverlay] = [],
        annotations: [MKAnnotation] = [],
        rendererFor: ((MKOverlay) -> MKOverlayRenderer?)? = nil,
        onRegionChange: ((MKCoordinateRegion) -> Void)? = nil,
        onSchoolSelect: ((UUID?) -> Void)? = nil,
        onLongPressCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil,
        onDoubleTapCoordinate: ((CLLocationCoordinate2D) -> Void)? = nil
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
        self.rendererFor = rendererFor
        self.onRegionChange = onRegionChange
        self.onSchoolSelect = onSchoolSelect
        self.onLongPressCoordinate = onLongPressCoordinate
        self.onDoubleTapCoordinate = onDoubleTapCoordinate
    }

    var body: some View {
        MapKitView(
            camera: $camera,
            overlays: overlays,
            annotations: annotations,
            rendererFor: rendererFor,
            onRegionChange: onRegionChange,
            onSchoolSelect: onSchoolSelect,
            onLongPressCoordinate: onLongPressCoordinate,
            onDoubleTapCoordinate: onDoubleTapCoordinate
        )
    }
}
