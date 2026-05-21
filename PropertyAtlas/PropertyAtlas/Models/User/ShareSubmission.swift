import Foundation
import SwiftData

@Model final class ShareSubmission {
    var id: UUID = UUID()
    var sourceTable: String = ""
    var sourceId: UUID = UUID()
    var targetPubTable: String = ""
    var payloadJson: String = ""
    var userNote: String?
    var status: String = "draft"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(sourceTable: String, sourceId: UUID, targetPubTable: String, payloadJson: String) {
        self.sourceTable = sourceTable
        self.sourceId = sourceId
        self.targetPubTable = targetPubTable
        self.payloadJson = payloadJson
    }
}
