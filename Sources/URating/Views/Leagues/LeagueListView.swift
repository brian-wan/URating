import SwiftUI
import SwiftData
import CloudKit

struct LeagueListView: View {
    @Query(sort: \League.createdAt) private var leagues: [League]
    @Environment(\.modelContext) private var context

    @State private var showingCreateLeague = false
    @State private var sharingLeague: League?
    @State private var isImportingShare = false
    @State private var importError: String?
    @State private var justImportedLeague: League?
    @State private var showingProfile = false
    private var profile: UserProfile { UserProfile.shared }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if leagues.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(leagues) { league in
                                NavigationLink(destination: LeagueTabView(league: league)) {
                                    LeagueCardView(league: league)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if league.isOwned {
                                        Button {
                                            sharingLeague = league
                                        } label: {
                                            Label(league.isShared ? "Manage Share" : "Share League", systemImage: "person.2.badge.plus")
                                        }
                                    }
                                    Button(role: .destructive) {
                                        context.delete(league)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                }

                if isImportingShare {
                    ZStack {
                        Color.black.opacity(0.6).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)
                            Text("Joining league…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(32)
                        .background(Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .navigationTitle("URating")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingProfile = true } label: {
                        if let data = profile.photoData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable().scaledToFill()
                                .frame(width: 30, height: 30)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: profile.isSetUp ? "person.circle.fill" : "person.circle")
                                .font(.title3)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreateLeague = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Could not join league", isPresented: .constant(importError != nil)) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
        .sheet(isPresented: $showingCreateLeague) {
            CreateLeagueView()
        }
        .sheet(isPresented: $showingProfile) {
            UserProfileView()
        }
        .sheet(item: $sharingLeague) { league in
            CloudSharingView(league: league) {
                sharingLeague = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .cloudKitShareAccepted)) { notification in
            guard let metadata = notification.object as? CKShare.Metadata else { return }
            Task { await handleIncomingShare(metadata) }
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No leagues yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Create a league or accept a share link.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Button("Create League") { showingCreateLeague = true }
                .buttonStyle(.bordered)
                .padding(.top, 4)
        }
    }

    private func handleIncomingShare(_ metadata: CKShare.Metadata) async {
        isImportingShare = true
        do {
            try await CloudKitManager.shared.acceptShare(metadata)
            let league = try await CloudKitManager.shared.importSharedLeague(metadata, into: context)
            justImportedLeague = league
        } catch {
            importError = error.localizedDescription
        }
        isImportingShare = false
    }
}

struct LeagueCardView: View {
    let league: League

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: league.colorHex).opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(Color(hex: league.colorHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(league.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if league.isShared {
                        Image(systemName: league.isOwned ? "person.2.fill" : "person.2")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if !league.sport.isEmpty {
                    Text(league.sport)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("\(league.memberships.count) player\(league.memberships.count == 1 ? "" : "s") · \(league.matches.count) match\(league.matches.count == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
