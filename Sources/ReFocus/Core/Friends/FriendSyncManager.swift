import Foundation
import CloudKit
import Combine
import UserNotifications

// MARK: - Arkadaş Veri Modelleri

/// Bir arkadaşın tek gününün özeti
struct FriendDayActivity: Identifiable {
    let date: Date
    let totalMinutes: Int
    let sessionCount: Int
    let averageQuality: Double
    /// Bağlam adı → dakika (sıralı)
    let contexts: [(name: String, minutes: Int)]

    var id: Date { date }
}

/// Paylaşım bölgesinden okunan bir arkadaş
struct FriendSummary: Identifiable {
    let zoneID: CKRecordZone.ID
    let displayName: String
    /// Son günler, en yeni önce
    let days: [FriendDayActivity]
    /// Şu an bir odak seansında mı
    let isFocusing: Bool
    /// Odaklanmaya başladığı an (isFocusing true iken)
    let focusingSince: Date?

    var id: String { "\(zoneID.ownerName)|\(zoneID.zoneName)" }

    var today: FriendDayActivity? {
        days.first { Calendar.current.isDateInToday($0.date) }
    }

    var weekTotalMinutes: Int {
        days.reduce(0) { $0 + $1.totalMinutes }
    }
}

// MARK: - FriendSyncManager

/// Arkadaşlarla çalışma özeti paylaşımını yöneten sınıf.
///
/// Mimari: her kullanıcı kendi iCloud özel veritabanında bir "paylaşım bölgesi"
/// tutar ve günlük özetlerini oraya yazar. Bölge, CKShare ile davet edilen
/// arkadaşlara salt-okunur açılır; arkadaşların bölgeleri de kullanıcının
/// paylaşılan veritabanında görünür. Sunucu yoktur — veri yalnızca
/// katılımcıların iCloud hesapları arasında dolaşır.
final class FriendSyncManager: ObservableObject {
    static let shared = FriendSyncManager()

    /// Paylaşılan veritabanından okunan arkadaşlar
    @Published private(set) var friends: [FriendSummary] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var iCloudAvailable = true

    /// Kullanıcının arkadaşlarına görünen adı; boşsa özellik henüz kurulmamıştır
    @Published var displayName: String {
        didSet {
            UserDefaults.standard.set(displayName, forKey: Self.displayNameKey)
        }
    }

    var isEnabled: Bool { !displayName.trimmingCharacters(in: .whitespaces).isEmpty }

    private static let displayNameKey = "friendDisplayName"
    private static let zoneName = "ReFocusFriendZone"
    private static let containerID = "iCloud.com.mikailyurt.refocus"
    private static let historyDayCount = 7

    private let container = CKContainer(identifier: FriendSyncManager.containerID)
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    private init() {
        displayName = UserDefaults.standard.string(forKey: Self.displayNameKey) ?? ""
    }

    // MARK: - Davet (paylaşım linki)

    /// Kendi paylaşım bölgesini hazırlar ve davet linkini döndürür.
    /// Bölge/paylaşım zaten varsa mevcut link döner.
    func prepareInviteURL() async throws -> URL {
        // 1. Bölgenin var olduğundan emin ol
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])

        // 2. Profil kaydını güncelle (davet edilen kişi ismi görebilsin)
        try await saveProfileRecord()

        // 3. Mevcut bölge paylaşımı var mı?
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        if let existing = try? await privateDB.record(for: shareID) as? CKShare,
           let url = existing.url {
            return url
        }

        // 4. Yoksa oluştur: linki alan herkes salt-okunur katılabilir
        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = "ReFocus" as CKRecordValue

        let result = try await privateDB.modifyRecords(saving: [share], deleting: [])
        for (_, saveResult) in result.saveResults {
            if case .success(let record) = saveResult,
               let saved = record as? CKShare, let url = saved.url {
                return url
            }
        }
        throw CKError(.internalError)
    }

    /// Davet linkine tıklayan tarafta paylaşımı kabul eder
    func acceptShare(metadata: CKShare.Metadata) {
        Task {
            _ = try? await container.accept(metadata)
            await refreshFriends()
        }
    }

    // MARK: - Varlık (şu an odakta) ve bildirimler

    /// Seans başlarken/biterken çağrılır: paylaşım bölgesine varlık durumu yazar.
    /// Arkadaşların cihazları bu değişiklikle sessiz push alır ve bildirim gösterir.
    func setPresence(focusing: Bool, since: Date = Date()) {
        guard isEnabled else { return }
        Task {
            let zones = (try? await privateDB.allRecordZones()) ?? []
            guard zones.contains(where: { $0.zoneID.zoneName == Self.zoneName }) else { return }

            let record = CKRecord(
                recordType: "Presence",
                recordID: CKRecord.ID(recordName: "presence", zoneID: zoneID)
            )
            record["state"] = (focusing ? "focusing" : "idle") as CKRecordValue
            record["since"] = since as CKRecordValue
            _ = try? await privateDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        }
    }

    /// Paylaşılan veritabanı değişikliklerinde sessiz push almak için abonelik kurar (bir kez)
    private func ensureSubscription() async {
        let flagKey = "friendPushSubscribed"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let subscription = CKDatabaseSubscription(subscriptionID: "shared-db-changes")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        if (try? await sharedDB.modifySubscriptions(saving: [subscription], deleting: [])) != nil {
            UserDefaults.standard.set(true, forKey: flagKey)
        }
    }

    /// Sessiz push geldiğinde çağrılır: arkadaşları tazele, yeni başlayan varsa bildir
    func handleRemoteChange() async {
        guard isEnabled else { return }
        await refreshFriends()
        notifyNewlyStartedFriends()
    }

    /// Yeni odaklanmaya başlayan arkadaşlar için nazik bir yerel bildirim gösterir.
    /// Aynı seans için tekrar bildirim üretmez; bayat (30 dk+) başlangıçları atlar.
    private func notifyNewlyStartedFriends() {
        let store = UserDefaults.standard
        var notified = store.dictionary(forKey: "friendNotifiedStarts") as? [String: Double] ?? [:]

        for friend in friends {
            guard friend.isFocusing, let since = friend.focusingSince else { continue }
            guard Date().timeIntervalSince(since) < 30 * 60 else { continue }
            if let last = notified[friend.id], last >= since.timeIntervalSince1970 { continue }
            notified[friend.id] = since.timeIntervalSince1970

            let content = UNMutableNotificationContent()
            content.body = String(
                format: String(localized: "friends.notification.started"),
                friend.displayName
            )
            let request = UNNotificationRequest(
                identifier: "friendStart-\(friend.id)-\(Int(since.timeIntervalSince1970))",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
        store.set(notified, forKey: "friendNotifiedStarts")
    }

    /// Arkadaşı listeden çıkar (paylaşımdan ayrıl: bölge paylaşılan DB'den silinir)
    func removeFriend(_ friend: FriendSummary) async {
        _ = try? await sharedDB.modifyRecordZones(saving: [], deleting: [friend.zoneID])
        await MainActor.run {
            friends.removeAll { $0.id == friend.id }
        }
    }

    // MARK: - Kendi verini yayınla

    /// Bugünün özetini paylaşım bölgesine yazar.
    /// Paylaşım hiç kurulmamışsa (davet gönderilmemişse) sessizce çıkar.
    func publishToday(sessions: [FocusSession]) {
        guard isEnabled else { return }
        Task { try? await publish(sessions: sessions) }
    }

    private func publish(sessions: [FocusSession]) async throws {
        // Bölge yoksa davet de gönderilmemiştir; yayınlamaya gerek yok
        let zones = (try? await privateDB.allRecordZones()) ?? []
        guard zones.contains(where: { $0.zoneID.zoneName == Self.zoneName }) else { return }

        let todaysSessions = sessions.filter {
            Calendar.current.isDateInToday($0.startTime) && $0.endTime != nil
        }

        let generalName = String(localized: "workcontext.general")
        var contextMinutes: [String: Int] = [:]
        for session in todaysSessions {
            let name = session.workContext?.name ?? generalName
            contextMinutes[name, default: 0] += Int(session.totalFocusDuration / 60)
        }
        let detail = contextMinutes
            .sorted { $0.value > $1.value }
            .map { ["c": $0.key, "m": "\($0.value)"] }

        let totalMinutes = todaysSessions.reduce(0) { $0 + Int($1.totalFocusDuration / 60) }
        let avgQuality = todaysSessions.isEmpty ? 0
            : todaysSessions.reduce(0.0) { $0 + $1.focusFlowQuality } / Double(todaysSessions.count)

        let record = CKRecord(
            recordType: "DailyActivity",
            recordID: CKRecord.ID(recordName: Self.dayRecordName(for: Date()), zoneID: zoneID)
        )
        record["dateStart"] = Calendar.current.startOfDay(for: Date()) as CKRecordValue
        record["minutes"] = totalMinutes as CKRecordValue
        record["sessions"] = todaysSessions.count as CKRecordValue
        record["quality"] = avgQuality as CKRecordValue
        if let detailData = try? JSONEncoder().encode(detail),
           let detailString = String(data: detailData, encoding: .utf8) {
            record["detail"] = detailString as CKRecordValue
        }

        // .allKeys: kaydın tamamını üzerine yaz (tek yazar biziz)
        let operationResult = try await privateDB.modifyRecords(
            saving: [record], deleting: [], savePolicy: .allKeys
        )
        _ = operationResult

        try await saveProfileRecord()
    }

    private func saveProfileRecord() async throws {
        guard isEnabled else { return }
        let record = CKRecord(
            recordType: "SharedProfile",
            recordID: CKRecord.ID(recordName: "profile", zoneID: zoneID)
        )
        record["displayName"] = displayName as CKRecordValue
        _ = try await privateDB.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    // MARK: - Arkadaşları oku

    /// Paylaşılan veritabanındaki tüm arkadaş bölgelerini okur
    @MainActor
    func refreshFriends() async {
        guard isEnabled else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        guard let status = try? await container.accountStatus(), status == .available else {
            iCloudAvailable = false
            return
        }
        iCloudAvailable = true

        guard let zones = try? await sharedDB.allRecordZones() else { return }

        var result: [FriendSummary] = []
        for zone in zones {
            if let friend = await fetchFriend(in: zone.zoneID) {
                result.append(friend)
            }
        }
        friends = result.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }

        // Arkadaş varsa push aboneliğinin kurulu olduğundan emin ol
        if !friends.isEmpty {
            await ensureSubscription()
        }
    }

    /// Tek bir arkadaş bölgesinden profil + son günleri okur.
    /// Sorgu (CKQuery) yerine bilinen kayıt adları kullanılır — indeks gerektirmez.
    private func fetchFriend(in zoneID: CKRecordZone.ID) async -> FriendSummary? {
        var ids = [
            CKRecord.ID(recordName: "profile", zoneID: zoneID),
            CKRecord.ID(recordName: "presence", zoneID: zoneID)
        ]
        for offset in 0..<Self.historyDayCount {
            if let day = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                ids.append(CKRecord.ID(recordName: Self.dayRecordName(for: day), zoneID: zoneID))
            }
        }

        guard let results = try? await sharedDB.records(for: ids) else { return nil }

        var name = ""
        var days: [FriendDayActivity] = []
        var isFocusing = false
        var focusingSince: Date?

        for (recordID, recordResult) in results {
            guard case .success(let record) = recordResult else { continue }
            switch recordID.recordName {
            case "profile":
                name = record["displayName"] as? String ?? ""
            case "presence":
                let since = record["since"] as? Date
                // 12 saatten eski "odakta" kaydı bayattır (kapanmamış seans vb.)
                if record["state"] as? String == "focusing",
                   let since, Date().timeIntervalSince(since) < 12 * 3600 {
                    isFocusing = true
                    focusingSince = since
                }
            default:
                if record.recordType == "DailyActivity" {
                    days.append(Self.dayActivity(from: record))
                }
            }
        }

        guard !name.isEmpty else { return nil }
        return FriendSummary(
            zoneID: zoneID,
            displayName: name,
            days: days.sorted { $0.date > $1.date },
            isFocusing: isFocusing,
            focusingSince: focusingSince
        )
    }

    private static func dayActivity(from record: CKRecord) -> FriendDayActivity {
        var contexts: [(String, Int)] = []
        if let detailString = record["detail"] as? String,
           let data = detailString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) {
            contexts = decoded.compactMap { item in
                guard let name = item["c"], let minutes = Int(item["m"] ?? "") else { return nil }
                return (name, minutes)
            }
        }
        return FriendDayActivity(
            date: record["dateStart"] as? Date ?? .distantPast,
            totalMinutes: record["minutes"] as? Int ?? 0,
            sessionCount: record["sessions"] as? Int ?? 0,
            averageQuality: record["quality"] as? Double ?? 0,
            contexts: contexts
        )
    }

    private static func dayRecordName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        return "day-" + formatter.string(from: Calendar.current.startOfDay(for: date))
    }
}
