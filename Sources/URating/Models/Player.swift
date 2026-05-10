import SwiftData
import Foundation

@Model
final class Player {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#3498DB"
    var createdAt: Date = Date()
    @Attribute(.externalStorage) var photoData: Data? = nil

    init(name: String, colorHex: String) {
        self.name = name
        self.colorHex = colorHex
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
