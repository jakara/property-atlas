import Foundation
import SwiftData

/// 174 楼盘→学校匹配 (compound_school_match.json)
@Model
final class CompoundSchoolMatch {
    var id: UUID = UUID() // 自生 (compound_id md5)
    var compoundId: UUID // 关联 Compound.id
    var compoundName: String = ""
    var district: String = ""
    var mappedDistrict: String?
    var primaryMatchesJSON: String = "[]" // list of {school_id, school_name, match_kind, ...}
    var middleMatchesJSON: String = "[]"
    var needsManualReview: Bool = false

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), compoundId: UUID, compoundName: String, district: String) {
        self.id = id
        self.compoundId = compoundId
        self.compoundName = compoundName
        self.district = district
    }
}
