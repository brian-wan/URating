import SwiftUI
import SwiftData

struct MatchFeedView: View {
    let league: League
    @Environment(\.modelContext) private var context
    @State private var showingRecordMatch = false
    @State private var rematchMatch: Match?
    @State private var matchToDelete: Match?
    @State private var showDeleteAlert = false
    @State private var isRefreshing = false
    @State private var displayLimit = 20

    var sortedMatches: [Match] {
        league.matches.sorted { $0.date > $1.date }
    }

    var pagedMatches: [Match] {
        Array(sortedMatches.prefix(displayLimit))
    }

    var groupedMatches: [(title: String, matches: [Match])] {
        var result: [(title: String, matches: [Match])] = []
        var currentTitle = ""
        var currentGroup: [Match] = []
        for match in pagedMatches {
            let title = sectionTitle(for: match.date)
            if title != currentTitle {
                if !currentGroup.isEmpty { result.append((currentTitle, currentGroup)) }
                currentTitle = title
                currentGroup = [match]
            } else {
                currentGroup.append(match)
            }
        }
        if !currentGroup.isEmpty { result.append((currentTitle, currentGroup)) }
        return result
    }

    func sectionTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if let week = cal.dateInterval(of: .weekOfYear, for: .now), week.contains(date) {
            return "This Week"
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if sortedMatches.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedMatches, id: \.title) { group in
                            Section {
                                ForEach(group.matches) { match in
                                    MatchCardView(match: match, league: league)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                matchToDelete = match
                                                showDeleteAlert = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                rematchMatch = match
                                            } label: {
                                                Label("Rematch", systemImage: "arrow.clockwise")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            } header: {
                                Text(group.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(nil)
                                    .padding(.leading, 4)
                            }
                        }

                        if sortedMatches.count > displayLimit {
                            Button { displayLimit += 20 } label: {
                                Text("Load More")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(white: 0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.bottom, 60)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showingRecordMatch = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundStyle(.black)
                        .frame(width: 56, height: 56)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .white.opacity(0.2), radius: 8)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Matches")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if league.isShared {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { Task { await refresh() } } label: {
                            if isRefreshing { ProgressView() }
                            else { Image(systemName: "arrow.clockwise") }
                        }
                        .disabled(isRefreshing)
                    }
                }
            }
            .alert("Delete Match?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let match = matchToDelete { deleteMatch(match) }
                    matchToDelete = nil
                }
                Button("Cancel", role: .cancel) { matchToDelete = nil }
            } message: {
                Text("Rating changes will be reversed for both players.")
            }
        }
        .sheet(isPresented: $showingRecordMatch) {
            RecordMatchView(league: league)
        }
        .sheet(item: $rematchMatch) { match in
            let m1 = league.memberships.first { $0.player?.id == match.player1?.id }
            let m2 = league.memberships.first { $0.player?.id == match.player2?.id }
            RecordMatchView(league: league, preset1: m1, preset2: m2)
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No matches yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to record your first match.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private func deleteMatch(_ match: Match) {
        if let m1 = league.memberships.first(where: { $0.player?.id == match.player1?.id }) {
            m1.rating -= match.player1RatingAfter - match.player1RatingBefore
            if match.player1Won { m1.wins = max(0, m1.wins - 1) } else { m1.losses = max(0, m1.losses - 1) }
        }
        if let m2 = league.memberships.first(where: { $0.player?.id == match.player2?.id }) {
            m2.rating -= match.player2RatingAfter - match.player2RatingBefore
            if !match.player1Won { m2.wins = max(0, m2.wins - 1) } else { m2.losses = max(0, m2.losses - 1) }
        }
        context.delete(match)
    }

    private func refresh() async {
        isRefreshing = true
        try? await CloudKitManager.shared.refreshMatches(for: league, into: context)
        isRefreshing = false
    }
}

struct MatchCardView: View {
    let match: Match
    let league: League

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                playerSide(player: match.player1, won: match.player1Won,
                           ratingBefore: match.player1RatingBefore, ratingAfter: match.player1RatingAfter)
                Text("vs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                playerSide(player: match.player2, won: !match.player1Won,
                           ratingBefore: match.player2RatingBefore, ratingAfter: match.player2RatingAfter)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Color(white: 0.2))

            HStack {
                if !match.score.isEmpty {
                    Text(match.score).font(.caption).foregroundStyle(.secondary)
                }
                if let tournament = match.tournament {
                    if !match.score.isEmpty { Text("·").font(.caption).foregroundStyle(.tertiary) }
                    Text(tournament.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(match.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    func playerSide(player: Player?, won: Bool, ratingBefore: Double, ratingAfter: Double) -> some View {
        let delta    = ratingAfter - ratingBefore
        let deltaStr = delta >= 0 ? "+\(Int(delta.rounded()))" : "\(Int(delta.rounded()))"
        VStack(spacing: 6) {
            if let player {
                let membership = league.memberships.first { $0.player?.id == player.id }
                Group {
                    if let membership {
                        NavigationLink(destination: PlayerProfileView(membership: membership, league: league)) {
                            PlayerAvatar(player: player, size: 40)
                        }
                        .buttonStyle(.plain)
                    } else {
                        PlayerAvatar(player: player, size: 40)
                    }
                }
                Text(player.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(won ? .primary : Color(white: 0.5))
                    .lineLimit(1)
            } else {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(white: 0.35))
                    .frame(width: 40, height: 40)
                Text("Deleted")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(white: 0.35))
                    .lineLimit(1)
            }
            Text(won ? "Won" : "Lost")
                .font(.caption.weight(.medium))
                .foregroundStyle(won ? .green : .red)
            Text(deltaStr)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(delta >= 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity)
    }
}
