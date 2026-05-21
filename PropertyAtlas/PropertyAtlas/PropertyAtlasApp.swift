import SwiftData
import SwiftUI

@main
struct PropertyAtlasApp: App {
    let container: ModelContainer
    @State private var selectionState = MapSelectionState()
    @State private var seedDone = false

    init() {
        do {
            let schema = Schema([
                SchoolZone.self, Compound.self, School.self,
                SchoolScore.self, AdmissionDoc.self, BuiltinTag.self,
                PropertyMark.self, Visit.self, Photo.self,
                TagExtension.self, VisitTag.self, UserArea.self, ShareSubmission.self,
            ])
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.fujie.propertyatlas")
            )
            container = try ModelContainer(for: schema, configurations: [config])
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
                } else {
                    SeedProgressView(onComplete: { seedDone = true })
                }
            }
        }
        .modelContainer(container)
    }
}
