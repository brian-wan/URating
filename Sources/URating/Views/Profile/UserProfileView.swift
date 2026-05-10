import SwiftUI
import SwiftData
import PhotosUI

struct UserProfileView: View {
    @Query(sort: \League.createdAt) private var leagues: [League]
    @Environment(\.dismiss) private var dismiss

    private var profile: UserProfile { UserProfile.shared }
    @State private var name: String = UserProfile.shared.name
    @State private var photoItem: PhotosPickerItem?
    @State private var showingPhotoPicker = false

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        let t = name.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "?" : String(t.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        avatarSection
                        nameSection
                        if !leagues.isEmpty { leagueIdentitySection }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        profile.name = name.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self),
                      let compressed = UIImage(data: data)?.jpegData(compressionQuality: 0.75)
                else { return }
                profile.photoData = compressed
            }
        }
    }

    var avatarSection: some View {
        Button { showingPhotoPicker = true } label: {
            ZStack(alignment: .bottomTrailing) {
                if let data = profile.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable().scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle().fill(Color(hex: "#3498DB")).frame(width: 88, height: 88)
                        Text(initials)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
                    .background(Color.black.clipShape(Circle()))
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
    }

    var nameSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "person")
                    .font(.body).foregroundStyle(.secondary).frame(width: 22)
                TextField("Your name", text: $name)
                    .font(.body)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var leagueIdentitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Player").font(.subheadline).foregroundStyle(.secondary)
                Text("Choose which player you are in each league.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            VStack(spacing: 0) {
                ForEach(Array(leagues.enumerated()), id: \.element.id) { index, league in
                    LeagueIdentityRow(league: league)
                    if index < leagues.count - 1 {
                        Divider().padding(.leading, 16).background(Color(white: 0.2))
                    }
                }
            }
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct LeagueIdentityRow: View {
    let league: League
    private var profile: UserProfile { UserProfile.shared }

    var myMembership: LeagueMembership? {
        guard let pid = profile.myPlayerID(inLeague: league.id) else { return nil }
        return league.memberships.first { $0.player?.id == pid }
    }

    var body: some View {
        Menu {
            if myMembership != nil {
                Button(role: .destructive) {
                    profile.setMyPlayer(nil, inLeague: league.id)
                } label: {
                    Label("Remove", systemImage: "xmark.circle")
                }
                Divider()
            }
            ForEach(league.memberships) { membership in
                if let player = membership.player {
                    Button {
                        profile.setMyPlayer(player.id, inLeague: league.id)
                    } label: {
                        Label(player.name, systemImage: "person")
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: league.colorHex).opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: "trophy.fill").font(.caption).foregroundStyle(Color(hex: league.colorHex))
                }
                Text(league.name).font(.subheadline).foregroundStyle(.primary)
                Spacer()
                if let m = myMembership, let p = m.player {
                    PlayerAvatar(player: p, size: 28)
                    Text(p.name).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Not set").font(.caption).foregroundStyle(.tertiary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}
