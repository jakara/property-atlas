import Foundation
import SwiftData

@Model
final class School {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = "小学"
    var zoneId: UUID?
    var district: String = ""
    var tier: String = "普通"
    var motto: String?
    var websiteUrl: String?
    var foundedYear: Int?
    var isPublicSchool: Bool = true
    var notes: String?
    var sourceUrl: String?
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        type: String,
        zoneId: UUID? = nil,
        district: String,
        tier: String = "普通"
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.zoneId = zoneId
        self.district = district
        self.tier = tier
    }
}
