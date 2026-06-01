#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData
struct LayerSettingsTab: View {
    let datasetId: UUID
    var body: some View { Text("图层设置") }
}
#endif
