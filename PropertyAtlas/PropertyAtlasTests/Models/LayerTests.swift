import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerTests {
    @Test func layerPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Layer.self])
        let ctx = ModelContext(container)
        let l = Layer(
            datasetId: UUID(),
            name: "重点学校"
        )
        l.iconSF = "star.fill"
        l.colorHex = "#FF3B30"
        l.minZoom = 0
        l.maxZoom = 21
        l.dynamicQueryJSON = #"{"entityType":"school","conditions":[{"field":"grade","op":"equals","value":"重点"}]}"#
        ctx.insert(l)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Layer>())
        #expect(all.first?.name == "重点学校")
        #expect(all.first?.maxZoom == 21)
        #expect(all.first?.isDefault == false)
        #expect(all.first?.enabled == true)
    }
}

@MainActor
struct LayerZIndexThemeTests {
    @Test func zIndexAndThemeIdPersist() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let l = Layer(datasetId: UUID(), name: "教育")
        l.zIndex = 5
        let tid = UUID(); l.themeId = tid
        ctx.insert(l); try ctx.save()
        let f = try ctx.fetch(FetchDescriptor<Layer>()).first
        #expect(f?.zIndex == 5)
        #expect(f?.themeId == tid)
    }
}
