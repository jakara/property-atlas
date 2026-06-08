// PropertyAtlas/PropertyAtlas/Studio/RightDrawer.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct RightDrawer: View {
    @Bindable var appState: AppState
    let datasetId: UUID
    /// 区域重绘多边形:由 RootView 进入绘制态。
    var onRedrawArea: (UUID) -> Void = { _ in }
    @Environment(\.modelContext) private var context

    var body: some View {
        if let ref = appState.selectedRef {
            // 单一就地编辑面板:选中即可编辑,无只读/编辑切换。
            EntityEditor(
                ref: ref, datasetId: datasetId, appState: appState,
                onClose: { appState.clearSelection() },
                onDelete: {
                    EdgeStore.cascadeSoftDelete(entityId: ref.id, datasetId: datasetId, in: context)
                    EntityWriter.softDelete(ref, in: context)
                    appState.clearSelection()
                },
                onSelectRelated: { appState.select($0) },
                onRedrawPolygon: ref.kind == .area ? { onRedrawArea(ref.id) } : nil
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}
#endif
