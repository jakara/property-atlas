import Foundation
import Testing
@testable import PropertyAtlas

@Suite("P9d pure logic")
struct P9dLogicTests {
    @Test func conditionCodecRoundTrip() {
        let conds = [
            StyleCondition(field: "grade", op: .equals, value: .string("重点")),
            StyleCondition(field: "isNewHouse", op: .exists, value: .null),
            StyleCondition(field: "tags", op: .inOp, value: .array([.string("a"), .string("b")])),
        ]
        let json = StyleConditionCodec.encode(conds)
        let back = StyleConditionCodec.decode(json)
        #expect(back.count == 3)
        #expect(back[0].field == "grade")
        #expect(back[0].op == .equals)
        #expect(back[2].op == .inOp)
    }

    @Test func conditionCodecBadEmpty() {
        #expect(StyleConditionCodec.decode("").isEmpty)
        #expect(StyleConditionCodec.decode("not json").isEmpty)
        #expect(StyleConditionCodec.encode([]) == "[]")
    }

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
