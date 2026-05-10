import SwiftData
import Foundation

@Model
final class League {
    var id: UUID = UUID()
    var name: String = ""
    var sport: String = ""
    var colorHex: String = "#3498DB"
    var createdAt: Date = Date()
    var kFactor: Double = 32.0

    // CloudKit sharing metadata
    var cloudZoneName: String? = nil
    var cloudZoneOwnerName: String? = nil
    var cloudRecordName: String? = nil
    var isShared: Bool = false
    var isOwned: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \LeagueMembership.league)
    var memberships: [LeagueMembership] = []

    @Relationship(deleteRule: .cascade, inverse: \Match.league)
    var matches: [Match] = []

    @Relationship(deleteRule: .cascade, inverse: \Tournament.league)
    var tournaments: [Tournament] = []

    init(name: String, sport: String = "", colorHex: String = "#3498DB") {
        self.name = name
        self.sport = sport
        self.colorHex = colorHex
    }
}
