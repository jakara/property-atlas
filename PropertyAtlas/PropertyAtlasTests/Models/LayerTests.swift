import Foundation
import SwiftData
import Testing
@testable import PropertyAtlas

@MainActor
struct LayerTests {
    @Test func layerPersists() throws {
        let container = try TestContainer.makeInMemory(for: [Dataset.self, Layer.self])
        let ctx = ModelContext(container)
        let l = Layer(datasetId: UUID(), name: "重点学校", entityType: "school")
        l.iconSF = "star.fill"
        l.colorHex = "#FF3B30"
        l.minZoom = 0
        l.maxZoom = 21
        ctx.insert(l)
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<Layer>())
        #expect(all.first?.name == "重点学校")
        #expect(all.first?.entityType == "school")
        #expect(all.first?.maxZoom == 21)
        #expect(all.first?.enabled == true)
    }
}

@MainActor
struct LayerConfigPersistTests {
    @Test func zIndexAndConfigPersist() throws {
        let container = try TestContainer.makeInMemory(for: ModelSchema.allTypes)
        let ctx = ModelContext(container)
        let l = Layer(datasetId: UUID(), name: "教育", entityType: "school")
        l.zIndex = 5
        l.paletteHex = ["#FF0000", "#00FF00"]
        l.showLegend = false
        ctx.insert(l)
        try ctx.save()
        let f = try ctx.fetch(FetchDescriptor<Layer>()).first
        #expect(f?.zIndex == 5)
        #expect(f?.paletteHex == ["#FF0000", "#00FF00"])
        #expect(f?.showLegend == false)
    }
}
