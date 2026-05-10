import SwiftUI
import SwiftData
import CloudKit

@main
struct URatingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    static let container: ModelContainer = {
        let schema = Schema([Player.self, League.self, LeagueMembership.self, Match.self, Tournament.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            LeagueListView()
                .preferredColorScheme(.dark)
                .task { await CloudKitManager.shared.setup() }
        }
        .modelContainer(Self.container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        NotificationCenter.default.post(
            name: .cloudKitShareAccepted,
            object: cloudKitShareMetadata
        )
    }
}
