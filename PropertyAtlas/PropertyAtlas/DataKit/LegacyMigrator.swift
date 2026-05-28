import Foundation
import SwiftData

/// One-shot migration from legacy @Model (LegacyCompound / LegacySchool /
/// LegacySchoolZone / LegacyAdmissionDoc + still-named-old: BuiltinTag /
/// CompoundSchoolMatch / SchoolGroup / Policy / AdmissionRate / SchoolScore)
/// to new @Models (Models/Entities/*, Core/*, Style/*, Display/*, Schema/*, Media/*).
/// Idempotent — safe to call multiple times.
@MainActor
enum LegacyMigrator {
    static let datasetName = "天津 demo"

    static func run(in ctx: ModelContext) throws {
        // Idempotent: skip if a Dataset already exists
        if try !ctx.fetch(FetchDescriptor<Dataset>()).isEmpty {
            return
        }
        // No-op when no legacy data
        let hasLegacy: Bool = try (
            !ctx.fetch(FetchDescriptor<LegacyCompound>()).isEmpty
                || !ctx.fetch(FetchDescriptor<LegacySchool>()).isEmpty
                || !ctx.fetch(FetchDescriptor<LegacySchoolZone>()).isEmpty
        )
        if !hasLegacy { return }

        let dataset = Dataset(name: datasetName)
        ctx.insert(dataset)
        try ctx.save()
    }
}
