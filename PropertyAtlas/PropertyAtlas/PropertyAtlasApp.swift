import SwiftData
import SwiftUI

@main
struct PropertyAtlasApp: App {
    let container: ModelContainer
    @State private var selectionState = MapSelectionState()
    #if targetEnvironment(macCatalyst)
    @State private var appMode = AppMode(.studio) // Mac: 默认 Studio
    #else
    @State private var appMode = AppMode(.explore)
    #endif
    @State private var seedDone = false

    init() {
        do {
            container = try ModelSchema.makeContainer()
            var debugInfo = "Home: \(NSHomeDirectory())\n"
            debugInfo += "AppSupport: \(URL.applicationSupportDirectory.path)\n"
            for cfg in container.configurations {
                debugInfo += "StoreURL: \(cfg.url.path)\n"
            }
            try? debugInfo.write(
                toFile: "/tmp/propertyatlas_paths.txt",
                atomically: true,
                encoding: .utf8
            )
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if seedDone {
                    RootView()
                        .environment(selectionState)
                        .environment(appMode)
                } else {
                    SeedProgressView(onComplete: { seedDone = true })
                }
            }
        }
        .modelContainer(container)
        #if targetEnvironment(macCatalyst)
            .commands {
                CommandMenu("Studio") {
                    Button("切换 Studio 模式") { appMode.toggle() }
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                    Divider()
                    ForEach(Array(CameraPresets.seed.prefix(6).enumerated()), id: \.offset) { i, p in
                        Button("跳到 \(p.name)") {
                            NotificationCenter.default.post(name: .studioPresetSelected, object: p)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
                    }
                }
                // 隐藏无用的系统默认菜单项(保留 Edit 复制/撤销、Window 供文本框用)。
                CommandGroup(replacing: .newItem) {}
                CommandGroup(replacing: .saveItem) {}
                CommandGroup(replacing: .importExport) {}
                CommandGroup(replacing: .printItem) {}
                CommandGroup(replacing: .textFormatting) {}
                CommandGroup(replacing: .toolbar) {}
                CommandGroup(replacing: .sidebar) {}
                CommandGroup(replacing: .help) {}
            }
        #endif
    }
}
