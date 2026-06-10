import Foundation
import Testing
@testable import PropertyAtlas

struct StyleDefaultsTests {
    @Test func builtinPinFallbacksAreSensible() {
        let defaults = StyleDefaults.builtinPin(for: "compound")
        #expect(defaults.shape == .circle)
        #expect(defaults.size == 22)
        #expect(defaults.labelVisible == false)
    }
}
