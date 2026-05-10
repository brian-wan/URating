import SwiftUI
import SwiftData

struct CreateTournamentView: View {
    let league: League
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var format: TournamentFormat = .roundRobin
    @State private var selectedIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        nameSection
                        formatSection
                        playerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Tournament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createTournament() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedIDs.count < 2)
                }
            }
        }
    }

    var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Image(systemName: "flag")
                    .font(.body).foregroundStyle(.secondary).frame(width: 22)
                TextField("Tournament name", text: $name)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Format").font(.subheadline).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(TournamentFormat.allCases.enumerated()), id: \.element) { index, fmt in
                    Button { format = fmt } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(fmt.rawValue).font(.body).foregroundStyle(.primary)
                                Text(formatDescription(fmt)).font(.caption).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            if format == fmt {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    if index < TournamentFormat.allCases.count - 1 {
                        Divider().padding(.leading, 16).background(Color(white: 0.2))
                    }
                }
            }
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    var playerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Players").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedIDs.count) selected").font(.caption).foregroundStyle(.tertiary)
            }
            VStack(spacing: 0) {
                ForEach(Array(league.memberships.enumerated()), id: \.element.id) { index, membership in
                    if let player = membership.player {
                        let pid = player.id.uuidString
                        Button {
                            if selectedIDs.contains(pid) { selectedIDs.remove(pid) }
                            else { selectedIDs.insert(pid) }
                        } label: {
                            HStack(spacing: 12) {
                                PlayerAvatar(player: player, size: 36)
                                Text(player.name).font(.body).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: selectedIDs.contains(pid) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(pid) ? .blue : .secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        if index < league.memberships.count - 1 {
                            Divider().padding(.leading, 64).background(Color(white: 0.2))
                        }
                    }
                }
            }
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if selectedIDs.count >= 2 {
                let n     = selectedIDs.count
                let count = format == .singleElimination ? n - 1 : n * (n - 1) / 2
                Text("\(count) match\(count == 1 ? "" : "es") will be played")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    func formatDescription(_ format: TournamentFormat) -> String {
        switch format {
        case .roundRobin:        return "Everyone plays everyone"
        case .singleElimination: return "Lose once and you're out"
        }
    }

    func createTournament() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, selectedIDs.count >= 2 else { return }
        let tournament = Tournament(name: trimmed, league: league, format: format)
        tournament.participantIDs = Array(selectedIDs)
        if format == .singleElimination {
            let participantMemberships = selectedIDs.compactMap { pid in
                league.memberships.first { $0.player?.id.uuidString == pid }
            }
            let bracket = BracketEngine.generate(participants: participantMemberships)
            tournament.bracketData = BracketEngine.encode(bracket)
        }
        context.insert(tournament)
        dismiss()
    }
}
