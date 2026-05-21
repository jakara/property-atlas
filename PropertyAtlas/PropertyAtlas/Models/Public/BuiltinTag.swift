import SwiftData

@Model final class BuiltinTag {
    var id: UUID = UUID()
    var category: String = ""
    var label: String = ""
    var polarity: String = "中"
    var sortOrder: Int = 0
    var version: Int = 1

    init(id: UUID = UUID(), category: String, label: String, polarity: String = "中") {
        self.id = id
        self.category = category
        self.label = label
        self.polarity = polarity
    }
}
