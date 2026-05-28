import Foundation
import SwiftData

/// 19 区中考录取率 (admission_rates.json) — 顶层 sensitive=true
@available(*, deprecated, message: "P1 removed; policy-sensitive, no replacement. Will be removed in P5.")
@Model
final class AdmissionRate {
    var id: UUID = UUID() // 自生 (district+year md5)
    var district: String = ""
    var year: Int = 0
    var gaokaoAdmitPct: Int = 0
    var vocationalAdmitPct: Int = 0
    var sourceCode: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(id: UUID = UUID(), district: String, year: Int) {
        self.id = id
        self.district = district
        self.year = year
    }
}
