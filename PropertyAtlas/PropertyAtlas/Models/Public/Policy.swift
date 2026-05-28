import Foundation
import SwiftData

/// 25 政策 (policies.json) — 落户/入学/转学/小升初/中考/高考
@Model
final class Policy {
    var id: UUID = UUID()
    var category: String = "" // 落户 / 入学 / ...
    var subcategory: String?
    var name: String = ""
    var sourceCode: String?
    var note: String?

    // 数组/字典字段都 JSON-encode 为 String, 检索/展示时 decode
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

    var description_: String?
    var effectiveDate: String?
    var timing: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), category: String, name: String) {
        self.id = id
        self.category = category
        self.name = name
    }
}
