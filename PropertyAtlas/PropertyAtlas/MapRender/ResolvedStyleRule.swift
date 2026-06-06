import Foundation

/// resolver 用的纯内存规则(RootView 预取时由 ViewStyleRule + 其 ViewStyleCondition 组装)。
/// 避免 resolver 内查 DB / 解析 JSON。conditions 全部 AND;空 → 永远命中。
struct ResolvedStyleRule {
    let pinPartial: PartialPinStyle
    let areaPartial: PartialAreaStyle
    let priority: Int
    let enabled: Bool
    let conditions: [StyleCondition]
}
