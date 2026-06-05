import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleResolverGroupColorTests {
    @Test func groupFillOverridesViewStyleButNotEntityOverride() {
        // No entity override: groupFillHex wins over builtin/view-style.
        let plain = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolvedPlain = StyleResolver.resolvePin(
            entity: plain.styleEntity, viewStyle: nil, groupFillHex: "#123456"
        )
        #expect(resolvedPlain.fillHex == "#123456")

        // Entity override present: override always wins over groupFillHex.
        let overridden = School(datasetId: UUID(), name: "y", latitude: 0, longitude: 0)
        overridden.styleFillHex = "#ABCDEF"
        let resolvedOverridden = StyleResolver.resolvePin(
            entity: overridden.styleEntity, viewStyle: nil, groupFillHex: "#123456"
        )
        #expect(resolvedOverridden.fillHex == "#ABCDEF")
    }

    @Test func nilGroupFillFallsBackToBuiltin() {
        let school = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(entity: school.styleEntity, viewStyle: nil)
        #expect(resolved.fillHex == StyleDefaults.builtinPin(for: "school").fillHex)
    }
}
