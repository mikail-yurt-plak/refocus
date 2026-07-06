import Foundation
import SwiftData

/// CloudKit ile senkronlanan tekil kayıt.
/// Her alan nesnesi (seans, bağlam, profil) JSON payload olarak saklanır;
/// böylece mevcut Codable modeller ve view'lar hiç değişmeden kalır.
@Model
final class SyncedRecord {
    var recordID: String = ""
    var kind: String = ""
    var updatedAt: Date = Date(timeIntervalSince1970: 0)
    var payload: Data = Data()

    init(recordID: String, kind: String, updatedAt: Date, payload: Data) {
        self.recordID = recordID
        self.kind = kind
        self.updatedAt = updatedAt
        self.payload = payload
    }
}

/// iCloud (CloudKit özel veritabanı) üzerinden cihazlar arası senkron sağlayan depo.
/// - iCloud kullanılamıyorsa yerel SwiftData deposuna düşer;
///   o da yoksa sessizce devre dışı kalır ve uygulama UserDefaults ile çalışmaya devam eder.
/// - Çakışma çözümü: aynı recordID için en yeni `updatedAt` kazanır.
final class CloudStore {
    static let shared = CloudStore()

    enum Kind: String {
        case session
        case workContext
        case profile
    }

    private let container: ModelContainer?

    /// Senkron deposu kullanılabilir mi
    var isAvailable: Bool { container != nil }

    /// Depo iCloud destekli mi (false ise yalnızca yerel çalışıyor)
    private(set) var isCloudBacked = false

    private init() {
        let schema = Schema([SyncedRecord.self])
        if let cloud = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) {
            container = cloud
            isCloudBacked = true
        } else if let local = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)]
        ) {
            container = local
        } else {
            container = nil
        }
    }

    /// Her işlem için taze context: CloudKit'ten gelen uzak değişikliklerin
    /// bayat snapshot'larda gizli kalmasını önler
    private func makeContext() -> ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }

    // MARK: - CRUD

    /// Kaydı ekler veya günceller (aynı recordID için en yeni updatedAt kazanır)
    func upsert<T: Codable>(_ value: T, kind: Kind, id: String, updatedAt: Date = Date()) {
        guard let context = makeContext(),
              let payload = try? JSONEncoder().encode(value) else { return }

        let kindRaw = kind.rawValue
        let predicate = #Predicate<SyncedRecord> { $0.recordID == id && $0.kind == kindRaw }
        let existing = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []

        if let record = existing.first {
            guard updatedAt >= record.updatedAt else { return }
            record.payload = payload
            record.updatedAt = updatedAt
            // CloudKit unique constraint desteklemediği için oluşabilecek kopyaları temizle
            for duplicate in existing.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            context.insert(SyncedRecord(recordID: id, kind: kindRaw, updatedAt: updatedAt, payload: payload))
        }
        try? context.save()
    }

    /// Kaydı siler (silme diğer cihazlara da yayılır)
    func delete(kind: Kind, id: String) {
        guard let context = makeContext() else { return }
        let kindRaw = kind.rawValue
        let predicate = #Predicate<SyncedRecord> { $0.recordID == id && $0.kind == kindRaw }
        guard let records = try? context.fetch(FetchDescriptor(predicate: predicate)) else { return }
        for record in records {
            context.delete(record)
        }
        try? context.save()
    }

    /// Türdeki tüm kayıtları döndürür (kopyalar recordID bazında ayıklanır)
    func fetchAll<T: Codable>(_ type: T.Type, kind: Kind) -> [(id: String, value: T, updatedAt: Date)] {
        guard let context = makeContext() else { return [] }
        let kindRaw = kind.rawValue
        let predicate = #Predicate<SyncedRecord> { $0.kind == kindRaw }
        let records = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []

        var latest: [String: SyncedRecord] = [:]
        for record in records {
            if let current = latest[record.recordID], current.updatedAt >= record.updatedAt {
                continue
            }
            latest[record.recordID] = record
        }

        return latest.values.compactMap { record in
            guard let value = try? JSONDecoder().decode(T.self, from: record.payload) else { return nil }
            return (record.recordID, value, record.updatedAt)
        }
    }

    /// Türdeki en yeni tek kaydı döndürür (profil gibi tekil veriler için)
    func fetchLatest<T: Codable>(_ type: T.Type, kind: Kind) -> T? {
        fetchAll(type, kind: kind).max(by: { $0.updatedAt < $1.updatedAt })?.value
    }
}
