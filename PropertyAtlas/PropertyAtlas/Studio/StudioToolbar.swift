#if targetEnvironment(macCatalyst)
import MapKit
import SwiftUI

struct StudioToolbar: View {
    @Binding var selectedPreset: CameraPreset
    @Binding var aspect: CanvasAspect
    @Binding var showZoneFill: Bool
    @Binding var showSchoolPins: Bool
    @Binding var showSchoolLabels: Bool
    let onSnapshot: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu("🗺️ 图层") {
                Toggle("学片色块 (hull 粗略)", isOn: $showZoneFill)
                Toggle("学校 Pin", isOn: $showSchoolPins)
                Toggle("学校名牌", isOn: $showSchoolLabels)
            }
            Menu("📐 \(aspect.rawValue)") {
                ForEach(CanvasAspect.allCases) { a in
                    Button(a.rawValue) { aspect = a }
                }
            }
            Divider().frame(height: 20)
            Button {
                NotificationCenter.default.post(name: .reloadSeeds, object: nil)
            } label: {
                Text("↻ 重载数据")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            Button(action: onSnapshot) {
                Text("📸 截屏")
            }
            .keyboardShortcut("e", modifiers: .command)
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}
#endif
