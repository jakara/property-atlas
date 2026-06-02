import Foundation

/// JSON 输入 DTO(对应 compounds.json,原 LegacyCompound)。不进 SwiftData。
struct CompoundSeed: Codable {
    var id: UUID
    var amapPoiId: String?
    var name: String
    var aliases: [String] = []
    var district: String
    var districtGroup: String?
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
    var availableUnits: String?
    var areaSegments: String?
    var priceSegments: String?
    var finishType: String?
    var deliveryTime: String?
    var isNewHouse: Bool = true
    var sourceCode: String?
    var sourceRow: Int?
    var sensitivePros: String?
    var sensitiveCons: String?
    var sensitiveSource: String?
    var sensitiveNote: String?
}
