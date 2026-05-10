import SwiftUI

struct LeagueTabView: View {
    let league: League
    @State private var showingSettings = false

    var body: some View {
        TabView {
            LeaderboardView(league: league)
                .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }

            MatchFeedView(league: league)
                .tabItem { Label("Matches", systemImage: "sportscourt.fill") }

            TournamentsView(league: league)
                .tabItem { Label("Tournaments", systemImage: "flag.fill") }

            PlayersView(league: league)
                .tabItem { Label("Players", systemImage: "person.2.fill") }
        }
        .navigationTitle(league.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            LeagueSettingsView(league: league)
        }
    }
}
