import Foundation

/// 对应 groups.json(原 SchoolGroup)。
struct GroupSeed: Codable {
    var id: UUID
    var name: String
    var district: String
    var leadsJSON: String = "[]"
    var membersJSON: String = "[]"
    var note: String?
}

/// 对应 compound_school_match.json(原 CompoundSchoolMatch)。
struct MatchSeed: Codable {
    var id: UUID
    var compoundId: UUID
    var compoundName: String
    var district: String
    var mappedDistrict: String?
    var primaryMatchesJSON: String = "[]"
    var middleMatchesJSON: String = "[]"
    var needsManualReview: Bool = false
}

/// 对应 policies.json(原 Policy)。保险:解码留存,无下游消费。
struct PolicySeed: Codable {
    var id: UUID
    var category: String
    var name: String
    var subcategory: String?
    var sourceCode: String?
    var note: String?
    var description_: String?
    var effectiveDate: String?
    var timing: String?
    var eligibilityJSON: String?
    var docsJSON: String?
    var applicableJSON: String?
    var caveatsJSON: String?
    var rulesJSON: String?
    var rulesByDistrictJSON: String?
    var schoolsJSON: String?
    var specificSchools3yrJSON: String?
    var stepsJSON: String?
    var processJSON: String?
}

/// 对应 admission_rates.json(原 AdmissionRate)。保险:无下游消费。
struct AdmissionRateSeed: Codable {
    var id: UUID
    var district: String
    var year: Int
    var gaokaoAdmitPct: Int = 0
    var vocationalAdmitPct: Int = 0
    var sourceCode: String?
}

/// 一次启动 seed 的全部内存输入。migrator 直接消费此结构。
struct SeedBundle {
    var zones: [ZoneSeed] = []
    var schools: [SchoolSeed] = []
    var compounds: [CompoundSeed] = []
    var groups: [GroupSeed] = []
    var matches: [MatchSeed] = []
    var policies: [PolicySeed] = [] // 保险:无下游
    var admissionRates: [AdmissionRateSeed] = [] // 保险:无下游
}
