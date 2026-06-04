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
            SectionLabel(text: "实拍照片", trailing: "\(photos.count)")
            ForEach(photos, id: \.id) { p in
                HStack(spacing: 11) {
                    Image(systemName: "photo").font(.system(size: 16))
                        .foregroundStyle(Studio.on2)
                        .frame(width: 34, height: 34)
                        .background(Studio.glassHover, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text(p.caption ?? p.url).font(Studio.sans(14, .medium))
                        .foregroundStyle(Studio.on).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .frame(minHeight: 52)
                .background(Studio.glassHover.opacity(0.5), in: RoundedRectangle(cornerRadius: Studio.rCard, style: .continuous))
            }
            Text("长边压缩 1280 · HEIC · 不入直播（PhotosPicker 集成留 P3.5）")
                .font(Studio.mono(10)).foregroundStyle(Studio.on3)
        }
    }
}
#endif
