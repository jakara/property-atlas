import Foundation

enum StableHash {
    /// FNV-1a 32-bit hash. Stable across processes / platforms (unlike Swift's Hasher).
    /// Spec: http://www.isthe.com/chongo/tech/comp/fnv/
    static func fnv1a32(_ s: String) -> UInt32 {
        var hash: UInt32 = 0x811C_9DC5
        for byte in s.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        return hash
    }
}
