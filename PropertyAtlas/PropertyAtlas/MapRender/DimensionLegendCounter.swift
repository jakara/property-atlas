import CoreLocation
import Foundation
import MapKit
import SwiftData

@MainActor
enum DimensionLegendCounter {
    struct Item {
        let id: UUID
        let entity: StyleEntity
        let coordinate: CLLocationCoordinate2D
        let layerNames: [String]
    }

    struct Row: Identifiable {
        let dimensionKey: String
        let value: String
        let swatchHex: String
        let viewport: Int
        let total: Int
        var id: String {
            "\(dimensionKey).\(value)"
        }
    }

    static func rows(
        dimension: MapDimension,
        items: [Item],
        region: MKCoordinateRegion?,
        context: ModelContext?,
        datasetId: UUID?,
        swatch: (_ value: String) -> String
    ) -> [Row] {
        let bbox = region.map { BBox(region: $0) }
        var totalByValue: [String: Int] = [:]
        var viewportByValue: [String: Int] = [:]
        for it in items {
            let input = MapDimension.Input(
                entity: it.entity,
                layerNames: it.layerNames,
                context: context,
                datasetId: datasetId
            )
            for value in dimension.resolve(input) where !value.isEmpty {
                totalByValue[value, default: 0] += 1
                if let bbox, bbox.contains(it.coordinate) { viewportByValue[value, default: 0] += 1 }
            }
        }
        return totalByValue.keys.sorted().map { v in
            Row(
                dimensionKey: dimension.key,
                value: v,
                swatchHex: swatch(v),
                viewport: viewportByValue[v] ?? 0,
                total: totalByValue[v] ?? 0
            )
        }
    }

    // 从预解析好的 entries(已 resolve 的维度值 + 坐标)计数,仅做 region bbox 判断。
    // 用于缓存路径:pan / zoom-settle 时不再触 styleEntity / dimension.resolve。
    #if targetEnvironment(macCatalyst)
    static func rowsFromEntries(
        dimensionKey: String,
        entries: [LegendSpec.Entry],
        region: MKCoordinateRegion?,
        swatch: [String: String]
    ) -> [Row] {
        let bbox = region.map { BBox(region: $0) }
        var totalByValue: [String: Int] = [:]
        var viewportByValue: [String: Int] = [:]
        for entry in entries {
            let inViewport = bbox?.contains(entry.coordinate) ?? false
            for value in entry.values where !value.isEmpty {
                totalByValue[value, default: 0] += 1
                if inViewport { viewportByValue[value, default: 0] += 1 }
            }
        }
        return totalByValue.keys.sorted().map { value in
            Row(
                dimensionKey: dimensionKey,
                value: value,
                swatchHex: swatch[value] ?? "#8E8E93",
                viewport: viewportByValue[value] ?? 0,
                total: totalByValue[value] ?? 0
            )
        }
    }
    #endif

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
