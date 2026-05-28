import Foundation
import SwiftData

@Model
final class CameraPreset {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var name: String = ""
    var centerLat: Double = 0
    var centerLon: Double = 0
    var distance: Double = 10000
    var pitch: Double = 0
    var heading: Double = 0
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        centerLat: Double,
        centerLon: Double,
        distance: Double,
        pitch: Double = 0,
        heading: Double = 0
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.distance = distance
        self.pitch = pitch
        self.heading = heading
    }
}
