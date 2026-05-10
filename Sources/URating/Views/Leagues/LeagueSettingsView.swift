import SwiftUI
import SwiftData

struct LeagueSettingsView: View {
    let league: League
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showResetAlert = false
    @State private var showDeleteAlert = false

    private let kFactorOptions: [(label: String, value: Double)] = [
        ("Casual (16)", 16),
        ("Standard (32)", 32),
        ("Competitive (48)", 48),
        ("High Variance (64)", 64),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        kFactorSection
                        dangerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .alert("Reset All Ratings?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) { resetRatings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All player ratings will return to 1000. Match history will be kept.")
            }
            .alert("Delete League?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    context.delete(league)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the league, all matches, and player memberships.")
            }
        }
    }

    var kFactorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("K-Factor").font(.subheadline).foregroundStyle(.secondary)
                Text("Controls how much ratings change per match. Higher = more volatile.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            VStack(spacing: 0) {
                ForEach(Array(kFactorOptions.enumerated()), id: \.offset) { index, option in
                    Button {
                        league.kFactor = option.value
                    } label: {
                        HStack {
                            Text(option.label).font(.body).foregroundStyle(.primary)
                            Spacer()
                            if league.kFactor == option.value {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    if index < kFactorOptions.count - 1 {
                        Divider().padding(.leading, 16).background(Color(white: 0.2))
                    }
                }
            }
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    var dangerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Danger Zone").font(.subheadline).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                Button {
                    showResetAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise").frame(width: 22)
                        Text("Reset All Ratings to 1000")
                        Spacer()
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                Divider().padding(.leading, 54).background(Color(white: 0.2))
                Button {
                    showDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash").frame(width: 22)
                        Text("Delete League")
                        Spacer()
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(white: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func resetRatings() {
        for membership in league.memberships {
            membership.rating = 1000.0
            membership.wins   = 0
            membership.losses = 0
        }
    }
}
