import Foundation
import Testing
@testable import PropertyAtlas

@Suite("P9d pure logic")
struct P9dLogicTests {
    // StyleConditionCodec tests removed: codec deleted in view-owned-style refactor
    // (StyleRule conditional styling dropped). CameraFieldClamp tests retained.

    @Test func clampPitch() {
        #expect(CameraFieldClamp.pitch(-10) == 0)
        #expect(CameraFieldClamp.pitch(90) == 85)
        #expect(CameraFieldClamp.pitch(45) == 45)
    }

    @Test func clampHeading() {
        #expect(CameraFieldClamp.heading(370) == 10)
        #expect(CameraFieldClamp.heading(-10) == 350)
        #expect(CameraFieldClamp.heading(360) == 0)
    }
}
