import Foundation

enum AppModeValue: String, Codable, CaseIterable {
    case explore
    case studio
}

@Observable
final class AppMode {
    var value: AppModeValue

    init(_ value: AppModeValue = .explore) {
        self.value = value
    }

    func toggle() {
        value = (value == .explore) ? .studio : .explore
    }
}
