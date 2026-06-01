import Foundation
import Testing
@testable import PropertyAtlas

@MainActor
struct StyleResolverGroupColorTests {
    @Test func groupFillOverridesThemeButNotEntityOverride() {
        // No entity override: groupFillHex wins over builtin/theme/rules.
        let plain = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolvedPlain = StyleResolver.resolvePin(
            entity: plain.styleEntity,
            theme: nil,
            rules: [],
            palettes: [:],
            groupFillHex: "#123456"
        )
        #expect(resolvedPlain.fillHex == "#123456")

        // Entity override present: override always wins over groupFillHex.
        let overridden = School(datasetId: UUID(), name: "y", latitude: 0, longitude: 0)
        overridden.overrideStyleJSON = ##"{"fillHex":"#ABCDEF"}"##
        let resolvedOverridden = StyleResolver.resolvePin(
            entity: overridden.styleEntity,
            theme: nil,
            rules: [],
            palettes: [:],
            groupFillHex: "#123456"
        )
        #expect(resolvedOverridden.fillHex == "#ABCDEF")
    }

    @Test func nilGroupFillKeepsOldBehavior() {
        let s = School(datasetId: UUID(), name: "x", latitude: 0, longitude: 0)
        let resolved = StyleResolver.resolvePin(
            entity: s.styleEntity,
            theme: nil,
            rules: [],
            palettes: [:]
        )
        #expect(resolved.fillHex == StyleDefaults.builtinPin(for: "school").fillHex)
    }
}
