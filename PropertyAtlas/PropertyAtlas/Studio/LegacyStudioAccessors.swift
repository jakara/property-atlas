#if targetEnvironment(macCatalyst)
import Foundation

/// Minimal legacy School accessors retained ONLY for the Tianjin-specific
/// Studio UI still pending generic rework: PinFilter, StudioLegend,
/// SchoolDetailCard. These are NOT used by the MapRender pipeline.
/// P4 removal target — delete together with those three files when the
/// generic legend/filter/detail UI lands.
extension School {
    /// Legacy `School.type` = new `category`
    var legacyType: String {
        category ?? ""
    }

    /// Legacy `School.tier` ∈ {重点, 区重点, 普通}; default = 普通
    var legacyTier: String {
        grade ?? "普通"
    }

    /// Legacy `School.isJiunian` = new `form == "九年一贯"`
    var legacyIsJiunian: Bool {
        form == "九年一贯"
    }

    /// Legacy `School.is12Year` = new `form == "十二年制"`
    var legacyIs12Year: Bool {
        form == "十二年制"
    }

    /// Legacy `School.zoneId` = new `primaryAreaId`
    var legacyZoneId: UUID? {
        primaryAreaId
    }

    /// Legacy `School.district` — no longer a baseField; resolve via Area (P4).
    var legacyDistrict: String {
        ""
    }

    /// Legacy `School.lat` mapped from `latitude` (0 → nil so old
    /// "missing geocode" checks still work).
    var lat: Double? {
        latitude == 0 ? nil : latitude
    }

    /// Legacy `School.lon` mapped from `longitude`.
    var lon: Double? {
        longitude == 0 ? nil : longitude
    }
}
#endif
