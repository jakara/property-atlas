import Foundation
import SwiftData

@Model final class TagExtension {
    var id: UUID = UUID()
    var category: String = ""
    var label: String = ""
    var polarity: String = "中"
    var createdAt: Date = Date()

    init(category: String, label: String, polarity: String = "中") {
        self.category = category
        self.label = label
        self.polarity = polarity
    }
}
