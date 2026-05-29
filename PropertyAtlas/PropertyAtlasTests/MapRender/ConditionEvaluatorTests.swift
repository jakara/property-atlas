import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct ConditionEvaluatorTests {
    @Test func equalsOnBaseFieldMatchesString() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        let c = StyleCondition(field: "grade", op: .equals, value: .string("重点"))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func equalsOnBaseFieldFailsWhenDifferent() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "普通"
        let c = StyleCondition(field: "grade", op: .equals, value: .string("重点"))
        #expect(!ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func notEqualsInverts() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "普通"
        let c = StyleCondition(field: "grade", op: .notEquals, value: .string("重点"))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func inOpAcceptsArrayValue() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.grade = "重点"
        let c = StyleCondition(field: "grade", op: .inOp, value: .array([.string("重点"), .string("区重点")]))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func containsOpMatchesSubstring() {
        let s = School(datasetId: UUID(), name: "鞍山道小学", latitude: 0, longitude: 0)
        let c = StyleCondition(field: "name", op: .contains, value: .string("小学"))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func gteAndLteOpsOnNumeric() {
        let c = Compound(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        c.buildYear = 2022
        let gte = StyleCondition(field: "buildYear", op: .gte, value: .int(2020))
        let lte = StyleCondition(field: "buildYear", op: .lte, value: .int(2018))
        #expect(ConditionEvaluator.matches(entity: c.styleEntity, condition: gte))
        #expect(!ConditionEvaluator.matches(entity: c.styleEntity, condition: lte))
    }

    @Test func existsOpTrueWhenFieldNonNil() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.foundYear = 1954
        let c = StyleCondition(field: "foundYear", op: .exists, value: .null)
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }

    @Test func customFieldLookupReadsFromCustomFieldsJSON() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        s.customFieldsJSON = #"{"isMarketKey":true}"#
        let c = StyleCondition(field: "isMarketKey", op: .equals, value: .bool(true))
        #expect(ConditionEvaluator.matches(entity: s.styleEntity, condition: c))
    }
}
