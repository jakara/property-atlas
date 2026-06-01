import Foundation

/// MapView の primaryFilterJSON / normalFiltersJSON ⇄ 値型。
/// 解码失败回退空值，UI 永不崩溃。
enum ViewConfigCodec {
    static func decodePrimary(_ json: String) -> PrimaryFilter {
        (try? JSONHelpers.decode(json) as PrimaryFilter) ?? PrimaryFilter(conditions: [], groupBy: nil)
    }

    static func encodePrimary(_ pf: PrimaryFilter) -> String {
        (try? JSONHelpers.encode(pf)) ?? #"{"conditions":[]}"#
    }

    static func decodeNormals(_ json: String) -> [NormalFilter] {
        (try? JSONHelpers.decode(json) as [NormalFilter]) ?? []
    }

    static func encodeNormals(_ nfs: [NormalFilter]) -> String {
        (try? JSONHelpers.encode(nfs)) ?? "[]"
    }
}
