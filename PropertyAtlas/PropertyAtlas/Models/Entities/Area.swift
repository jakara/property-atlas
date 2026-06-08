import CoreLocation
import Foundation
import SwiftData

@Model
final class Area {
    var id: UUID = UUID()
    var datasetId: UUID = UUID()
    var layerId: UUID?

    var name: String = ""
    var aliases: [String] = []
    var notes: String?
    var privateNotes: String?
    var customFieldsJSON: String?
    var overrideStyleJSON: String?
    // 强类型 override(nil = 继承视图默认)。取代 overrideStyleJSON(后续阶段删旧列)。
    var styleFillHex: String?
    var styleFillOpacity: Double?
    var styleStrokeHex: String?
    var styleStrokeWidth: Double?
    var styleLabelVisible: Bool?
    var photoIds: [UUID] = []
    var sourceUrl: String?

    var geometryKind: String = "polygon"
    var geometryJSON: String = ""
    var rasterImageRef: String?

    var category: String?
    /// 自由文本标签(多值)。区分用途,如行政区下的"街道"。
    var tags: [String] = []
    var strokeHex: String?
    var fillOpacity: Double = 0.2
    var textDescription: String?

    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        datasetId: UUID,
        name: String,
        geometryKind: String = "polygon",
        geometryJSON: String = ""
    ) {
        self.id = id
        self.datasetId = datasetId
        self.name = name
        self.geometryKind = geometryKind
        self.geometryJSON = geometryJSON
    }

    // MARK: - Raster geometry decoding (mirrors LegacySchoolZone.decodeRaster)

    struct RasterGeometry {
        let image: String
        let corners: [CLLocationCoordinate2D]
    }

    static func decodeRaster(_ json: String) throws -> RasterGeometry {
        guard let data = json.data(using: .utf8) else {
            throw GeoJSONHelper.GeoJSONError.invalidUTF8
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any],
              let image = dict["image"] as? String,
              let corners = dict["corners"] as? [[Double]],
              corners.count == 4
        else {
            throw GeoJSONHelper.GeoJSONError.invalidStructure
        }
        return RasterGeometry(
            image: image,
            corners: corners.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
        )
    }
}
