import Foundation

/// 片区显示名:`区短名 + 判别词`,解决图例里跨区重名(如多区都叫「第一学区」)。
/// 保留原后缀语义:学片→片、学区→区;南开括号「(北片)」保留北/中/南;
/// 行政区域只留区短名;自带「{区}-」前缀的(津南/滨海)剥前缀。
enum AreaNameFormatter {
    private static let cnNumerals: Set<Character> = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    static func displayName(district: String, zoneName: String) -> String {
        let short = districtShort(district)

        // 行政区域 → 仅区短名(北辰 / 宝坻 / …)
        if zoneName == "行政区域" { return short }

        // 自带 "{district}-" 前缀 → 剥离
        let prefix = district + "-"
        if zoneName.hasPrefix(prefix) {
            let rem = String(zoneName.dropFirst(prefix.count))
            // 纯中文数字(津南区-一)→ 短名 + 数字 + 区
            if !rem.isEmpty, rem.allSatisfy({ cnNumerals.contains($0) }) {
                return short + rem + "区"
            }
            return rem // 塘沽1 / 生态城 / 空港 …
        }

        // 第N学片 / 第N学区 [(X片)]
        if let parsed = parseSchoolZone(zoneName) {
            if let paren = parsed.paren { return short + paren } // 南开北片
            return short + parsed.numeral + parsed.suffix // 和平一片 / 河西一区
        }

        // 兜底:加区短名前缀消歧(全区招生 → 和平全区招生 等)
        return short + zoneName
    }

    static func districtShort(_ district: String) -> String {
        if district == "滨海新区" { return "滨海" }
        if district.hasSuffix("区") { return String(district.dropLast()) }
        return district
    }

    private struct SchoolZone {
        let numeral: String
        let suffix: String
        let paren: String?
    }

    private static func parseSchoolZone(_ s: String) -> SchoolZone? {
        guard s.hasPrefix("第") else { return nil }
        var rest = s.dropFirst() // 一学片…
        var num = ""
        while let c = rest.first, cnNumerals.contains(c) {
            num.append(c)
            rest = rest.dropFirst()
        }
        guard !num.isEmpty else { return nil }
        let suffix: String
        if rest.hasPrefix("学片") {
            suffix = "片"
            rest = rest.dropFirst(2)
        } else if rest.hasPrefix("学区") {
            suffix = "区"
            rest = rest.dropFirst(2)
        } else {
            return nil
        }
        let trimmed = rest.trimmingCharacters(in: .whitespaces)
        return SchoolZone(numeral: num, suffix: suffix, paren: parenContent(trimmed))
    }

    private static func parenContent(_ s: String) -> String? {
        let opens: Set<Character> = ["(", "（"]
        let closes: Set<Character> = [")", "）"]
        guard let first = s.first, opens.contains(first),
              let last = s.last, closes.contains(last), s.count >= 3
        else { return nil }
        return String(s.dropFirst().dropLast())
    }
}
