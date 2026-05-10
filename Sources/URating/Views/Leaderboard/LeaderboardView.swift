import SwiftUI
import SwiftData

enum LeaderboardSort: String, CaseIterable {
    case rating  = "Rating"
    case wins    = "Wins"
    case winRate = "Win %"
    case matches = "Matches"
}

struct LeaderboardView: View {
    let league: League
    @State private var sort: LeaderboardSort = .rating
    @State private var ascending = false

    var sortedMemberships: [LeagueMembership] {
        let ordered: [LeagueMembership]
        switch sort {
        case .rating:  ordered = league.memberships.sorted { $0.rating > $1.rating }
        case .wins:    ordered = league.memberships.sorted { $0.wins > $1.wins }
        case .winRate: ordered = league.memberships.sorted { $0.winRate > $1.winRate }
        case .matches: ordered = league.memberships.sorted { $0.totalMatches > $1.totalMatches }
        }
        return ascending ? ordered.reversed() : ordered
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if league.memberships.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(sortedMemberships.enumerated()), id: \.element.id) { index, membership in
                                if let player = membership.player {
                                    NavigationLink(destination: PlayerProfileView(membership: membership, league: league)) {
                                        LeaderboardRowView(player: player, membership: membership, league: league, rank: index + 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Sort by") {
                            ForEach(LeaderboardSort.allCases, id: \.self) { option in
                                Button {
                                    sort = option
                                } label: {
                                    if sort == option {
                                        Label(option.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        }
                        Section {
                            Button {
                                ascending.toggle()
                            } label: {
                                Label(
                                    ascending ? "Highest First" : "Lowest First",
                                    systemImage: ascending ? "arrow.down" : "arrow.up"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No players yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add players in the Players tab to get started.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

struct LeaderboardRowView: View {
    let player: Player
    let membership: LeagueMembership
    let league: League
    let rank: Int
    private var profile: UserProfile { UserProfile.shared }
    var isMe: Bool { profile.myPlayerID(inLeague: league.id) == player.id }

    var recentForm: [Bool] {
        league.matches
            .filter { $0.player1?.id == player.id || $0.player2?.id == player.id }
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0.player1?.id == player.id ? $0.player1Won : !$0.player1Won }
    }

    var streak: (count: Int, isWin: Bool)? {
        let sorted = league.matches
            .filter { $0.player1?.id == player.id || $0.player2?.id == player.id }
            .sorted { $0.date > $1.date }
        guard let first = sorted.first else { return nil }
        let firstWon = first.player1?.id == player.id ? first.player1Won : !first.player1Won
        var count = 0
        for match in sorted {
            let won = match.player1?.id == player.id ? match.player1Won : !match.player1Won
            if won == firstWon { count += 1 } else { break }
        }
        return count >= 3 ? (count, firstWon) : nil
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                .foregroundStyle(rankColor)
                .frame(width: 36, alignment: .leading)

            PlayerAvatar(player: player, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if isMe {
                        Text("You")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    if let s = streak {
                        Text("\(s.count)\(s.isWin ? "W" : "L")")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(s.isWin ? .green : .red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background((s.isWin ? Color.green : Color.red).opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 4) {
                    Text("\(membership.wins)W · \(membership.losses)L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !recentForm.isEmpty {
                        Spacer().frame(width: 4)
                        formDots
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(membership.rating.rounded()))")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                if membership.totalMatches > 0 {
                    Text("\(Int((membership.winRate * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isMe ? Color(white: 0.14) : Color(white: 0.1))
        .contentShape(Rectangle())
    }

    var formDots: some View {
        HStack(spacing: 3) {
            ForEach(Array(recentForm.enumerated()), id: \.offset) { _, won in
                Circle()
                    .fill(won ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
            }
        }
    }

    var rankColor: Color {
        switch rank {
        case 1:  return .yellow
        case 2:  return Color(white: 0.75)
        case 3:  return Color(hex: "#CD7F32")
        default: return .secondary
        }
    }
}
