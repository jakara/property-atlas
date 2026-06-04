#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

/// 实体「所属图层」下拉。改即写入 layerId 并保存。
struct LayerPickerRow: View {
    let ref: EntityRef
    let datasetId: UUID
    @Environment(\.modelContext) private var context
    @Query private var layers: [Layer]

    private var dsLayers: [Layer] {
        layers.filter { $0.datasetId == datasetId && !$0.deleted }.sorted { $0.zIndex < $1.zIndex }
    }

    private var defaultId: UUID? {
        dsLayers.first(where: { $0.isDefault })?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("所属图层").font(Studio.sans(11, .medium)).foregroundStyle(Studio.on2)
            Picker("", selection: Binding(
                get: { EntityReader.layerId(ref, in: context) ?? defaultId },
                set: { newValue in
                    EntityWriter.setLayer(ref, newValue, in: context)
                    try? context.save()
                }
            )) {
                ForEach(dsLayers, id: \.id) { Text($0.name).tag($0.id as UUID?) }
            }
            .labelsHidden().tint(Studio.cool)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
