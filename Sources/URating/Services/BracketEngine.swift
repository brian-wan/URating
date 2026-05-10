import Foundation

struct BracketMatch: Codable, Identifiable {
    var id: UUID = UUID()
    let round: Int
    let position: Int       // 0-indexed within round
    var topID: String?      // upper player
    var bottomID: String?   // lower player
    var winnerID: String?
    var matchRecordID: String?

    var isBye: Bool        { (topID == nil) != (bottomID == nil) }
    var isComplete: Bool   { winnerID != nil }
    var isPlayable: Bool   { topID != nil && bottomID != nil && !isComplete }
}

struct Bracket: Codable {
    var matches: [BracketMatch]
    let totalRounds: Int
    let size: Int   // power of 2

    func slot(round: Int, position: Int) -> BracketMatch? {
        matches.first { $0.round == round && $0.position == position }
    }

    func round(_ r: Int) -> [BracketMatch] {
        matches.filter { $0.round == r }.sorted { $0.position < $1.position }
    }

    var champion: String? {
        matches.first { $0.round == totalRounds - 1 && $0.position == 0 }?.winnerID
    }

    var currentRound: Int {
        for r in 0..<totalRounds {
            if round(r).contains(where: { !$0.isComplete && ($0.topID != nil || $0.bottomID != nil) }) {
                return r
            }
        }
        return totalRounds - 1
    }

    func roundLabel(for r: Int) -> String {
        let roundsLeft = totalRounds - 1 - r
        switch roundsLeft {
        case 0:  return "Final"
        case 1:  return "Semifinals"
        case 2:  return "Quarterfinals"
        default: return "Round \(r + 1)"
        }
    }
}

enum BracketEngine {
    // MARK: - Generation

    static func generate(participants: [LeagueMembership]) -> Bracket {
        let seeds = participants.sorted { $0.rating > $1.rating }
        let n = seeds.count
        let size = nextPow2(n)
        let totalRounds = Int(log2(Double(size)))

        // Standard seeding: seed s plays seed (size+1-s) in round 1
        // Build slot array [seed1, seed2, seed3 ...] in bracket order using recursive fold
        let slotOrder = standardSeedOrder(size: size)
        // slotOrder[i] = seed number (1-based) for bracket slot i

        // Map seed → playerID (nil if bye)
        var slotToPlayerID: [Int: String] = [:]
        for (i, member) in seeds.enumerated() {
            if let pid = member.player?.id.uuidString {
                // find which slot this seed (i+1) is at
                if let slotIdx = slotOrder.firstIndex(of: i + 1) {
                    slotToPlayerID[slotIdx] = pid
                }
            }
        }

        // Build first-round matches
        let firstRoundCount = size / 2
        var allMatches: [BracketMatch] = []

        for pos in 0..<firstRoundCount {
            let topSlot    = pos * 2
            let bottomSlot = pos * 2 + 1
            var m = BracketMatch(round: 0, position: pos,
                                 topID: slotToPlayerID[topSlot],
                                 bottomID: slotToPlayerID[bottomSlot])
            // Auto-advance bye
            if m.topID != nil && m.bottomID == nil  { m.winnerID = m.topID }
            if m.bottomID != nil && m.topID == nil  { m.winnerID = m.bottomID }
            allMatches.append(m)
        }

        // Build subsequent empty rounds
        for r in 1..<totalRounds {
            let count = size / Int(pow(2.0, Double(r + 1)))
            for pos in 0..<count {
                allMatches.append(BracketMatch(round: r, position: pos))
            }
        }

        var bracket = Bracket(matches: allMatches, totalRounds: totalRounds, size: size)
        propagateByes(&bracket)
        return bracket
    }

    // MARK: - Record winner and advance bracket

    static func recordWinner(matchID: UUID, winnerID: String, matchRecordID: String, in bracket: inout Bracket) {
        guard let idx = bracket.matches.firstIndex(where: { $0.id == matchID }) else { return }
        bracket.matches[idx].winnerID      = winnerID
        bracket.matches[idx].matchRecordID = matchRecordID

        let round    = bracket.matches[idx].round
        let position = bracket.matches[idx].position
        let nextRound = round + 1
        let nextPos   = position / 2
        let isTop     = position % 2 == 0

        guard let nextIdx = bracket.matches.firstIndex(where: { $0.round == nextRound && $0.position == nextPos })
        else { return }

        if isTop { bracket.matches[nextIdx].topID    = winnerID }
        else     { bracket.matches[nextIdx].bottomID = winnerID }

        // Auto-advance if opponent is a bye
        let top    = bracket.matches[nextIdx].topID
        let bottom = bracket.matches[nextIdx].bottomID
        if top != nil && bottom == nil { bracket.matches[nextIdx].winnerID = top }
        if bottom != nil && top == nil { bracket.matches[nextIdx].winnerID = bottom }
    }

    // MARK: - Serialisation helpers

    static func encode(_ bracket: Bracket) -> Data? {
        try? JSONEncoder().encode(bracket)
    }

    static func decode(_ data: Data) -> Bracket? {
        try? JSONDecoder().decode(Bracket.self, from: data)
    }

    // MARK: - Private helpers

    private static func propagateByes(_ bracket: inout Bracket) {
        for r in 1..<bracket.totalRounds {
            let count = bracket.size / Int(pow(2.0, Double(r + 1)))
            for pos in 0..<count {
                guard let f1 = bracket.slot(round: r - 1, position: pos * 2),
                      let f2 = bracket.slot(round: r - 1, position: pos * 2 + 1),
                      let idx = bracket.matches.firstIndex(where: { $0.round == r && $0.position == pos })
                else { continue }
                bracket.matches[idx].topID    = f1.winnerID
                bracket.matches[idx].bottomID = f2.winnerID
                let top    = bracket.matches[idx].topID
                let bottom = bracket.matches[idx].bottomID
                // Only auto-advance when the opposing feeder is a phantom slot (no players at all),
                // not when it's a real unplayed match whose winnerID happens to be nil.
                if top != nil && bottom == nil && f2.topID == nil && f2.bottomID == nil {
                    bracket.matches[idx].winnerID = top
                }
                if bottom != nil && top == nil && f1.topID == nil && f1.bottomID == nil {
                    bracket.matches[idx].winnerID = bottom
                }
            }
        }
    }

    // Recursive fold: produces bracket order so seed s faces seed (size+1-s)
    private static func standardSeedOrder(size: Int) -> [Int] {
        if size == 1 { return [1] }
        let half = standardSeedOrder(size: size / 2)
        var result: [Int] = []
        for seed in half {
            result.append(seed)
            result.append(size + 1 - seed)
        }
        return result
    }

    private static func nextPow2(_ n: Int) -> Int {
        var p = 1
        while p < n { p <<= 1 }
        return p
    }
}
