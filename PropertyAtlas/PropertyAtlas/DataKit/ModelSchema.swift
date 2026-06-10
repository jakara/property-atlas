import Foundation
import SwiftData

enum ModelSchema {
    /// Full SwiftData schema: new @Models + existing User/* (orthogonal).
    /// Single source of truth; both PropertyAtlasApp.swift and tests should reference this.
    static let allTypes: [any PersistentModel.Type] = [
        // New core
        Dataset.self, Edge.self, Tag.self, CameraPreset.self,
        // New entities
        Compound.self, School.self, POI.self, Area.self,
        // New style
        StyleRule.self, Palette.self, Theme.self,
        // New display
        Layer.self, ViewEntityStyle.self, ViewStyleRule.self, ViewStyleCondition.self,
        // New schema registry
        CustomFieldDef.self, EnumOption.self,
        // New media
        Photo.self, Document.self,
        // User/* (orthogonal; untouched in P1)
        VisitPhoto.self, PropertyMark.self, Visit.self, TagExtension.self,
        VisitTag.self, UserArea.self, ShareSubmission.self,
    ]

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(allTypes)
        #if targetEnvironment(macCatalyst)
        // P1: keep .none. Spec says enable for Mac in P5.
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        #else
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.fujie.propertyatlas")
        )
        #endif
        return try ModelContainer(for: schema, configurations: [config])
    }
}
