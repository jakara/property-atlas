#if targetEnvironment(macCatalyst)
import SwiftUI
import SwiftData
struct ViewSettingsTab: View {
    @Bindable var viewContext: MapViewContext
    var body: some View { Text("视图设置") }
}
#endif
