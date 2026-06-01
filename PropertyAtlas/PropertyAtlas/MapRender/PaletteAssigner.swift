import Foundation

/// 分类配色:值→色。FNV-1a 选首选槽,同屏内线性探测避重(值数 ≤ palette 才保证全异),
/// 超容量才复用。同值稳定(纯函数于 sorted values + palette)。
enum PaletteAssigner {
    /// 8 色高对比内置板(ColorBrewer Set1 改,跳黄,白字可读)。供默认分类染色。
    static let highContrast: [String] = [
        "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3",
        "#FF7F00", "#A65628", "#F781BF", "#17BECF",
    ]

    static func assign(values: [String], palette: [String]) -> [String: String] {
        guard !palette.isEmpty else { return [:] }
        var used = Set<Int>()
        var map: [String: String] = [:]
        for v in values.sorted() {
            var idx = Int(StableHash.fnv1a32(v) % UInt32(palette.count))
            if used.count < palette.count {
                var probe = 0
                while used.contains(idx) && probe < palette.count {
                    idx = (idx + 1) % palette.count
                    probe += 1
                }
            }
            used.insert(idx)
            map[v] = palette[idx]
        }
        return map
    }
}
