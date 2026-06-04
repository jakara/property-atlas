import Foundation
import SwiftData

/// 可按 layerId 归属的实体(用于 backfill 与删层成员重指派的泛型遍历)。
protocol LayerAssignable: AnyObject {
    var datasetId: UUID { get }
    var deleted: Bool { get }
    var layerId: UUID? { get set }
}

extension Compound: LayerAssignable {}
extension School: LayerAssignable {}
extension POI: LayerAssignable {}
extension Area: LayerAssignable {}
