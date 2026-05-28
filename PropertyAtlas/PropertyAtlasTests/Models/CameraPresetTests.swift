import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct CameraPresetTests {
    @Test func cameraPresetPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, CameraPreset.self])
        let ctx = ModelContext(container)
        let preset = CameraPreset(
            datasetId: UUID(),
            name: "和平区",
            centerLat: 39.125,
            centerLon: 117.205,
            distance: 12000,
            pitch: 0,
            heading: 0
        )
        ctx.insert(preset)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CameraPreset>())
        #expect(all.count == 1)
        #expect(all.first?.name == "和平区")
        #expect(all.first?.distance == 12000)
    }
}
