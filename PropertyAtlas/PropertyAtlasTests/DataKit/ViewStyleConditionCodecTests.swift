import Foundation
import Testing
@testable import PropertyAtlas

struct ViewStyleConditionCodecTests {
    @Test func equalsBuildsStringCondition() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "grade", op: .equals, valueString: "重点", valueList: []
        )
        #expect(cond.field == "grade")
        #expect(cond.op == .equals)
        #expect(cond.value == .string("重点"))
    }

    @Test func inBuildsArrayCondition() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "tags", op: .inOp, valueString: nil, valueList: ["a", "b"]
        )
        #expect(cond.value == .array([.string("a"), .string("b")]))
    }

    @Test func gteParsesNumber() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "capacity", op: .gte, valueString: "100", valueList: []
        )
        #expect(cond.value == .double(100))
    }

    @Test func existsBuildsNull() {
        let cond = ViewStyleConditionCodec.styleCondition(
            field: "address", op: .exists, valueString: nil, valueList: []
        )
        #expect(cond.value == .null)
    }

    @Test func columnsFromStringValue() {
        let cols = ViewStyleConditionCodec.columns(from: .string("重点"), op: .equals)
        #expect(cols.valueString == "重点")
        #expect(cols.valueList.isEmpty)
    }

    @Test func columnsFromArrayValue() {
        let cols = ViewStyleConditionCodec.columns(from: .array([.string("a"), .int(2)]), op: .inOp)
        #expect(cols.valueList == ["a", "2"])
        #expect(cols.valueString == nil)
    }

    @Test func columnsFromNumericValue() {
        let cols = ViewStyleConditionCodec.columns(from: .int(100), op: .gte)
        #expect(cols.valueString == "100")
    }
}
