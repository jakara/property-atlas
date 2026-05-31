// PropertyAtlasTests/DataKit/EntityFieldSchemaTests.swift
import Testing
@testable import PropertyAtlas

struct EntityFieldSchemaTests {
    @Test func schoolHasCategoryGradeForm() {
        let keys = EntityFieldSchema.fields(for: .school).map(\.key)
        #expect(keys.contains("category"))
        #expect(keys.contains("grade"))
        #expect(keys.contains("form"))
    }

    @Test func compoundHasFinishTypeAndNewHouseBool() {
        let fields = EntityFieldSchema.fields(for: .compound)
        #expect(fields.contains { $0.key == "finishType" && $0.kind == .string })
        #expect(fields.contains { $0.key == "isNewHouse" && $0.kind == .bool })
    }

    @Test func everyFieldHasNonEmptyLabel() {
        for kind in EntityKind.allCases {
            for f in EntityFieldSchema.fields(for: kind) {
                #expect(!f.label.isEmpty)
            }
        }
    }
}
