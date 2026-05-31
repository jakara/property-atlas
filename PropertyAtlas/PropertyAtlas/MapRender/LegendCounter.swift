// PropertyAtlas/PropertyAtlas/MapRender/LegendCounter.swift
import CoreLocation
import Foundation
import MapKit

@MainActor
enum LegendCounter {
    struct Item {
        let id: UUID
        let type: String
        let entity: StyleEntity
        let coordinate: CLLocationCoordinate2D
    }

    struct Row: Identifiable {
        let entityType: String
        let fieldKey: String
        let fieldLabel: String
        let slot: Int
        let value: String
        let swatchHex: String
        let viewport: Int
        let total: Int
        var id: String {
            "\(entityType).\(fieldKey).\(value)"
        }
    }

    static func rows(
        items: [Item],
        configs: [FilterFieldConfig],
        region: MKCoordinateRegion?,
        filter: FilterPredicate,
        layerVisible: Set<UUID>,
        swatch: (_ type: String, _ fieldKey: String, _ value: String) -> String
    ) -> [Row] {
        var fieldKeysByType: [String: [String]] = [:]
        for c in configs where !c.deleted {
            fieldKeysByType[c.entityType, default: []].append(c.fieldKey)
        }

        let bbox = region.map { BBox(region: $0) }
        var out: [Row] = []

        for cfg in configs.filter({ !$0.deleted && $0.showInLegend }).sorted(by: { $0.slot < $1.slot }) {
            let typeKeys = fieldKeysByType[cfg.entityType] ?? []
            var totalByValue: [String: Int] = [:]
            var viewportByValue: [String: Int] = [:]
            for it in items where it.type == cfg.entityType {
                let value = FilterPredicate.display(it.entity.field(cfg.fieldKey))
                guard !value.isEmpty else { continue }
                guard layerVisible.contains(it.id) else { continue }
                guard filter.passes(it.entity, fieldKeys: typeKeys, excludeFieldKey: cfg.fieldKey) else { continue }
                totalByValue[value, default: 0] += 1
                if let bbox, bbox.contains(it.coordinate) {
                    viewportByValue[value, default: 0] += 1
                }
            }
            for value in totalByValue.keys.sorted() {
                out.append(Row(
                    entityType: cfg.entityType, fieldKey: cfg.fieldKey, fieldLabel: cfg.label,
                    slot: cfg.slot, value: value,
                    swatchHex: cfg.showSwatch ? swatch(cfg.entityType, cfg.fieldKey, value) : "#CCCCCC",
                    viewport: viewportByValue[value] ?? 0, total: totalByValue[value] ?? 0
                ))
            }
        }
        return out
    }

    private struct BBox {
        let minLat, maxLat, minLon, maxLon: Double
        init(region: MKCoordinateRegion) {
            minLat = region.center.latitude - region.span.latitudeDelta / 2
            maxLat = region.center.latitude + region.span.latitudeDelta / 2
            minLon = region.center.longitude - region.span.longitudeDelta / 2
            maxLon = region.center.longitude + region.span.longitudeDelta / 2
        }

        func contains(_ c: CLLocationCoordinate2D) -> Bool {
            c.latitude >= minLat && c.latitude <= maxLat && c.longitude >= minLon && c.longitude <= maxLon
        }
    }
}
