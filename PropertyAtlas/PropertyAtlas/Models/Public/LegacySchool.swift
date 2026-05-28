import Foundation
import SwiftData

@Model
final class LegacySchool {
    var id: UUID = UUID()
    var name: String = ""
    var type: String = "小学" // "小学" / "初中"
    var zoneId: UUID?
    var zoneName: String? // cache from JSON zone_name
    var district: String = ""
    var tier: String = "普通" // coarse: 重点 / 区重点 / 普通

    var address: String?
    var phone: String?
    var campuses: String?
    var communitiesText: String? // 招生范围居委会清单
    var tuition: String?

    var isPublicSchool: Bool = true // !is_private
    var isJiunian: Bool = false
    var is12Year: Bool = false
    var isMarketFive: Bool = false
    var isMarketKey: Bool = false

    var sourceCode: String? // 信源缩写 (JM-PDF 等)
    var notes: String?

    // legacy / 未来字段
    var motto: String?
    var websiteUrl: String?
    var foundedYear: Int?
    var sourceUrl: String?

    var lat: Double?
    var lon: Double?
    var geocodeSource: String?
    var geocodeConfidence: String?

    // sensitive subobject (flat with sens_ prefix)
    var sensitiveTierLetter: String?
    var sensitiveTierLabel: String? // 原始 label, e.g. 强校/优质 (区别 coarse tier)
    var sensitiveRankOverall: Int?
    var sensitiveTopPercentile: Int?
    var sensitiveTierRank: Int?
    var sensitiveComment: String?
    var sensitiveDataOrigin: String?
    var sensitiveSource: String?
    var sensitiveSourceUrl: String?
    var sensitiveNote: String?

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
