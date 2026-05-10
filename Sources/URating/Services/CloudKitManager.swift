import CloudKit
import SwiftData
import Foundation

enum CloudKitError: LocalizedError {
    case accountUnavailable
    case zoneSaveFailed
    case noLeagueRecord

    var errorDescription: String? {
        switch self {
        case .accountUnavailable: return "iCloud is not available. Sign in to iCloud in Settings."
        case .zoneSaveFailed:    return "Failed to create CloudKit zone."
        case .noLeagueRecord:    return "Could not find the shared league's data."
        }
    }
}

extension Notification.Name {
    static let cloudKitShareAccepted = Notification.Name("cloudKitShareAccepted")
}

@Observable
final class CloudKitManager {
    static let shared = CloudKitManager()
    private init() {}

    let ckContainer = CKContainer(identifier: "iCloud.com.brianwan.URating")
    private var privateDB: CKDatabase { ckContainer.privateCloudDatabase }
    private var sharedDB: CKDatabase  { ckContainer.sharedCloudDatabase }

    var isAccountAvailable = false
    var isBusy = false
    var lastError: String?

    // MARK: - Setup

    func setup() async {
        do {
            let status = try await ckContainer.accountStatus()
            isAccountAvailable = (status == .available)
        } catch {
            isAccountAvailable = false
        }
    }

    // MARK: - Share creation (called by UICloudSharingController's preparation handler)

    func prepareShare(for league: League, completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        Task {
            isBusy = true
            defer { isBusy = false }
            do {
                let share = try await createShare(for: league)
                completion(share, ckContainer, nil)
            } catch {
                lastError = error.localizedDescription
                completion(nil, nil, error)
            }
        }
    }

    private func createShare(for league: League) async throws -> CKShare {
        let zoneName = "league-\(league.id.uuidString)"
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

        let (zoneSaveResults, _) = try await privateDB.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        guard case .success(let zone) = zoneSaveResults[zoneID] else { throw CloudKitError.zoneSaveFailed }

        // Root record for the league
        let leagueRecordID = CKRecord.ID(recordName: "League-\(league.id.uuidString)", zoneID: zone.zoneID)
        let leagueRecord   = CKRecord(recordType: "URLeague", recordID: leagueRecordID)
        leagueRecord["name"]     = league.name
        leagueRecord["sport"]    = league.sport
        leagueRecord["colorHex"] = league.colorHex
        leagueRecord["leagueID"] = league.id.uuidString

        var records: [CKRecord] = [leagueRecord]
        for membership in league.memberships {
            guard let player = membership.player else { continue }
            records.append(playerRecord(player, zoneID: zone.zoneID))
            records.append(membershipRecord(membership, player: player, zoneID: zone.zoneID))
        }
        for match in league.matches {
            records.append(matchRecord(match, zoneID: zone.zoneID))
        }

        let shareID = CKRecord.ID(recordName: "share-\(league.id.uuidString)", zoneID: zone.zoneID)
        let share = CKShare(rootRecord: leagueRecord, shareID: shareID)
        share[CKShare.SystemFieldKey.title] = league.name as CKRecordValue
        share.publicPermission = CKShare.Participant.Permission.none
        records.append(share)

        _ = try await privateDB.modifyRecords(saving: records, deleting: [])

        league.cloudZoneName      = zoneName
        league.cloudZoneOwnerName = CKCurrentUserDefaultName
        league.cloudRecordName    = leagueRecordID.recordName
        league.isShared           = true
        league.isOwned            = true

        return share
    }

    // MARK: - Accept share

    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        try await ckContainer.accept(metadata)
    }

    // MARK: - Import shared league into local SwiftData store

    func importSharedLeague(_ metadata: CKShare.Metadata, into context: ModelContext) async throws -> League {
        let zoneID    = metadata.share.recordID.zoneID
        let ownerName = zoneID.ownerName

        var allRecords: [CKRecord] = []
        for type in ["URLeague", "URPlayer", "URMembership", "URMatch"] {
            let query = CKQuery(recordType: type, predicate: NSPredicate(value: true))
            let (matchResults, _) = try await sharedDB.records(matching: query, inZoneWith: zoneID)
            allRecords += matchResults.compactMap { try? $0.1.get() }
        }

        guard let lr = allRecords.first(where: { $0.recordType == "URLeague" }) else {
            throw CloudKitError.noLeagueRecord
        }

        let league = League(
            name:     lr["name"]     as? String ?? "",
            sport:    lr["sport"]    as? String ?? "",
            colorHex: lr["colorHex"] as? String ?? "#3498DB"
        )
        league.cloudZoneName      = zoneID.zoneName
        league.cloudZoneOwnerName = ownerName
        league.cloudRecordName    = lr.recordID.recordName
        league.isShared           = true
        league.isOwned            = false
        context.insert(league)

        var playerMap: [String: Player] = [:]
        for r in allRecords where r.recordType == "URPlayer" {
            guard let pid = r["playerID"] as? String else { continue }
            let player = Player(name: r["name"] as? String ?? "", colorHex: r["colorHex"] as? String ?? "#3498DB")
            context.insert(player)
            playerMap[pid] = player
        }

        for r in allRecords where r.recordType == "URMembership" {
            guard let pid = r["playerID"] as? String, let player = playerMap[pid] else { continue }
            let m = LeagueMembership(player: player, league: league)
            m.rating  = r["rating"]  as? Double ?? 1000
            m.wins    = r["wins"]    as? Int    ?? 0
            m.losses  = r["losses"]  as? Int    ?? 0
            context.insert(m)
        }

        let matchRecords = allRecords
            .filter { $0.recordType == "URMatch" }
            .sorted { ($0["date"] as? Date ?? .distantPast) < ($1["date"] as? Date ?? .distantPast) }

        for r in matchRecords {
            guard let p1id = r["player1ID"] as? String, let p1 = playerMap[p1id],
                  let p2id = r["player2ID"] as? String, let p2 = playerMap[p2id] else { continue }
            let match = Match(
                league: league, player1: p1, player2: p2,
                player1Won: (r["player1Won"] as? Int ?? 1) == 1,
                score: r["score"] as? String ?? "",
                player1RatingBefore: r["p1RatingBefore"] as? Double ?? 1000,
                player2RatingBefore: r["p2RatingBefore"] as? Double ?? 1000,
                player1RatingAfter:  r["p1RatingAfter"]  as? Double ?? 1000,
                player2RatingAfter:  r["p2RatingAfter"]  as? Double ?? 1000
            )
            match.date            = r["date"] as? Date ?? Date()
            match.cloudRecordName = r.recordID.recordName
            context.insert(match)
        }

        return league
    }

    // MARK: - Push a new match to the shared zone

    func pushMatch(_ match: Match, league: League) async throws {
        guard let zoneName  = league.cloudZoneName,
              let ownerName = league.cloudZoneOwnerName else { return }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let db     = league.isOwned ? privateDB : sharedDB
        let record = matchRecord(match, zoneID: zoneID)
        try await db.save(record)
        match.cloudRecordName = record.recordID.recordName
    }

    // MARK: - Pull new matches from the shared zone

    func refreshMatches(for league: League, into context: ModelContext) async throws {
        guard let zoneName  = league.cloudZoneName,
              let ownerName = league.cloudZoneOwnerName else { return }

        isBusy = true
        defer { isBusy = false }

        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let db     = league.isOwned ? privateDB : sharedDB

        let query = CKQuery(recordType: "URMatch", predicate: NSPredicate(value: true))
        let (matchResults, _) = try await db.records(matching: query, inZoneWith: zoneID)
        let cloudRecords  = matchResults.compactMap { try? $0.1.get() }

        let existingIDs = Set(league.matches.compactMap { $0.cloudRecordName })
        let newRecords  = cloudRecords
            .filter { !existingIDs.contains($0.recordID.recordName) }
            .sorted  { ($0["date"] as? Date ?? .distantPast) < ($1["date"] as? Date ?? .distantPast) }

        var playerMap: [String: Player] = [:]
        for m in league.memberships { if let p = m.player { playerMap[p.id.uuidString] = p } }

        for r in newRecords {
            guard let p1id = r["player1ID"] as? String, let p1 = playerMap[p1id],
                  let p2id = r["player2ID"] as? String, let p2 = playerMap[p2id] else { continue }

            let p1Won    = (r["player1Won"] as? Int ?? 1) == 1
            let winnerID = p1Won ? p1id : p2id
            let loserID  = p1Won ? p2id : p1id

            let match = Match(
                league: league, player1: p1, player2: p2, player1Won: p1Won,
                score: r["score"] as? String ?? "",
                player1RatingBefore: r["p1RatingBefore"] as? Double ?? 1000,
                player2RatingBefore: r["p2RatingBefore"] as? Double ?? 1000,
                player1RatingAfter:  r["p1RatingAfter"]  as? Double ?? 1000,
                player2RatingAfter:  r["p2RatingAfter"]  as? Double ?? 1000
            )
            match.date            = r["date"] as? Date ?? Date()
            match.cloudRecordName = r.recordID.recordName
            context.insert(match)

            // Update membership stats and rating from stored snapshots
            if let wm = league.memberships.first(where: { $0.player?.id.uuidString == winnerID }) {
                wm.rating = p1Won ? (r["p1RatingAfter"] as? Double ?? wm.rating) : (r["p2RatingAfter"] as? Double ?? wm.rating)
                wm.wins  += 1
            }
            if let lm = league.memberships.first(where: { $0.player?.id.uuidString == loserID }) {
                lm.rating = p1Won ? (r["p2RatingAfter"] as? Double ?? lm.rating) : (r["p1RatingAfter"] as? Double ?? lm.rating)
                lm.losses += 1
            }
        }
    }

    // MARK: - Record builders

    private func playerRecord(_ player: Player, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(recordType: "URPlayer", recordID: .init(recordName: "Player-\(player.id.uuidString)", zoneID: zoneID))
        r["name"]     = player.name
        r["colorHex"] = player.colorHex
        r["playerID"] = player.id.uuidString
        return r
    }

    private func membershipRecord(_ membership: LeagueMembership, player: Player, zoneID: CKRecordZone.ID) -> CKRecord {
        let r = CKRecord(recordType: "URMembership", recordID: .init(recordName: "Membership-\(membership.id.uuidString)", zoneID: zoneID))
        r["playerID"]     = player.id.uuidString
        r["membershipID"] = membership.id.uuidString
        r["rating"]       = membership.rating
        r["wins"]         = membership.wins
        r["losses"]       = membership.losses
        return r
    }

    private func matchRecord(_ match: Match, zoneID: CKRecordZone.ID) -> CKRecord {
        let name = match.cloudRecordName ?? "Match-\(match.id.uuidString)"
        let r = CKRecord(recordType: "URMatch", recordID: .init(recordName: name, zoneID: zoneID))
        r["matchID"]      = match.id.uuidString
        r["player1ID"]    = match.player1?.id.uuidString ?? ""
        r["player2ID"]    = match.player2?.id.uuidString ?? ""
        r["player1Won"]   = match.player1Won ? 1 : 0
        r["score"]        = match.score
        r["date"]         = match.date
        r["p1RatingBefore"] = match.player1RatingBefore
        r["p1RatingAfter"]  = match.player1RatingAfter
        r["p2RatingBefore"] = match.player2RatingBefore
        r["p2RatingAfter"]  = match.player2RatingAfter
        return r
    }
}
