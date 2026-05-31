// PropertyAtlas/PropertyAtlas/Studio/RightDrawer.swift
#if targetEnvironment(macCatalyst)
import SwiftData
import SwiftUI

struct RightDrawer: View {
    @Bindable var appState: AppState
    let datasetId: UUID
    @Environment(\.modelContext) private var context

    var body: some View {
        if let ref = appState.selectedRef {
            Group {
                switch appState.editingMode {
                case .edit:
                    EntityEditor(
                        ref: ref, datasetId: datasetId, appState: appState,
                        onClose: { appState.editingMode = .read },
                        onDelete: {
                            EdgeStore.cascadeSoftDelete(entityId: ref.id, datasetId: datasetId, in: context)
                            EntityWriter.softDelete(ref, in: context)
                            appState.clearSelection()
                        },
                        onSelectRelated: { appState.select($0) }
                    )
                default:
                    EntityCard(
                        ref: ref, datasetId: datasetId,
                        onEdit: { appState.beginEditing() },
                        onClose: { appState.clearSelection() },
                        onSelectRelated: { appState.select($0) }
                    )
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}
#endif
