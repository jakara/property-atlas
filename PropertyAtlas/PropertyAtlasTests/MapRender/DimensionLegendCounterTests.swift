import CoreLocation
import Foundation
import MapKit
import Testing
@testable import PropertyAtlas

@MainActor
struct DimensionLegendCounterTests {
    private func item(_ type: String, _ f: [String: AnyJSON], _ lat: Double) -> DimensionLegendCounter.Item {
        .init(
            id: UUID(),
            entity: StyleEntity(entityType: type, id: UUID(), baseFields: f, customFields: [:]),
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: 117.2),
            layerNames: []
        )
    }

    @Test func countsByDimensionValue() {
        let items = [
            item("school", ["grade": .string("重点")], 39.1),
            item("school", ["grade": .string("重点")], 39.1),
            item("school", ["grade": .string("普通")], 39.1),
        ]
        let rows = DimensionLegendCounter.rows(
            dimension: MapDimension(kind: .field, fieldKey: "grade"),
            items: items, region: nil, context: nil, datasetId: nil,
            swatch: { _ in "#FF0000" }
        )
        let byVal = Dictionary(uniqueKeysWithValues: rows.map { ($0.value, $0.total) })
        #expect(byVal["重点"] == 2)
        #expect(byVal["普通"] == 1)
    }
}
