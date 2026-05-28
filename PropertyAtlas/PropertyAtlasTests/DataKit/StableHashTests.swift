import Testing
@testable import PropertyAtlas

struct StableHashTests {
    @Test func fnv1aProducesKnownValuesForReferenceStrings() {
        // FNV-1a 32-bit reference vectors (http://www.isthe.com/chongo/tech/comp/fnv/)
        #expect(StableHash.fnv1a32("") == 0x811C_9DC5)
        #expect(StableHash.fnv1a32("a") == 0xE40C_292C)
        #expect(StableHash.fnv1a32("foobar") == 0xBF9C_F968)
    }

    @Test func fnv1aIsStableAcrossCalls() {
        let a = StableHash.fnv1a32("天津 demo")
        let b = StableHash.fnv1a32("天津 demo")
        #expect(a == b)
    }

    @Test func fnv1aDistinctInputsProduceDistinctHashes() {
        #expect(StableHash.fnv1a32("第一学片") != StableHash.fnv1a32("第二学片"))
    }
}
