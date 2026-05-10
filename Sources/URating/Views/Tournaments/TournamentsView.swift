import SwiftUI
import SwiftData

struct TournamentsView: View {
    let league: League
    @State private var showingCreate = false
    @State private var tournamentToDelete: Tournament?
    @State private var showDeleteAlert = false
    @Environment(\.modelContext) private var context

    var sortedTournaments: [Tournament] {
        league.tournaments.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if sortedTournaments.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedTournaments) { tournament in
                                NavigationLink(destination: TournamentDetailView(tournament: tournament, league: league)) {
                                    TournamentCardView(tournament: tournament, league: league)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        tournamentToDelete = tournament
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete Tournament", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .padding(.bottom, 80)
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showingCreate = true } label: {
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
            .navigationTitle("Tournaments")
            .navigationBarTitleDisplayMode(.large)
            .alert("Delete Tournament?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let t = tournamentToDelete { context.delete(t) }
                    tournamentToDelete = nil
                }
                Button("Cancel", role: .cancel) { tournamentToDelete = nil }
            } message: {
                Text("This will permanently delete the tournament and its match records.")
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateTournamentView(league: league)
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No tournaments yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to create your first tournament.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

struct TournamentCardView: View {
    let tournament: Tournament
    let league: League

    var participants: [LeagueMembership] {
        tournament.participantIDs.compactMap { pid in
            league.memberships.first { $0.player?.id.uuidString == pid }
        }
    }

    var totalMatches: Int {
        let n = participants.count
        return tournament.format == .singleElimination ? max(0, n - 1) : n * (n - 1) / 2
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: league.colorHex).opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: "flag.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hex: league.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tournament.name).font(.headline).foregroundStyle(.primary)
                Text(tournament.format.rawValue).font(.caption).foregroundStyle(.secondary)
                if totalMatches > 0 {
                    HStack(spacing: 6) {
                        ProgressView(value: Double(tournament.matches.count), total: Double(totalMatches))
                            .tint(Color(hex: league.colorHex))
                            .frame(width: 80)
                        Text("\(tournament.matches.count)/\(totalMatches) matches")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
