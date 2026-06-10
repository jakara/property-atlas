import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleEntityLayerIdTests {
    @Test func carriesLayerId() {
        let lid = UUID()
        let se = StyleEntity(entityType: "school", id: UUID(), baseFields: [:], customFields: [:], layerId: lid)
        #expect(se.layerId == lid)
    }

    @Test func defaultsNil() {
        let se = StyleEntity(entityType: "poi", id: UUID(), baseFields: [:], customFields: [:])
        #expect(se.layerId == nil)
    }
}
