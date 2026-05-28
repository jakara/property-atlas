import Testing
@testable import PropertyAtlas

@Suite("AppMode")
struct AppModeTests {
    @Test("default mode is explore")
    func defaultMode() {
        let mode = AppMode()
        #expect(mode.value == .explore)
    }

    @Test("toggle switches between explore and studio")
    func toggle() {
        let mode = AppMode()
        mode.toggle()
        #expect(mode.value == .studio)
        mode.toggle()
        #expect(mode.value == .explore)
    }
}
