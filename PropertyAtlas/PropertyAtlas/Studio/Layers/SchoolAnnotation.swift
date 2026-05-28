#if targetEnvironment(macCatalyst)
import CoreLocation
import Foundation
import MapKit

final class SchoolAnnotation: NSObject, MKAnnotation {
    let schoolId: UUID
    let name: String
    let level: String // "小学" / "初中" / "九年一贯"
    let shortLabel: String // 学片号: "一"/"北"/"全"/...
    let tier: String // "重点"/"区重点"/"普通" — glyph on pin
    let showName: Bool // pin 上是否显示校名 label
    let zoneName: String? // for color lookup fallback
    let zoneColorHex: String? // viewport-assigned color (优先于 hash)
    let isJiunian: Bool // 决定 hexagon 形状
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(
        school: School,
        zoneName: String?,
        zoneColorHex: String? = nil,
        showName: Bool = true
    ) {
        self.schoolId = school.id
        self.name = school.name
        self.level = school.type
        self.tier = school.tier
        self.shortLabel = zoneName.map(ZoneShortLabel.shortLabel(for:)) ?? ""
        self.showName = showName
        self.zoneName = zoneName
        self.zoneColorHex = zoneColorHex
        self.isJiunian = school.isJiunian
        self.coordinate = CLLocationCoordinate2D(
            latitude: school.lat ?? 0,
            longitude: school.lon ?? 0
        )
    }

    var title: String? {
        name
    }
}
#endif
