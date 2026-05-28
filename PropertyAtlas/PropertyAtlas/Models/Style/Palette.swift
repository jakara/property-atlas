import Foundation
import SwiftData

@Model
final class Palette {
    var id: UUID = UUID()
    var name: String = ""
    var colorsHex: [String] = []
    var builtIn: Bool = false
    var sortOrder: Int = 0
    var version: Int = 1
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var deleted: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        colorsHex: [String],
        builtIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.colorsHex = colorsHex
        self.builtIn = builtIn
    }
}
