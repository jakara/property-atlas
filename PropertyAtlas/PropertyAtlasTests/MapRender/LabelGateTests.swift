import Testing
@testable import PropertyAtlas

struct LabelGateTests {
    /// 低 zoom:可见 pin < 阈值 → 强制显 label
    @Test func sparseLowZoomShowsLabels() {
        #expect(LabelGate.allowed(visiblePinCount: 9, zoom: 10, minZoom: 13, threshold: 10))
    }

    /// 低 zoom:可见 pin >= 阈值 → 隐藏
    @Test func denseLowZoomHidesLabels() {
        #expect(!LabelGate.allowed(visiblePinCount: 10, zoom: 10, minZoom: 13, threshold: 10))
    }

    /// 高 zoom:即便密集也显(zoom 过线)
    @Test func denseHighZoomShowsLabels() {
        #expect(LabelGate.allowed(visiblePinCount: 200, zoom: 13, minZoom: 13, threshold: 10))
    }

    /// 高 zoom + 稀疏:显
    @Test func sparseHighZoomShowsLabels() {
        #expect(LabelGate.allowed(visiblePinCount: 1, zoom: 16, minZoom: 13, threshold: 10))
    }

    // 边界:恰好等于阈值 → 不算"少于",低 zoom 隐藏
    @Test func countEqualsThresholdLowZoomHides() {
        #expect(!LabelGate.allowed(visiblePinCount: 10, zoom: 12.9, minZoom: 13, threshold: 10))
    }
}
