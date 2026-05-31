// PropertyAtlasTests/MapRender/LegendCounterTests.swift
import CoreLocation
import Foundation
import MapKit
import Testing
@testable import PropertyAtlas

@MainActor
struct LegendCounterTests {
    private func item(
        _ id: UUID,
        _ type: String,
        _ fields: [String: AnyJSON],
        _ lat: Double,
        _ lon: Double
    ) -> LegendCounter.Item {
        LegendCounter.Item(
            id: id,
            type: type,
            entity: StyleEntity(entityType: type, id: id, baseFields: fields, customFields: [:]),
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
        )
    }

    private let cfg = FilterFieldConfig(
        datasetId: UUID(),
        entityType: "school",
        fieldKey: "category",
        fieldSource: "base",
        label: "阶段",
        slot: 1
    )

    private func bbox(_ latC: Double, _ lonC: Double, _ d: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: .init(latitude: latC, longitude: lonC),
            span: MKCoordinateSpan(latitudeDelta: d, longitudeDelta: d)
        )
    }

    @Test func groupsByValueWithTotalCounts() {
        let items = [
            item(UUID(), "school", ["category": .string("小学")], 39.1, 117.1),
            item(UUID(), "school", ["category": .string("小学")], 39.1, 117.1),
            item(UUID(), "school", ["category": .string("初中")], 39.1, 117.1),
        ]
        let rows = LegendCounter.rows(
            items: items,
            configs: [cfg],
            region: bbox(39.1, 117.1, 1),
            filter: FilterPredicate(hidden: [:]),
            layerVisible: Set(items.map(\.id)),
            swatch: { _, _, _ in "#000000" }
        )
        #expect(rows.first { $0.value == "小学" }?.total == 2)
        #expect(rows.first { $0.value == "初中" }?.total == 1)
    }

    @Test func viewportExcludesOutsideBbox() {
        let inId = UUID()
        let outId = UUID()
        let items = [
            item(inId, "school", ["category": .string("小学")], 39.1, 117.1),
            item(outId, "school", ["category": .string("小学")], 10.0, 10.0),
        ]
        let rows = LegendCounter.rows(
            items: items,
            configs: [cfg],
            region: bbox(39.1, 117.1, 0.5),
            filter: FilterPredicate(hidden: [:]),
            layerVisible: Set([inId, outId]),
            swatch: { _, _, _ in "#000000" }
        )
        let r = rows.first { $0.value == "小学" }
        #expect(r?.total == 2)
        #expect(r?.viewport == 1)
    }

    @Test func selfFieldFilterExcludedFromOwnCount() {
        let items = [item(UUID(), "school", ["category": .string("小学")], 39.1, 117.1)]
        let rows = LegendCounter.rows(
            items: items,
            configs: [cfg],
            region: bbox(39.1, 117.1, 1),
            filter: FilterPredicate(hidden: ["school.category": Set(["小学"])]),
            layerVisible: Set(items.map(\.id)),
            swatch: { _, _, _ in "#000000" }
        )
        #expect(rows.first { $0.value == "小学" }?.total == 1)
    }

    @Test func layerInvisibleExcluded() {
        let visible = UUID()
        let hidden = UUID()
        let items = [
            item(visible, "school", ["category": .string("小学")], 39.1, 117.1),
            item(hidden, "school", ["category": .string("小学")], 39.1, 117.1),
        ]
        let rows = LegendCounter.rows(
            items: items,
            configs: [cfg],
            region: bbox(39.1, 117.1, 1),
            filter: FilterPredicate(hidden: [:]),
            layerVisible: Set([visible]),
            swatch: { _, _, _ in "#000000" }
        )
        #expect(rows.first { $0.value == "小学" }?.total == 1)
    }
}
