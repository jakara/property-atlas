#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit

struct StudioCameraPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let center: CLLocationCoordinate2D
    let distance: CLLocationDistance
    let pitch: CGFloat
    let heading: CLLocationDirection

    var camera: MKMapCamera {
        MKMapCamera(
            lookingAtCenter: center,
            fromDistance: distance,
            pitch: pitch,
            heading: heading
        )
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (l: StudioCameraPreset, r: StudioCameraPreset) -> Bool {
        l.id == r.id
    }
}

extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (l: CLLocationCoordinate2D, r: CLLocationCoordinate2D) -> Bool {
        l.latitude == r.latitude && l.longitude == r.longitude
    }
}

enum CameraPresets {
    static let seed: [StudioCameraPreset] = [
        .init(id: "和平区", name: "和平区", center: .init(latitude: 39.125, longitude: 117.205), distance: 12000, pitch: 0, heading: 0),
        .init(id: "河西区", name: "河西区", center: .init(latitude: 39.110, longitude: 117.225), distance: 18000, pitch: 0, heading: 0),
        .init(id: "南开区", name: "南开区", center: .init(latitude: 39.130, longitude: 117.150), distance: 18000, pitch: 0, heading: 0),
        .init(id: "河东区", name: "河东区", center: .init(latitude: 39.125, longitude: 117.235), distance: 18000, pitch: 0, heading: 0),
        .init(id: "河北区", name: "河北区", center: .init(latitude: 39.155, longitude: 117.205), distance: 18000, pitch: 0, heading: 0),
        .init(id: "红桥区", name: "红桥区", center: .init(latitude: 39.165, longitude: 117.155), distance: 18000, pitch: 0, heading: 0),
    ]
}
#endif
