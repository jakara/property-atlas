// PropertyAtlas/PropertyAtlas/Studio/StudioRenderCache.swift
#if targetEnvironment(macCatalyst)
import CoreLocation
import Foundation
import MapKit

/// 内容签名用:读 count + maxUpdatedAt 检测某类型实体的增/删/改。
protocol MapEntityVersioning {
    var datasetId: UUID { get }
    var deleted: Bool { get }
    var updatedAt: Date { get }
}

extension Compound: MapEntityVersioning {}
extension School: MapEntityVersioning {}
extension POI: MapEntityVersioning {}
extension Area: MapEntityVersioning {}

/// 图例一组的预解析规格:维度值已 resolve 完(只在内容变化时算一次),
/// settle/pan 时仅按 region 做 bbox 计数,无需再触 styleEntity / dimension.resolve。
struct LegendSpec {
    struct Entry {
        let coordinate: CLLocationCoordinate2D
        let values: [String]
    }

    let title: String
    let dimensionKey: String
    let togglable: Bool
    /// groupBy 染色图例:仅显示视口内有值的行(viewport>0)。
    let dropZeroViewport: Bool
    let swatch: [String: String]
    let entries: [Entry]
}

/// Studio 渲染管线缓存。内容签名(不含 visibleRegion)未变时复用 pins/overlays/图例规格,
/// 把"手势停稳后整条管线重算"降为"仅图例视口重计数"。纯引用类型 + @State 存储,
/// mutate 其属性不触发 SwiftUI 失效(仅作缓存)。
@MainActor
final class StudioRenderCache {
    var sig: Int?
    var pins: [MKAnnotation] = []
    var overlays: [MKOverlay] = []
    var styleMap: [ObjectIdentifier: AreaStyle] = [:]
    var legendSpecs: [LegendSpec] = []
}
#endif
