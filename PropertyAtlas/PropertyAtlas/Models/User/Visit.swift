import Foundation
import SwiftData

@Model final class Visit {
    var id: UUID = UUID()
    var compoundId: UUID = UUID()
    var visitDate: Date = Date()
    var ratingOverall: Int?
    var ratingLight: Int?
    var ratingNoise: Int?
    var ratingLayout: Int?
    var ratingProperty: Int?
    var floorNumber: Int?
    var totalFloors: Int?
    var areaM2: Double?
    var askPriceWan: Int?
    var layout: String?
    var agentName: String?
    var agentPhone: String?
    var freeText: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(compoundId: UUID, visitDate: Date = Date()) {
        self.compoundId = compoundId
        self.visitDate = visitDate
    }
}
