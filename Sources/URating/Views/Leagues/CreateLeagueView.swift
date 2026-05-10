import SwiftUI
import SwiftData

struct CreateLeagueView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var color: String = Color.playerColors.randomElement() ?? Color.playerColors[0]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: color).opacity(0.18))
                                    .frame(width: 88, height: 88)
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color(hex: color))
                            }
                            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text(name)
                                    .font(.title3.weight(.semibold))
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }
                        }
                        .animation(.spring(response: 0.3), value: name)
                        .padding(.top, 16)

                        VStack(spacing: 0) {
                            fieldRow(icon: "trophy", placeholder: "League Name", text: $name)
                            Divider().background(Color(white: 0.2)).padding(.leading, 54)
                            fieldRow(icon: "text.alignleft", placeholder: "Description (optional)", text: $description)
                        }
                        .background(Color(white: 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New League")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createLeague() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    func fieldRow(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .center)
            TextField(placeholder, text: text)
                .font(.body)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }

    func createLeague() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let league = League(
            name: trimmed,
            sport: description.trimmingCharacters(in: .whitespaces),
            colorHex: color
        )
        context.insert(league)
        dismiss()
    }
}
