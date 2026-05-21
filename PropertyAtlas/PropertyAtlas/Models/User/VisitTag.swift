import Foundation
import SwiftData

@Model final class VisitTag {
    var id: UUID = UUID()
    var visitId: UUID = UUID()
    var tagId: UUID = UUID()
    var tagSource: String = "builtin"

    init(visitId: UUID, tagId: UUID, tagSource: String = "builtin") {
        self.visitId = visitId
        self.tagId = tagId
        self.tagSource = tagSource
    }
}
