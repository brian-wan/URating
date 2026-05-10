import SwiftUI
import SwiftData
import Charts
import PhotosUI

struct RatingPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rating: Double
}

struct HeadToHeadRecord: Identifiable {
    let id = UUID()
    let opponent: Player
    let wins: Int
    let losses: Int
    var total: Int { wins + losses }
}

struct PlayerProfileView: View {
    let membership: LeagueMembership
    let league: League
    @Query(sort: \Match.date, order: .reverse) private var allMatches: [Match]
    @State private var photoItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false

    var player: Player? { membership.player }

    var playerMatches: [Match] {
        guard let player else { return [] }
        return allMatches.filter {
            $0.league?.id == league.id &&
            ($0.player1?.id == player.id || $0.player2?.id == player.id)
        }
    }

    var ratingHistory: [RatingPoint] {
        guard let player else { return [] }
        let sorted = playerMatches.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }
        var points: [RatingPoint] = []
        let first = sorted[0]
        let initRating = first.player1?.id == player.id ? first.player1RatingBefore : first.player2RatingBefore
        points.append(RatingPoint(date: first.date.addingTimeInterval(-3600), rating: initRating))
        for match in sorted {
            let rating = match.player1?.id == player.id ? match.player1RatingAfter : match.player2RatingAfter
            points.append(RatingPoint(date: match.date, rating: rating))
        }
        return points
    }

    var headToHead: [HeadToHeadRecord] {
        guard let player else { return [] }
        var records: [UUID: (opponent: Player, wins: Int, losses: Int)] = [:]
        for match in playerMatches {
            let isP1 = match.player1?.id == player.id
            guard let opp = isP1 ? match.player2 : match.player1 else { continue }
            let won = isP1 ? match.player1Won : !match.player1Won
            if records[opp.id] == nil { records[opp.id] = (opp, 0, 0) }
            if won { records[opp.id]!.wins += 1 } else { records[opp.id]!.losses += 1 }
        }
        return records.values
            .map { HeadToHeadRecord(opponent: $0.opponent, wins: $0.wins, losses: $0.losses) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                if let player {
                    VStack(spacing: 24) {
                        headerSection(player: player)
                        statsGrid
                        if ratingHistory.count >= 2 {
                            ratingChartSection
                        }
                        if !headToHead.isEmpty {
                            headToHeadSection
                        }
                        matchHistorySection(player: player)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle(player?.name ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.75)
                else { return }
                player?.photoData = compressed
            }
        }
    }

    func headerSection(player: Player) -> some View {
        VStack(spacing: 10) {
            Button { showingPhotoPicker = true } label: {
                ZStack(alignment: .bottomTrailing) {
                    PlayerAvatar(player: player, size: 80)
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .background(Color.black.clipShape(Circle()))
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)
            Text(player.name).font(.title2.bold())
            HStack(spacing: 4) {
                Text("\(Int(membership.rating.rounded()))")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Color(hex: player.colorHex))
                Text("pts").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    var statsGrid: some View {
        HStack(spacing: 0) {
            statCell(value: "\(membership.wins)", label: "Wins")
            Divider().frame(height: 36).background(Color(white: 0.2))
            statCell(value: "\(membership.losses)", label: "Losses")
            Divider().frame(height: 36).background(Color(white: 0.2))
            statCell(value: "\(Int((membership.winRate * 100).rounded()))%", label: "Win Rate")
            Divider().frame(height: 36).background(Color(white: 0.2))
            statCell(value: "\(membership.totalMatches)", label: "Matches")
        }
        .padding(.vertical, 16)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.title3, design: .rounded, weight: .bold))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    var ratingChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rating History").font(.headline)
            Chart(ratingHistory) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Rating", point.rating)
                )
                .foregroundStyle(Color(hex: player?.colorHex ?? "#3498DB"))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Rating", point.rating)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: player?.colorHex ?? "#3498DB").opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Color(white: 0.2))
                    AxisValueLabel()
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(16)
            .background(Color(white: 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    var headToHeadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Head-to-Head").font(.headline)
            VStack(spacing: 8) {
                ForEach(headToHead) { record in
                    HStack(spacing: 12) {
                        PlayerAvatar(player: record.opponent, size: 36)
                        Text(record.opponent.name)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        HStack(spacing: 0) {
                            Text("\(record.wins)")
                                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                .foregroundStyle(.green)
                                .frame(width: 28, alignment: .trailing)
                            Text(" - ")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text("\(record.losses)")
                                .font(.system(.subheadline, design: .monospaced, weight: .bold))
                                .foregroundStyle(.red)
                                .frame(width: 28, alignment: .leading)
                        }
                        // Win rate bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.red.opacity(0.3)).frame(height: 4)
                                Capsule().fill(Color.green)
                                    .frame(width: record.total > 0
                                        ? geo.size.width * CGFloat(record.wins) / CGFloat(record.total)
                                        : 0,
                                           height: 4)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                    .padding(12)
                    .background(Color(white: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    func matchHistorySection(player: Player) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Match History").font(.headline)
            if playerMatches.isEmpty {
                Text("No matches yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(playerMatches) { match in
                    ProfileMatchRow(match: match, playerId: player.id)
                }
            }
        }
    }
}

struct ProfileMatchRow: View {
    let match: Match
    let playerId: UUID

    var isPlayer1: Bool { match.player1?.id == playerId }
    var won: Bool { isPlayer1 ? match.player1Won : !match.player1Won }
    var opponent: Player? { isPlayer1 ? match.player2 : match.player1 }
    var delta: Double {
        let after  = isPlayer1 ? match.player1RatingAfter  : match.player2RatingAfter
        let before = isPlayer1 ? match.player1RatingBefore : match.player2RatingBefore
        return after - before
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(won ? Color.green : Color.red)
                .frame(width: 4, height: 48)
            if let opp = opponent {
                PlayerAvatar(player: opp, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("vs \(opp.name)")
                        .font(.subheadline.weight(.medium))
                    Group {
                        if !match.score.isEmpty { Text(match.score) }
                        else { Text(match.date.formatted(date: .abbreviated, time: .omitted)) }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(won ? "Win" : "Loss")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(won ? .green : .red)
                Text(delta >= 0 ? "+\(Int(delta.rounded()))" : "\(Int(delta.rounded()))")
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundStyle(delta >= 0 ? .green : .red)
            }
        }
        .padding(12)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
