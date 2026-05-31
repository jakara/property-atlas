// PropertyAtlasTests/MapRender/LegendSwatchTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct LegendSwatchTests {
    @Test func returnsBuiltinFillWhenNoRules() {
        let hex = LegendSwatch.fillHex(
            entityType: "school",
            fieldKey: "category",
            value: "小学",
            theme: nil,
            rules: [],
            palettes: [:]
        )
        #expect(hex.hasPrefix("#"))
    }

    @Test func ruleFixedFillApplies() {
        let rule = StyleRule(datasetId: UUID(), name: "r", entityType: "school")
        rule.conditionsJSON = ##"[{"field":"category","op":"equals","value":"小学"}]"##
        rule.appliesFillMode = "fixed"
        rule.appliesFillHex = "#123456"
        let hex = LegendSwatch.fillHex(
            entityType: "school",
            fieldKey: "category",
            value: "小学",
            theme: nil,
            rules: [rule],
            palettes: [:]
        )
        #expect(hex == "#123456")
    }
}
