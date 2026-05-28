#if targetEnvironment(macCatalyst)
import Foundation

/// Parse 1-char marker from `zone_name` for pin glyph.
/// Examples:
///   "第一学片"            → "一"
///   "第一学区(北片)"      → "北"
///   "第二学区(中片)"      → "中"
///   "第三学区(南片)"      → "南"
///   "津南区-七"          → "七"
///   "滨海新区-塘沽3"     → "3"
///   "全区招生"           → "全"
///   "特殊学校"           → "特"
///   "民办初中全区招生"   → "全"
///   "其他民办小学"       → "民"
///   "行政区域"           → ""  (郊区无学片)
enum ZoneShortLabel {
    /// Display name for legend: "和平一片" / "南开北片" / "津南-七" / "和平·特殊学校" 等.
    static func displayName(district: String, zoneName: String) -> String {
        let distTrim = district.replacingOccurrences(of: "区", with: "")
        let short = shortLabel(for: zoneName)
        if zoneName.contains("学区") || zoneName.contains("学片"), !short.isEmpty {
            return "\(distTrim)\(short)片"
        }
        if zoneName.contains("-"), !short.isEmpty {
            return "\(distTrim)-\(short)"
        }
        // 全区招生 / 特殊学校 / 民办初中全区招生 等 — 保留完整 zone 名 + district 前缀
        return "\(distTrim)·\(zoneName)"
    }

    static func shortLabel(for zoneName: String) -> String {
        if zoneName.contains("北片") { return "北" }
        if zoneName.contains("中片") { return "中" }
        if zoneName.contains("南片") { return "南" }
        // 第N学[片区]
        for ch in "一二三四五六七八九十" {
            if zoneName.contains("第\(ch)学") { return String(ch) }
        }
        // 后缀 -N (CN 或 digit)
        if let dashIdx = zoneName.lastIndex(of: "-") {
            let tail = zoneName[zoneName.index(after: dashIdx)...]
            for ch in tail {
                if "一二三四五六七八九十0123456789".contains(ch) {
                    return String(ch)
                }
            }
        }
        // 塘沽/汉沽/大港 + digit
        for prefix in ["塘沽", "汉沽", "大港", "大沽"] {
            if let r = zoneName.range(of: prefix) {
                let tail = zoneName[r.upperBound...]
                for ch in tail where ch.isNumber {
                    return String(ch)
                }
            }
        }
        if zoneName.contains("全区") { return "全" }
        if zoneName.contains("特殊") { return "特" }
        if zoneName.contains("民办") { return "民" }
        return ""
    }
}
#endif
