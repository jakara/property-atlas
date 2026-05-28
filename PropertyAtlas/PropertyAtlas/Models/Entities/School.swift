import CoreLocation
import Foundation
import SwiftData

@Model
final class School {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()

    var name: String = ""
    var aliases: [String] = []
    var address: String?
    var latitude: Double = 0
    var longitude: Double = 0
    var primaryAreaId: UUID?
    var notes: String?
    var privateNotes: String?
    var customFieldsJSON: String?
    var overrideStyleJSON: String?
    var photoIds: [UUID] = []
    var contactPhone: String?
    var contactWechat: String?
    var contactName: String?
    var sourceUrl: String?

    var category: String?
    var grade: String?
    var form: String?
    var foundYear: Int?
    var capacity: Int?
    var communitiesText: String?
    var phone: String?
    var websiteUrl: String?
    var motto: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        latitude: Double,
        longitude: Double
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
