import CoreLocation
import SwiftData

@Model
final class Compound {
    var id: UUID = UUID()
    var amapPoiId: String?
    var name: String = ""
    var aliases: [String] = []
    var district: String = ""
    var streetBlock: String?
    var address: String = ""
    var latitude: Double = 39.1
    var longitude: Double = 117.2
    var zoneId: UUID?
    var primarySchoolId: UUID?
    var buildYear: Int?
    var developer: String?
    var propertyMgmt: String?
    var totalBuildings: Int?
    var greeningRatio: Double?
    var parkingRatio: Double?
    var propertyFeeCents: Int?
    var landYears: Int?
    var sourceUrl: String?
    var contributedBy: String?
    var verifiedAt: Date?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        district: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.name = name
        self.district = district
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
