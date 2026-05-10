import SwiftUI

private let kMatchW: CGFloat = 160
private let kMatchH: CGFloat = 72
private let kHGap:   CGFloat = 56
private let kVGap:   CGFloat = 10
private let kPad:    CGFloat = 24

struct BracketView: View {
    let bracket: Bracket
    let memberships: [LeagueMembership]
    let onSelectWinner: (BracketMatch, String) -> Void

    private var slotH: CGFloat { kMatchH + kVGap }

    private var totalWidth: CGFloat {
        kPad * 2
            + CGFloat(bracket.totalRounds) * kMatchW
            + CGFloat(max(0, bracket.totalRounds - 1)) * kHGap
            + 120
    }

    private var totalHeight: CGFloat {
        let r0 = bracket.size / 2
        return kPad * 2
            + CGFloat(r0) * kMatchH
            + CGFloat(max(0, r0 - 1)) * kVGap
    }

    private func matchLeft(_ round: Int) -> CGFloat {
        kPad + CGFloat(round) * (kMatchW + kHGap)
    }

    private func matchCenterY(round: Int, position: Int) -> CGFloat {
        let span   = CGFloat(1 << round)
        let center = CGFloat(position) * span + (span - 1.0) / 2.0
        return kPad + center * slotH + kMatchH / 2
    }

    private func membership(for id: String?) -> LeagueMembership? {
        guard let id else { return nil }
        return memberships.first { $0.player?.id.uuidString == id }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for r in 0..<(bracket.totalRounds - 1) {
                        for match in bracket.round(r) {
                            let sx = matchLeft(r) + kMatchW
                            let sy = matchCenterY(round: r, position: match.position)
                            let mx = sx + kHGap / 2
                            let np = match.position / 2
                            let ny = matchCenterY(round: r + 1, position: np)
                            let ey = match.position % 2 == 0 ? ny - kMatchH / 4 : ny + kMatchH / 4
                            let ex = matchLeft(r + 1)

                            var path = Path()
                            path.move(to: CGPoint(x: sx, y: sy))
                            path.addLine(to: CGPoint(x: mx, y: sy))
                            path.addLine(to: CGPoint(x: mx, y: ey))
                            path.addLine(to: CGPoint(x: ex, y: ey))

                            ctx.stroke(
                                path,
                                with: .color(Color(white: match.isComplete ? 0.45 : 0.22)),
                                lineWidth: 1.5
                            )
                        }
                    }
                }
                .frame(width: totalWidth, height: totalHeight)

                ForEach(bracket.matches) { match in
                    BracketMatchCell(
                        match: match,
                        topMembership: membership(for: match.topID),
                        bottomMembership: membership(for: match.bottomID)
                    ) { winnerID in
                        onSelectWinner(match, winnerID)
                    }
                    .frame(width: kMatchW, height: kMatchH)
                    .position(
                        x: matchLeft(match.round) + kMatchW / 2,
                        y: matchCenterY(round: match.round, position: match.position)
                    )
                }

                if let champID = bracket.champion,
                   let player = membership(for: champID)?.player {
                    VStack(spacing: 5) {
                        Image(systemName: "trophy.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        PlayerAvatar(player: player, size: 38)
                        Text(player.name)
                            .font(.caption.weight(.bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 88)
                    }
                    .padding(10)
                    .background(Color(white: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
                    )
                    .position(
                        x: matchLeft(bracket.totalRounds) + 60,
                        y: matchCenterY(round: bracket.totalRounds - 1, position: 0)
                    )
                }
            }
            .frame(width: totalWidth, height: totalHeight)
        }
    }
}

struct BracketMatchCell: View {
    let match: BracketMatch
    let topMembership: LeagueMembership?
    let bottomMembership: LeagueMembership?
    let onSelectWinner: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            playerRow(playerID: match.topID, membership: topMembership)
            Rectangle().fill(Color(white: 0.2)).frame(height: 1)
            playerRow(playerID: match.bottomID, membership: bottomMembership)
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(match.isPlayable ? Color(white: 0.44) : Color(white: 0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    func playerRow(playerID: String?, membership: LeagueMembership?) -> some View {
        let isWinner = playerID != nil && playerID == match.winnerID
        let isLoser  = match.isComplete && !isWinner && playerID != nil
        let canTap   = match.isPlayable && playerID != nil

        Button {
            if canTap, let pid = playerID { onSelectWinner(pid) }
        } label: {
            HStack(spacing: 7) {
                if let player = membership?.player {
                    PlayerAvatar(player: player, size: 22)
                        .opacity(isLoser ? 0.4 : 1)
                    Text(player.name)
                        .font(.caption.weight(isWinner ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundStyle(isLoser ? Color(white: 0.35) : .primary)
                } else {
                    Text(playerID != nil ? "TBD" : "—")
                        .font(.caption)
                        .foregroundStyle(Color(white: 0.28))
                }
                Spacer(minLength: 0)
                if isWinner {
                    Image(systemName: "chevron.right.2")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isWinner ? Color(white: 0.17) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
    }
}
