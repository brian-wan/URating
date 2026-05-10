import SwiftUI
import SwiftData
import PhotosUI

struct AddPlayerView: View {
    let league: League
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Player.name) private var allPlayers: [Player]

    @State private var name = ""
    @State private var mode: Mode = .new
    @State private var color: String = Color.playerColors.randomElement() ?? Color.playerColors[0]
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showingPhotoPicker = false

    enum Mode { case new, existing }

    var existingNotInLeague: [Player] {
        let leaguePlayerIDs = Set(league.memberships.compactMap { $0.player?.id })
        return allPlayers.filter { !leaguePlayerIDs.contains($0.id) }
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    if !existingNotInLeague.isEmpty {
                        Picker("", selection: $mode) {
                            Text("New Player").tag(Mode.new)
                            Text("Existing Player").tag(Mode.existing)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }

                    if mode == .new {
                        newPlayerForm
                    } else {
                        existingPlayerList
                    }
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if mode == .new {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") { addNewPlayer() }
                            .fontWeight(.bold)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.75)
                else { return }
                photoData = compressed
            }
        }
    }

    var newPlayerForm: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Button { showingPhotoPicker = true } label: {
                        ZStack(alignment: .bottomTrailing) {
                            if let data = photoData, let ui = UIImage(data: data) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                PlayerAvatar(initials: initials, colorHex: color, size: 80)
                            }
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .background(Color.black.clipShape(Circle()))
                                .offset(x: 4, y: 4)
                        }
                    }
                    .buttonStyle(.plain)

                    if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(name)
                            .font(.title3.weight(.semibold))
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .animation(.spring(response: 0.3), value: name)
                .padding(.top, 16)

                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Image(systemName: "person")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .center)
                        TextField("Name", text: $name)
                            .font(.body)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                }
                .background(Color(white: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    var existingPlayerList: some View {
        List {
            ForEach(existingNotInLeague) { player in
                Button {
                    addExistingPlayer(player)
                } label: {
                    HStack(spacing: 12) {
                        PlayerAvatar(player: player, size: 40)
                        Text(player.name).font(.headline).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(white: 0.1))
                .listRowSeparatorTint(Color(white: 0.2))
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
    }

    func addNewPlayer() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let player = Player(name: trimmed, colorHex: color)
        player.photoData = photoData
        context.insert(player)
        let membership = LeagueMembership(player: player, league: league)
        context.insert(membership)
        dismiss()
    }

    func addExistingPlayer(_ player: Player) {
        let membership = LeagueMembership(player: player, league: league)
        context.insert(membership)
        dismiss()
    }
}
