import Foundation
import SwiftData

/// 32 集团办学关系 (groups.json)
@available(*, deprecated, message: "P1 replaced by Edge entities. Will be removed in P5.")
@Model
final class SchoolGroup {
    var id: UUID = UUID()
    var name: String = ""
    var district: String = ""
    var leadsJSON: String = "[]" // [{name, school_id, matched_school}]
    var membersJSON: String = "[]" // [{name, school_id, matched_school, ...}]
    var note: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), name: String, district: String) {
        self.id = id
        self.name = name
        self.district = district
    }
}
