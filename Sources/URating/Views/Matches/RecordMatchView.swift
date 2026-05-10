import SwiftUI
import SwiftData

struct RecordMatchView: View {
    let league: League
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var member1: LeagueMembership?
    @State private var member2: LeagueMembership?
    @State private var member1Won: Bool?
    @State private var score = ""
    @State private var isSaving = false

    init(league: League, preset1: LeagueMembership? = nil, preset2: LeagueMembership? = nil) {
        self.league  = league
        self._member1 = State(initialValue: preset1)
        self._member2 = State(initialValue: preset2)
    }

    var bothSelected: Bool { member1 != nil && member2 != nil }

    var previewChange: Double? {
        guard let m1 = member1, let m2 = member2, let m1Won = member1Won else { return nil }
        let winner = m1Won ? m1 : m2
        let loser  = m1Won ? m2 : m1
        return ELOService.ratingChange(winnerRating: winner.rating, loserRating: loser.rating, kFactor: league.kFactor)
    }

    var canSubmit: Bool { member1 != nil && member2 != nil && member1Won != nil && !isSaving }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        playerSection
                        scoreSection
                        if let change = previewChange {
                            eloPreviewSection(change: change)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Record Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await saveMatch() } }
                            .fontWeight(.bold)
                            .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    var playerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Players").font(.subheadline).foregroundStyle(.secondary)
                if bothSelected && member1Won == nil {
                    Spacer()
                    Text("Tap to pick winner").font(.caption).foregroundStyle(.tertiary)
                }
            }
            HStack(spacing: 12) {
                PlayerWinnerCard(
                    label: "Player 1",
                    selected: $member1,
                    excluding: member2,
                    memberships: league.memberships,
                    isWinner: member1Won == true,
                    bothSelected: bothSelected
                ) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    member1Won = true
                }

                PlayerWinnerCard(
                    label: "Player 2",
                    selected: $member2,
                    excluding: member1,
                    memberships: league.memberships,
                    isWinner: member1Won == false,
                    bothSelected: bothSelected
                ) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    member1Won = false
                }
            }
        }
    }

    var scoreSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "number")
                    .font(.body).foregroundStyle(.secondary).frame(width: 22, alignment: .center)
                TextField("Score (optional)", text: $score)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func eloPreviewSection(change: Double) -> some View {
        let m1Won        = member1Won == true
        let winnerMember = m1Won ? member1 : member2
        let loserMember  = m1Won ? member2 : member1
        return VStack(alignment: .leading, spacing: 10) {
            Text("Rating Preview").font(.subheadline).foregroundStyle(.secondary)
            VStack(spacing: 10) {
                if let w = winnerMember { ratingRow(name: w.player?.name ?? "", current: w.rating, delta: change) }
                if let l = loserMember  { ratingRow(name: l.player?.name ?? "", current: l.rating, delta: -change) }
            }
            .padding(16)
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    func ratingRow(name: String, current: Double, delta: Double) -> some View {
        HStack {
            Text(name).font(.subheadline)
            Spacer()
            Text("\(Int(current.rounded()))").font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
            Text("\(Int((current + delta).rounded()))").font(.system(.subheadline, design: .monospaced, weight: .bold))
            Text(delta >= 0 ? "+\(Int(delta.rounded()))" : "\(Int(delta.rounded()))")
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(delta >= 0 ? .green : .red)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func saveMatch() async {
        guard let m1 = member1, let m2 = member2, let m1Won = member1Won,
              let p1 = m1.player, let p2 = m2.player else { return }

        isSaving = true

        let winnerMember = m1Won ? m1 : m2
        let loserMember  = m1Won ? m2 : m1
        let p1Before = m1.rating
        let p2Before = m2.rating
        let change   = ELOService.ratingChange(winnerRating: winnerMember.rating, loserRating: loserMember.rating, kFactor: league.kFactor)

        winnerMember.rating += change
        loserMember.rating  -= change
        winnerMember.wins   += 1
        loserMember.losses  += 1

        let match = Match(
            league: league, player1: p1, player2: p2, player1Won: m1Won,
            score: score.trimmingCharacters(in: .whitespaces),
            player1RatingBefore: p1Before,
            player2RatingBefore: p2Before,
            player1RatingAfter:  m1.rating,
            player2RatingAfter:  m2.rating
        )
        context.insert(match)

        if league.isShared {
            try? await CloudKitManager.shared.pushMatch(match, league: league)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isSaving = false
        dismiss()
    }
}

struct PlayerWinnerCard: View {
    let label: String
    @Binding var selected: LeagueMembership?
    let excluding: LeagueMembership?
    let memberships: [LeagueMembership]
    let isWinner: Bool
    let bothSelected: Bool
    let onSelectWinner: () -> Void

    var available: [LeagueMembership] { memberships.filter { $0.id != excluding?.id } }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if bothSelected, selected != nil {
                Button(action: onSelectWinner) {
                    cardFace
                }
                .buttonStyle(.plain)

                Menu {
                    Button("Clear") { selected = nil }
                    Divider()
                    ForEach(available) { m in
                        if let p = m.player {
                            Button { selected = m } label: { Text(p.name) }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(white: 0.3))
                        .padding(8)
                }
            } else {
                Menu {
                    if selected != nil { Button("Clear") { selected = nil }; Divider() }
                    ForEach(available) { m in
                        if let p = m.player {
                            Button { selected = m } label: { Text(p.name) }
                        }
                    }
                } label: {
                    cardFace
                }
            }
        }
    }

    var cardFace: some View {
        VStack(spacing: 10) {
            if let m = selected, let p = m.player {
                PlayerAvatar(player: p, size: 52)
                Text(p.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(bothSelected && !isWinner ? Color(white: 0.45) : .primary)
                    .lineLimit(1)
                Text(isWinner ? "Winner" : " ")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                ZStack {
                    Circle().fill(Color(white: 0.18)).frame(width: 52, height: 52)
                    Image(systemName: "plus").font(.title3).foregroundStyle(.secondary)
                }
                Text("Select").font(.subheadline).foregroundStyle(.tertiary)
                Text(" ").font(.caption)
            }
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(bothSelected && isWinner ? Color(white: 0.15) : Color(white: 0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(
                bothSelected && isWinner
                    ? Color(hex: selected?.player?.colorHex ?? "#3498DB")
                    : Color.clear,
                lineWidth: 2
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct URatingTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color(white: 0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
