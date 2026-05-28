// PropertyAtlas/PropertyAtlas/Models/User/VisitPhoto.swift
import Foundation
import SwiftData

@Model final class VisitPhoto {
    var id: UUID = UUID()
    var visitId: UUID?
    var compoundId: UUID?
    var kind: String = "visit"
    var imageData: Data?
    var caption: String?
    var takenAt: Date?
    var width: Int?
    var height: Int?
    var createdAt: Date = Date()

    init(visitId: UUID? = nil, compoundId: UUID? = nil, kind: String = "visit") {
        self.visitId = visitId
        self.compoundId = compoundId
        self.kind = kind
    }
}
