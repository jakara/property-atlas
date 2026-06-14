import Testing
@testable import PropertyAtlas

struct ContrastTextTests {
    @Test func yellowFillGetsDarkLabel() {
        #expect(ContrastText.labelHex(onFill: "#FFCC00") == "#1A1A1A")
    }

    @Test func blueFillGetsWhiteLabel() {
        #expect(ContrastText.labelHex(onFill: "#0A84FF") == "#FFFFFF")
    }

    @Test func greenFillGetsWhiteLabel() {
        #expect(ContrastText.labelHex(onFill: "#34C759") == "#FFFFFF")
    }

    @Test func schoolOrangeStaysWhiteLabel() {
        // 区重点橙 #FF9500 luma≈0.642 ≤0.7 → 仍白字,学校视觉不变
        #expect(ContrastText.labelHex(onFill: "#FF9500") == "#FFFFFF")
    }

    @Test func invalidHexFallsBackToWhite() {
        #expect(ContrastText.labelHex(onFill: "bogus") == "#FFFFFF")
    }
}
