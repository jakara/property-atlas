import Testing
import Foundation
@testable import PropertyAtlas

struct ValueFormatTests {
    @Test func displayScalarKinds() {
        #expect(ValueFormat.display(.string("重点")) == "重点")
        #expect(ValueFormat.display(.int(3)) == "3")
        #expect(ValueFormat.display(.bool(true)) == "true")
        #expect(ValueFormat.display(nil) == "")
    }
    @Test func keyJoinsTypeAndField() {
        #expect(ValueFormat.key("school", "grade") == "school.grade")
    }
}
