import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var defaultMapStyle: String {
        didSet { defaults.set(defaultMapStyle, forKey: "defaultMapStyle") }
    }

    @Published var showZoneTiers: Set<String> {
        didSet { defaults.set(Array(showZoneTiers), forKey: "showZoneTiers") }
    }

    private init() {
        self.defaultMapStyle = defaults.string(forKey: "defaultMapStyle") ?? "standard"
        let tiers = defaults.stringArray(forKey: "showZoneTiers") ?? ["顶尖", "优质", "普通", "薄弱"]
        self.showZoneTiers = Set(tiers)
    }
}
