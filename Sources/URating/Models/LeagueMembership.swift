import SwiftData
import Foundation

@Model
final class LeagueMembership {
    var id: UUID = UUID()
    var player: Player?
    var league: League?
    var rating: Double = 1000.0
    var wins: Int = 0
    var losses: Int = 0
    var joinedAt: Date = Date()

    init(player: Player, league: League) {
        self.player = player
        self.league = league
    }

    var totalMatches: Int { wins + losses }
    var winRate: Double { totalMatches > 0 ? Double(wins) / Double(totalMatches) : 0 }
}
