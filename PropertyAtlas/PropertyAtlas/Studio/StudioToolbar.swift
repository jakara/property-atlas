#if targetEnvironment(macCatalyst)
import MapKit
import SwiftUI

struct StudioToolbar: View {
    @Bindable var themeContext: ThemeContext
    @Binding var aspect: CanvasAspect
    let onSnapshot: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Menu(themeContext.activeTheme?.name ?? "无主题") {
                ForEach(themeContext.allThemes, id: \.id) { theme in
                    Button(theme.name) { themeContext.switchTheme(to: theme) }
                }
            }
            Menu("📐 \(aspect.rawValue)") {
                ForEach(CanvasAspect.allCases) { a in
                    Button(a.rawValue) { aspect = a }
                }
            }
            Divider().frame(height: 20)
            Button(action: onSnapshot) { Text("📸 截屏") }
                .keyboardShortcut("e", modifiers: .command)
        }
        .padding(10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}
#endif
