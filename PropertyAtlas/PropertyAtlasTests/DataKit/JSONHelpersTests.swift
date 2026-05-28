import Foundation
import Testing
@testable import PropertyAtlas

struct JSONHelpersTests {
    @Test func encodeDecodeRoundTripDict() throws {
        let dict: [String: AnyJSON] = ["k1": .string("v1"), "k2": .int(42)]
        let json = try JSONHelpers.encode(dict)
        let back: [String: AnyJSON] = try JSONHelpers.decode(json)
        #expect(back["k1"] == .string("v1"))
        #expect(back["k2"] == .int(42))
    }

    @Test func encodeDecodeRoundTripArray() throws {
        let arr: [AnyJSON] = [.string("a"), .int(1), .bool(true), .null]
        let json = try JSONHelpers.encode(arr)
        let back: [AnyJSON] = try JSONHelpers.decode(json)
        #expect(back == arr)
    }

    @Test func decodeInvalidStringThrows() {
        #expect(throws: (any Error).self) {
            let _: [String: AnyJSON] = try JSONHelpers.decode("not-json{")
        }
    }
}
