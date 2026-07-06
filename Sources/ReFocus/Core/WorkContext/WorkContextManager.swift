import Foundation
import Combine

/// Çalışma bağlamlarını yöneten sınıf
/// Kullanıcının oluşturduğu context'leri persist eder
class WorkContextManager: ObservableObject {
    static let shared = WorkContextManager()

    @Published private(set) var contexts: [WorkContext] = []
    @Published var selectedContext: WorkContext?

    private let userDefaultsKey = "userWorkContexts"
    private let lastSelectedKey = "lastSelectedWorkContext"
    private let updatedAtKey = "userWorkContextsUpdatedAt"
    /// Tüm bağlamlar tek kayıt olarak senkronlanır: dizideki sıralama korunur
    /// ve silmeler doğal olarak diğer cihazlara yayılır
    private let cloudRecordID = "workContexts"

    init() {
        loadContexts()
        loadLastSelected()
    }

    // MARK: - Public Methods

    /// Tüm context'leri getir (varsayılan "Genel" her zaman dahil)
    func getAllContexts() -> [WorkContext] {
        var allContexts = [WorkContext.general]
        allContexts.append(contentsOf: contexts.filter { !$0.isDefault })
        return allContexts
    }

    /// Yeni context ekle
    func addContext(_ context: WorkContext) {
        // Aynı isimde context var mı kontrol et
        guard !contexts.contains(where: { $0.name.lowercased() == context.name.lowercased() }) else {
            return
        }
        contexts.append(context)
        saveContexts()
    }

    /// Context güncelle
    func updateContext(_ context: WorkContext) {
        if let index = contexts.firstIndex(where: { $0.id == context.id }) {
            contexts[index] = context
            saveContexts()
        }
    }

    /// Context sil (varsayılan "Genel" silinemez)
    func deleteContext(_ context: WorkContext) {
        guard !context.isDefault else { return }
        contexts.removeAll { $0.id == context.id }
        saveContexts()

        // Eğer silinen context seçiliyse, "Genel"e dön
        if selectedContext?.id == context.id {
            selectedContext = .general
            saveLastSelected()
        }
    }

    /// Context seç
    func selectContext(_ context: WorkContext) {
        selectedContext = context
        saveLastSelected()
    }

    /// Önerilen context'leri toplu ekle (onboarding için)
    func addSuggestedContexts(_ contexts: [WorkContext]) {
        for context in contexts {
            addContext(context)
        }
    }

    /// Context var mı kontrol et
    func hasContext(named name: String) -> Bool {
        getAllContexts().contains { $0.name.lowercased() == name.lowercased() }
    }

    /// Context'leri yeniden sırala (drag & drop)
    func moveContexts(from source: IndexSet, to destination: Int) {
        // Sadece kullanıcı context'lerini sırala (varsayılan hariç)
        var userContexts = contexts.filter { !$0.isDefault }
        userContexts.move(fromOffsets: source, toOffset: destination)

        // Varsayılanları koru ve kullanıcı context'lerini güncelle
        contexts = userContexts
        saveContexts()
    }

    /// Context'leri belirli bir sıraya göre güncelle
    func reorderContexts(_ newOrder: [WorkContext]) {
        contexts = newOrder.filter { !$0.isDefault }
        saveContexts()
    }

    // MARK: - Persistence

    private func saveContexts() {
        let now = Date()
        if let encoded = try? JSONEncoder().encode(contexts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            UserDefaults.standard.set(now, forKey: updatedAtKey)
        }
        CloudStore.shared.upsert(contexts, kind: .workContext, id: cloudRecordID, updatedAt: now)
    }

    private func loadContexts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([WorkContext].self, from: data) {
            contexts = decoded
        }
        mergeFromCloud()
    }

    /// iCloud'daki bağlam listesiyle yereli birleştirir; daha yeni olan kazanır
    func mergeFromCloud() {
        guard CloudStore.shared.isAvailable else { return }

        let localDate = UserDefaults.standard.object(forKey: updatedAtKey) as? Date ?? .distantPast
        let cloud = CloudStore.shared.fetchAll([WorkContext].self, kind: .workContext)
            .first { $0.id == cloudRecordID }

        if let cloud, cloud.updatedAt > localDate {
            contexts = cloud.value
            if let encoded = try? JSONEncoder().encode(contexts) {
                UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
                UserDefaults.standard.set(cloud.updatedAt, forKey: updatedAtKey)
            }
            // Seçili bağlam artık yoksa "Genel"e dön
            if let selected = selectedContext,
               !getAllContexts().contains(where: { $0.id == selected.id }) {
                selectedContext = .general
                saveLastSelected()
            }
        } else if cloud == nil, !contexts.isEmpty {
            // İlk taşıma: yerel veriyi buluta gönder
            CloudStore.shared.upsert(contexts, kind: .workContext, id: cloudRecordID, updatedAt: localDate)
        }
    }

    private func saveLastSelected() {
        if let context = selectedContext,
           let encoded = try? JSONEncoder().encode(context) {
            UserDefaults.standard.set(encoded, forKey: lastSelectedKey)
        }
    }

    private func loadLastSelected() {
        if let data = UserDefaults.standard.data(forKey: lastSelectedKey),
           let decoded = try? JSONDecoder().decode(WorkContext.self, from: data) {
            // Context hala mevcut mu kontrol et
            if getAllContexts().contains(where: { $0.id == decoded.id }) {
                selectedContext = decoded
            } else {
                selectedContext = .general
            }
        } else {
            selectedContext = .general
        }
    }

    // MARK: - Reset (test için)

    func resetToDefaults() {
        contexts = []
        selectedContext = .general
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: lastSelectedKey)
    }
}
