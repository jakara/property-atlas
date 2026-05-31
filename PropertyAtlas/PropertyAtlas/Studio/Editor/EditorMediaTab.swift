// PropertyAtlas/PropertyAtlas/Studio/Editor/EditorMediaTab.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct EditorMediaTab: View {
    let ref: EntityRef
    @Environment(\.modelContext) private var context

    var body: some View {
        let ownerId = ref.id
        let fd = FetchDescriptor<Photo>(
            predicate: #Predicate { $0.ownerEntityId == ownerId && !$0.deleted },
            sortBy: [SortDescriptor(\.order)]
        )
        let photos = (try? context.fetch(fd)) ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("照片 (\(photos.count))").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ForEach(photos, id: \.id) { p in
                HStack(spacing: 6) {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                    Text(p.caption ?? p.url).font(.system(size: 12)).lineLimit(1)
                }
            }
            Text("（加图 / 加文档：PhotosPicker 集成留 P3.5）")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
}
#endif
