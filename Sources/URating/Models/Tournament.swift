import SwiftData
import Foundation

enum TournamentFormat: String, Codable, CaseIterable {
    case singleElimination = "Single Elimination"
    case roundRobin        = "Round Robin"
}

@Model
final class Tournament {
    var id: UUID = UUID()
    var name: String = ""
    var league: League?
    var format: TournamentFormat = TournamentFormat.singleElimination
    var startDate: Date = Date()
    var endDate: Date?

    @Relationship(deleteRule: .nullify, inverse: \Match.tournament)
    var matches: [Match] = []

    var participantIDs: [String] = []
    var bracketData: Data? = nil

    init(name: String, league: League, format: TournamentFormat = .singleElimination) {
        self.name   = name
        self.league = league
        self.format = format
    }
}
