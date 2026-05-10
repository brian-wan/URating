import SwiftUI
import SwiftData

struct Pairing: Identifiable {
    let id = UUID()
    let membership1: LeagueMembership
    let membership2: LeagueMembership
    var completedMatch: Match?

    var isCompleted: Bool { completedMatch != nil }
}

struct TournamentDetailView: View {
    let tournament: Tournament
    let league: League
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var recordingPairing: Pairing?
    @State private var showDeleteAlert = false
    @State private var bracket: Bracket?

    var participants: [LeagueMembership] {
        tournament.participantIDs.compactMap { pid in
            league.memberships.first { $0.player?.id.uuidString == pid }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if tournament.format == .singleElimination {
                bracketContent
            } else {
                roundRobinContent
            }
        }
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
            }
        }
        .alert("Delete Tournament?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                context.delete(tournament)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the tournament and its match records.")
        }
        .sheet(item: $recordingPairing) { pairing in
            RecordMatchView(league: league, preset1: pairing.membership1, preset2: pairing.membership2)
        }
        .onAppear { loadBracket() }
    }

    // MARK: - Bracket (Single Elimination)

    var bracketContent: some View {
        VStack(spacing: 0) {
            if let b = bracket {
                bracketRoundHeader(b)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                BracketView(bracket: b, memberships: participants) { match, winnerID in
                    handleSelectWinner(match, winnerID)
                }
            } else {
                Spacer()
                ProgressView()
                Spacer()
            }
        }
    }

    func bracketRoundHeader(_ b: Bracket) -> some View {
        let isComplete = b.champion != nil
        let label      = isComplete ? "Champion Crowned" : b.roundLabel(for: b.currentRound)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.headline)
                if !isComplete {
                    Text("Tap a player to advance them")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isComplete {
                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func loadBracket() {
        if let data = tournament.bracketData {
            bracket = BracketEngine.decode(data)
        } else {
            let b = BracketEngine.generate(participants: participants)
            bracket = b
            tournament.bracketData = BracketEngine.encode(b)
        }
    }

    func handleSelectWinner(_ bracketMatch: BracketMatch, _ winnerID: String) {
        guard var b = bracket else { return }
        guard let topID    = bracketMatch.topID,
              let bottomID = bracketMatch.bottomID else { return }
        guard let topM    = participants.first(where: { $0.player?.id.uuidString == topID }),
              let bottomM = participants.first(where: { $0.player?.id.uuidString == bottomID }),
              let topPlayer    = topM.player,
              let bottomPlayer = bottomM.player else { return }

        let player1Won = winnerID == topID
        let winnerM = player1Won ? topM : bottomM
        let loserM  = player1Won ? bottomM : topM
        let change  = ELOService.ratingChange(winnerRating: winnerM.rating, loserRating: loserM.rating)

        let match = Match(
            league: league,
            player1: topPlayer,
            player2: bottomPlayer,
            player1Won: player1Won,
            score: "",
            tournament: tournament,
            player1RatingBefore: topM.rating,
            player2RatingBefore: bottomM.rating,
            player1RatingAfter: topM.rating + (player1Won ? change : -change),
            player2RatingAfter: bottomM.rating + (player1Won ? -change : change)
        )
        context.insert(match)
        winnerM.rating  += change
        loserM.rating   -= change
        winnerM.wins    += 1
        loserM.losses   += 1

        BracketEngine.recordWinner(
            matchID: bracketMatch.id,
            winnerID: winnerID,
            matchRecordID: match.id.uuidString,
            in: &b
        )
        bracket = b
        tournament.bracketData = BracketEngine.encode(b)
    }

    // MARK: - Round Robin

    var pairings: [Pairing] {
        var result: [Pairing] = []
        for i in 0..<participants.count {
            for j in (i+1)..<participants.count {
                let m1 = participants[i]
                let m2 = participants[j]
                let played = tournament.matches.first {
                    ($0.player1?.id == m1.player?.id && $0.player2?.id == m2.player?.id) ||
                    ($0.player1?.id == m2.player?.id && $0.player2?.id == m1.player?.id)
                }
                result.append(Pairing(membership1: m1, membership2: m2, completedMatch: played))
            }
        }
        return result
    }

    var standings: [(membership: LeagueMembership, wins: Int, losses: Int)] {
        var map: [UUID: (membership: LeagueMembership, wins: Int, losses: Int)] = [:]
        for p in participants {
            if let pid = p.player?.id { map[pid] = (p, 0, 0) }
        }
        for match in tournament.matches {
            if let p1id = match.player1?.id, let p2id = match.player2?.id {
                if match.player1Won {
                    map[p1id]?.wins   += 1
                    map[p2id]?.losses += 1
                } else {
                    map[p2id]?.wins   += 1
                    map[p1id]?.losses += 1
                }
            }
        }
        return map.values.sorted { ($0.wins, $1.losses) > ($1.wins, $0.losses) }
    }

    var roundRobinContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                rrProgressSection
                if !tournament.matches.isEmpty {
                    standingsSection
                }
                pairingsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    var rrProgressSection: some View {
        let total    = pairings.count
        let done     = pairings.filter { $0.isCompleted }.count
        let progress = total > 0 ? Double(done) / Double(total) : 0
        return VStack(spacing: 8) {
            HStack {
                Text("\(done) of \(total) matches played")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.subheadline.weight(.semibold))
            }
            ProgressView(value: progress)
                .tint(Color(hex: league.colorHex))
                .scaleEffect(x: 1, y: 1.5)
        }
        .padding(16)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var standingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Standings").font(.headline)
            VStack(spacing: 2) {
                ForEach(Array(standings.enumerated()), id: \.element.membership.id) { index, entry in
                    HStack(spacing: 14) {
                        Text("#\(index + 1)")
                            .font(.system(.subheadline, design: .monospaced, weight: .bold))
                            .foregroundStyle(index == 0 ? .yellow : .secondary)
                            .frame(width: 28, alignment: .leading)
                        if let player = entry.membership.player {
                            PlayerAvatar(player: player, size: 36)
                            Text(player.name).font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        Text("\(entry.wins)W · \(entry.losses)L")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.1))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    var pairingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Matchups").font(.headline)
            VStack(spacing: 8) {
                ForEach(pairings) { pairing in
                    PairingRow(pairing: pairing, leagueColor: league.colorHex) {
                        recordingPairing = pairing
                    }
                }
            }
        }
    }
}

struct PairingRow: View {
    let pairing: Pairing
    let leagueColor: String
    let onRecord: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let p1 = pairing.membership1.player {
                VStack(spacing: 4) {
                    PlayerAvatar(player: p1, size: 36)
                    Text(p1.name).font(.caption).lineLimit(1)
                        .foregroundStyle(winnerIs(p1) ? .primary : (pairing.isCompleted ? Color(white: 0.4) : .primary))
                }
                .frame(maxWidth: .infinity)
            }

            Text("vs").font(.caption).foregroundStyle(.secondary)

            if let p2 = pairing.membership2.player {
                VStack(spacing: 4) {
                    PlayerAvatar(player: p2, size: 36)
                    Text(p2.name).font(.caption).lineLimit(1)
                        .foregroundStyle(winnerIs(p2) ? .primary : (pairing.isCompleted ? Color(white: 0.4) : .primary))
                }
                .frame(maxWidth: .infinity)
            }

            if pairing.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button(action: onRecord) {
                    Text("Record")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(pairing.isCompleted ? Color(white: 0.08) : Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func winnerIs(_ player: Player) -> Bool {
        guard let match = pairing.completedMatch else { return false }
        return match.player1Won ? match.player1?.id == player.id : match.player2?.id == player.id
    }
}
