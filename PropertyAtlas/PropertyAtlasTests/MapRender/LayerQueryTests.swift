// PropertyAtlasTests/MapRender/LayerQueryTests.swift
import Foundation
import Testing
@testable import PropertyAtlas

struct LayerQueryTests {
    @Test func bothNilIsMatchAll() {
        let q = LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: nil)
        #expect(q.isMatchAll)
        #expect(q.coveredTypes.isEmpty)
    }

    @Test func parsesStaticRefs() {
        let json = ##"[{"entityId":"11111111-1111-1111-1111-111111111111","entityType":"compound"}]"##
        let q = LayerQuery(staticRefsJSON: json, dynamicQueryJSON: nil)
        #expect(!q.isMatchAll)
        #expect(q.staticRefs.count == 1)
        #expect(q.staticRefs.first?.kind == .compound)
        #expect(q.coveredTypes == Set(["compound"]))
    }

    @Test func parsesDynamicQueryTypeAndConditions() {
        let json = ##"{"entityType":"school","conditions":[{"field":"grade","op":"in","value":["重点","区重点"]}]}"##
        let q = LayerQuery(staticRefsJSON: nil, dynamicQueryJSON: json)
        #expect(!q.isMatchAll)
        #expect(q.dynamicType == "school")
        #expect(q.dynamicConditions.count == 1)
        #expect(q.coveredTypes == Set(["school"]))
    }
}
