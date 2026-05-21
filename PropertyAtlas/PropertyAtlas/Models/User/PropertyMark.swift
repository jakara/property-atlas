import Foundation
import SwiftData

@Model final class PropertyMark {
    var id: UUID = UUID()
    var compoundId: UUID = UUID()
    var status: String = "想看"
    var priority: Int?
    var privateNotes: String?
    var askPriceMinWan: Int?
    var askPriceMaxWan: Int?
    var firstSeenAt: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(compoundId: UUID, status: String = "想看") {
        self.compoundId = compoundId
        self.status = status
        self.firstSeenAt = Date()
    }
}
