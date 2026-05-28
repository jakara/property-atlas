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
            let schema = Schema([
                LegacySchoolZone.self, LegacyCompound.self, Compound.self, LegacySchool.self, School.self,
                SchoolGroup.self, Policy.self, AdmissionRate.self, CompoundSchoolMatch.self,
                SchoolScore.self, AdmissionDoc.self, BuiltinTag.self,
                PropertyMark.self, Visit.self, VisitPhoto.self,
                TagExtension.self, VisitTag.self, UserArea.self, ShareSubmission.self,
                Dataset.self, POI.self, Area.self, StyleRule.self, Palette.self, Theme.self, Layer.self,
            ])
            #if targetEnvironment(macCatalyst)
            // Mac Catalyst: 关 CloudKit 镜像 (entitlement 在但不接 iCloud); 否则会 ServerRejected
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            #else
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.fujie.propertyatlas")
            )
            #endif
            container = try ModelContainer(for: schema, configurations: [config])
            // 调试: 写 store 路径到固定文件, 不依赖 stdout/log
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
            }
        #endif
    }
}
