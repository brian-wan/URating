import SwiftUI
import SwiftData

struct PlayersView: View {
    let league: League
    @Environment(\.modelContext) private var context
    @State private var showingAddPlayer = false
    @State private var membershipToDelete: LeagueMembership?
    @State private var showDeleteAlert = false

    var sortedMemberships: [LeagueMembership] {
        league.memberships.sorted { ($0.player?.name ?? "") < ($1.player?.name ?? "") }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if league.memberships.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(sortedMemberships) { membership in
                            if let player = membership.player {
                                NavigationLink(destination: PlayerProfileView(membership: membership, league: league)) {
                                    HStack(spacing: 12) {
                                        PlayerAvatar(player: player, size: 40)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(player.name)
                                                .font(.headline)
                                            Text("\(Int(membership.rating.rounded())) pts · \(membership.wins)W \(membership.losses)L")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        membershipToDelete = membership
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                                .listRowBackground(Color(white: 0.1))
                                .listRowSeparatorTint(Color(white: 0.2))
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                    .padding(.bottom, 80)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { showingAddPlayer = true } label: {
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
            .navigationTitle("Players")
            .navigationBarTitleDisplayMode(.large)
            .alert("Remove Player?", isPresented: $showDeleteAlert) {
                Button("Remove", role: .destructive) {
                    if let m = membershipToDelete { context.delete(m) }
                    membershipToDelete = nil
                }
                Button("Cancel", role: .cancel) { membershipToDelete = nil }
            } message: {
                Text("This removes \(membershipToDelete?.player?.name ?? "the player") from this league. Their match history will be kept.")
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(league: league)
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No players yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap + to add your first player.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

}
