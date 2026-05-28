import Foundation
import SwiftData

@available(*, deprecated, message: "P1 removed; policy-sensitive, no replacement. Will be removed in P5.")
@Model final class SchoolScore {
    var id: UUID = UUID()
    var schoolId: UUID = UUID()
    var year: Int = 2024
    var rankCity: Int?
    var topPercentile: Double?
    var rawJson: String?
    var createdAt: Date = Date()

    init(id: UUID = UUID(), schoolId: UUID, year: Int) {
        self.id = id
        self.schoolId = schoolId
        self.year = year
    }
}
