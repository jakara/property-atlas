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
        var category: String?
        var phone: String?
        var url: URL?
        var fullAddress: String?
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
        return response.mapItems.map(placeHit(from:))
    }

    /// MKMapItem → PlaceHit(点击系统底图 POI / 搜索结果共用)。
    static func placeHit(from item: MKMapItem) -> PlaceHit {
        PlaceHit(
            name: item.name ?? "未命名",
            subtitle: subtitle(item.placemark),
            coordinate: item.placemark.coordinate,
            category: categoryLabel(item.pointOfInterestCategory),
            phone: item.phoneNumber,
            url: item.url,
            fullAddress: item.placemark.title ?? subtitle(item.placemark)
        )
    }

    /// 反查坐标处地点(双击地图空白)。CLGeocoder 逆地理编码 → PlaceHit。无结果返回 nil。
    static func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> PlaceHit? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else { return nil }
        let detail = [placemark.locality, placemark.subLocality, placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let name = placemark.name ?? placemark.thoroughfare ?? placemark.areasOfInterest?.first ?? "此处"
        return PlaceHit(
            name: name,
            subtitle: detail,
            coordinate: placemark.location?.coordinate ?? coordinate,
            category: placemark.areasOfInterest?.first,
            phone: nil,
            url: nil,
            fullAddress: detail.isEmpty ? name : detail
        )
    }

    private static func subtitle(_ placemark: MKPlacemark) -> String {
        [placemark.locality, placemark.thoroughfare, placemark.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    /// "MKPOICategoryRestaurant" → "Restaurant";nil → nil。
    private static func categoryLabel(_ category: MKPointOfInterestCategory?) -> String? {
        guard let raw = category?.rawValue else { return nil }
        return raw.replacingOccurrences(of: "MKPOICategory", with: "")
    }
}
#endif
