import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleResolverChainTests {
    private func pinEntity(override: PartialPinStyle = PartialPinStyle()) -> StyleEntity {
        StyleEntity(entityType: "compound", id: UUID(), baseFields: [:], customFields: [:], overridePin: override)
    }

    @Test func viewStyleOverridesBuiltin() {
        let vs = ViewEntityStyle(datasetId: UUID(), layerId: UUID(), entityType: "compound")
        vs.fillHex = "#111111"
        let style = StyleResolver.resolvePin(entity: pinEntity(), viewStyle: vs, groupFillHex: nil)
        #expect(style.fillHex == "#111111")
    }

    @Test func groupFillOverridesViewStyle() {
        let vs = ViewEntityStyle(datasetId: UUID(), layerId: UUID(), entityType: "compound")
        vs.fillHex = "#111111"
        let style = StyleResolver.resolvePin(entity: pinEntity(), viewStyle: vs, groupFillHex: "#222222")
        #expect(style.fillHex == "#222222")
    }

    @Test func entityOverrideBeatsGroupFill() {
        let vs = ViewEntityStyle(datasetId: UUID(), layerId: UUID(), entityType: "compound")
        vs.fillHex = "#111111"
        let entity = pinEntity(override: PartialPinStyle(fillHex: "#333333"))
        let style = StyleResolver.resolvePin(entity: entity, viewStyle: vs, groupFillHex: "#222222")
        #expect(style.fillHex == "#333333")
    }

    @Test func nilViewStyleFallsBackToBuiltin() {
        let style = StyleResolver.resolvePin(entity: pinEntity(), viewStyle: nil, groupFillHex: nil)
        #expect(style.fillHex == "#A8A8A8") // StyleDefaults.builtinPin fill
    }
}
