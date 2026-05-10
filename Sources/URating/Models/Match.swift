import SwiftData
import Foundation

@Model
final class Match {
    var id: UUID = UUID()
    var league: League?
    var tournament: Tournament?
    var player1: Player?
    var player2: Player?
    var player1Won: Bool = true
    var score: String = ""
    var date: Date = Date()
    var player1RatingBefore: Double = 0
    var player2RatingBefore: Double = 0
    var player1RatingAfter: Double = 0
    var player2RatingAfter: Double = 0
    var cloudRecordName: String? = nil

    init(
        league: League,
        player1: Player,
        player2: Player,
        player1Won: Bool,
        score: String = "",
        tournament: Tournament? = nil,
        player1RatingBefore: Double,
        player2RatingBefore: Double,
        player1RatingAfter: Double,
        player2RatingAfter: Double
    ) {
        self.league = league
        self.player1 = player1
        self.player2 = player2
        self.player1Won = player1Won
        self.score = score
        self.tournament = tournament
        self.player1RatingBefore = player1RatingBefore
        self.player2RatingBefore = player2RatingBefore
        self.player1RatingAfter = player1RatingAfter
        self.player2RatingAfter = player2RatingAfter
    }

    var winner: Player? { player1Won ? player1 : player2 }
    var loser: Player? { player1Won ? player2 : player1 }
}
