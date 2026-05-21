import SwiftData

@Model final class AdmissionDoc {
    var id: UUID = UUID()
    var title: String = ""
    var district: String = ""
    var year: Int = 2024
    var docType: String = "招生简章"
    var sourceUrl: String?
    var ocrText: String?
    var createdAt: Date = Date()

    init(id: UUID = UUID(), title: String, district: String, year: Int) {
        self.id = id
        self.title = title
        self.district = district
        self.year = year
    }
}
