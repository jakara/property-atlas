import Foundation

/// JSON 输入 DTO(对应 schools.json,原 LegacySchool)。不进 SwiftData。
struct SchoolSeed: Codable {
    var id: UUID
    var name: String
    var type: String = "小学"
    var zoneId: UUID?
    var zoneName: String?
    var district: String
    var tier: String = "普通"
    var address: String?
    var phone: String?
    var campuses: String?
    var communitiesText: String?
    var tuition: String?
    var isPublicSchool: Bool = true
    var isJiunian: Bool = false
    var is12Year: Bool = false
    var isMarketFive: Bool = false
    var isMarketKey: Bool = false
    var sourceCode: String?
    var notes: String?
    var motto: String?
    var websiteUrl: String?
    var foundedYear: Int?
    var sourceUrl: String?
    var lat: Double?
    var lon: Double?
    var geocodeSource: String?
    var geocodeConfidence: String?
    var sensitiveTierLetter: String?
    var sensitiveTierLabel: String?
    var sensitiveRankOverall: Int?
    var sensitiveTopPercentile: Int?
    var sensitiveTierRank: Int?
    var sensitiveComment: String?
    var sensitiveDataOrigin: String?
    var sensitiveSource: String?
    var sensitiveSourceUrl: String?
    var sensitiveNote: String?
}
