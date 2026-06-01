import Testing
import Foundation
@testable import PropertyAtlas

struct PaletteAssignerTests {
    let pal = ["#E41A1C", "#377EB8", "#4DAF4A", "#984EA3"]

    @Test func sameValueStableColor() {
        let m1 = PaletteAssigner.assign(values: ["重点", "普通"], palette: pal)
        let m2 = PaletteAssigner.assign(values: ["重点", "普通"], palette: pal)
        #expect(m1["重点"] == m2["重点"])
    }

    @Test func distinctValuesDistinctColorsWithinCapacity() {
        let m = PaletteAssigner.assign(values: ["a", "b", "c", "d"], palette: pal)
        #expect(Set(m.values).count == 4)   // 4 值 ≤ 4 色 → 全异
    }

    @Test func wrapsBeyondCapacity() {
        let m = PaletteAssigner.assign(values: ["a", "b", "c", "d", "e"], palette: pal)
        #expect(m.count == 5)               // 5 值 > 4 色 → 必有复用,但都有色
        #expect(m.values.allSatisfy { pal.contains($0) })
    }

    @Test func emptyPaletteYieldsEmpty() {
        #expect(PaletteAssigner.assign(values: ["a"], palette: []).isEmpty)
    }
}
