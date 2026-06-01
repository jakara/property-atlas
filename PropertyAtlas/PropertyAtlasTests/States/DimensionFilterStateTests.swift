import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct DimensionFilterStateTests {
    @Test func toggleHidesAndUnhides() {
        let s = DimensionFilterState()
        let dimKey = MapDimension(kind: .field, fieldKey: "grade").key
        #expect(!s.isHidden(dimensionKey: dimKey, value: "重点"))
        s.toggle(dimensionKey: dimKey, value: "重点")
        #expect(s.isHidden(dimensionKey: dimKey, value: "重点"))
        s.toggle(dimensionKey: dimKey, value: "重点")
        #expect(!s.isHidden(dimensionKey: dimKey, value: "重点"))
    }

    @Test func resetClears() {
        let s = DimensionFilterState()
        let k = MapDimension(kind: .entityType).key
        s.toggle(dimensionKey: k, value: "school")
        s.reset()
        #expect(!s.isHidden(dimensionKey: k, value: "school"))
    }
}
