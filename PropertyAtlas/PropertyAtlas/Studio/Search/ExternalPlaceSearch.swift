#if targetEnvironment(macCatalyst)
import CoreLocation
import MapKit

/// Apple 地点搜索包装。spec §6.4:Apple MKLocalSearch 覆盖大陆主流地点,高德先不引入。
enum ExternalPlaceSearch {
    struct PlaceHit: Identifiable {
        let id = UUID()
        let name: String
        let subtitle: String
        let coordinate: CLLocationCoordinate2D
    }

    static let fallbackRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.125, longitude: 117.205),
        span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
    )

    /// naturalLanguageQuery + region 偏置。空 query → []。失败/无网 → 抛错。
    static func search(_ query: String, region: MKCoordinateRegion?) async throws -> [PlaceHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.region = region ?? fallbackRegion
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.map { item in
            PlaceHit(
                name: item.name ?? "未命名",
                subtitle: subtitle(item.placemark),
                coordinate: item.placemark.coordinate
            )
        }
    }

    private static func subtitle(_ placemark: MKPlacemark) -> String {
        [placemark.locality, placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}
#endif
