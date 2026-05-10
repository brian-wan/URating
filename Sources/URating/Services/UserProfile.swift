import Foundation

@Observable
final class UserProfile {
    static let shared = UserProfile()
    private init() {}

    var name: String = UserDefaults.standard.string(forKey: "profile.name") ?? "" {
        didSet { UserDefaults.standard.set(name, forKey: "profile.name") }
    }

    var photoData: Data? = UserDefaults.standard.data(forKey: "profile.photo") {
        didSet { UserDefaults.standard.set(photoData, forKey: "profile.photo") }
    }

    // leagueID.uuidString → playerID.uuidString (device-local, per user)
    var playerIDMap: [String: String] =
        (UserDefaults.standard.dictionary(forKey: "profile.playerIDs") as? [String: String]) ?? [:] {
        didSet { UserDefaults.standard.set(playerIDMap, forKey: "profile.playerIDs") }
    }

    func myPlayerID(inLeague leagueID: UUID) -> UUID? {
        UUID(uuidString: playerIDMap[leagueID.uuidString] ?? "")
    }

    func setMyPlayer(_ playerID: UUID?, inLeague leagueID: UUID) {
        if let id = playerID { playerIDMap[leagueID.uuidString] = id.uuidString }
        else { playerIDMap.removeValue(forKey: leagueID.uuidString) }
    }

    var isSetUp: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
}
