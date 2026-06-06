import Foundation
import SwiftData

/// ViewStyleRule 的谓词。同 ruleId 下多条 AND。op = StyleConditionOp rawValue。
/// equals/notEquals/contains/gte/lte 用 valueString;in 用 valueList;exists 无值。
@Model
final class ViewStyleCondition {
    var id: UUID = UUID()
    var ruleId: UUID = UUID()
    var field: String = ""
    var op: String = "equals"
    var valueString: String?
    var valueList: [String] = []
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), ruleId: UUID, field: String, op: String) {
        self.id = id
        self.ruleId = ruleId
        self.field = field
        self.op = op
    }
}
