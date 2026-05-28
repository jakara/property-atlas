import Foundation

/// Maps new entity baseFields to legacy field names so the P1 Studio UI
/// (SchoolPinView, StudioRootView, SchoolDetailCard, ZoneGeometryImporter)
/// can read new entities without source changes. P2 replaces shim with
/// StyleResolver.
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

    /// Legacy `School.zoneName` — requires Area lookup; callers must
    /// resolve via separate Area dataset. Placeholder returns nil.
    var legacyZoneName: String? {
        nil
    }

    /// Legacy `School.district` — no longer baseField; callers query
    /// the primaryArea (e.g. category="行政区" Area).
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

extension Compound {
    var legacyZoneId: UUID? {
        primaryAreaId
    }

    var legacyDistrict: String {
        ""
    }

    /// Legacy `Compound.primarySchoolId` — Edge-driven in new model;
    /// callers wanting "first 对口小学" must query Edges (P4).
    var legacyPrimarySchoolId: UUID? {
        nil
    }
}

extension Area {
    var legacyPrimaryDistrict: String {
        ""
    }

    var legacyGeometryStage: String {
        geometryKind == "raster" ? "raster" : "hull"
    }

    var legacyTier: String {
        "普通"
    }

    var legacyGeometry: String {
        geometryJSON
    }
}
