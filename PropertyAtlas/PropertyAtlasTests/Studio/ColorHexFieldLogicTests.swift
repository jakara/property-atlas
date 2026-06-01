import Testing
@testable import PropertyAtlas

struct ColorHexFieldLogicTests {
    @Test func normalizesHash() {
        #expect(ColorHexField.normalize("E41A1C") == "#E41A1C")
        #expect(ColorHexField.normalize("#abc123") == "#ABC123")
        #expect(ColorHexField.normalize("  #fff ") == "#FFF")
    }
}
