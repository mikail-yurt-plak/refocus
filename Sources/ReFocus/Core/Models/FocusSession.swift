import Foundation

/// Seans niyeti - kullanıcının bu seansı nasıl kullanacağı
/// Bölünme algılama eşiklerini ve UX mesajlarını etkiler
enum SessionIntent: String, Codable, CaseIterable {
    case reading = "reading"      // 📖 Okuma / Yazma
    case watching = "watching"    // 🎥 İzleyerek Öğrenme
    case mixed = "mixed"          // 🧠 Karışık (varsayılan)

    var icon: String {
        switch self {
        case .reading: return "📖"
        case .watching: return "📺"
        case .mixed: return "🧠"
        }
    }

    var label: String {
        switch self {
        case .reading: return String(localized: "intent.label.reading")
        case .watching: return String(localized: "intent.label.watching")
        case .mixed: return String(localized: "intent.label.mixed")
        }
    }

    var shortLabel: String {
        switch self {
        case .reading: return String(localized: "intent.short.reading")
        case .watching: return String(localized: "intent.short.watching")
        case .mixed: return String(localized: "intent.short.mixed")
        }
    }

    /// Bölünme sayılması için minimum arka plan süresi (saniye).
    /// Ekran kilidi hiçbir modda bölünme sayılmaz; bu eşikler yalnızca
    /// başka uygulamaya geçişler için geçerlidir.
    var interruptionThreshold: TimeInterval {
        switch self {
        case .reading: return 30    // 30 saniye sonra bölünme
        case .watching: return -1   // Süre bazlı bölünme yok, sadece düzensizlik
        case .mixed: return 120     // Hızlı mesaj/arama cezasız; 2 dk üzeri kopuş sayılır
        }
    }

    /// İzleme modunda düzensizlik tespiti için eşikler
    /// 2 dakika içinde 5+ app switch = bölünme sinyali
    static let watchingModeAppSwitchThreshold = 5
    static let watchingModeTimeWindow: TimeInterval = 120 // 2 dakika
}

/// Kullanıcının niyet tercihini bağlam bazında hatırlar.
/// "Ders" bağlamında hep İzleme seçen kullanıcı bir daha seçmek zorunda
/// kalmaz — karar yükü bindirmeme ilkesinin gereği.
enum IntentMemory {
    private static let globalKey = "lastIntent.global"

    private static func key(for context: WorkContext?) -> String? {
        context.map { "lastIntent.\($0.id.uuidString)" }
    }

    static func save(_ intent: SessionIntent, for context: WorkContext?) {
        let defaults = UserDefaults.standard
        defaults.set(intent.rawValue, forKey: globalKey)
        if let contextKey = key(for: context) {
            defaults.set(intent.rawValue, forKey: contextKey)
        }
    }

    static func recall(for context: WorkContext?) -> SessionIntent {
        let defaults = UserDefaults.standard
        if let contextKey = key(for: context),
           let raw = defaults.string(forKey: contextKey),
           let intent = SessionIntent(rawValue: raw) {
            return intent
        }
        if let raw = defaults.string(forKey: globalKey),
           let intent = SessionIntent(rawValue: raw) {
            return intent
        }
        return .mixed
    }
}

/// Bir odak seansını temsil eder
struct FocusSession: Identifiable, Codable {
    let id: UUID
    let method: FocusMethod
    let intent: SessionIntent
    let workContext: WorkContext?  // Çalışma bağlamı (opsiyonel)
    let startTime: Date
    var endTime: Date?

    // Seans durumu
    var isActive: Bool
    var isBreak: Bool
    var isPaused: Bool

    // Bölünme takibi
    var interruptions: [Interruption]
    var backgroundEvents: [BackgroundEvent]

    // Geri bildirim
    var feedback: SessionFeedback?

    // Seans notu (zihinsel kapanış için)
    var sessionNote: String?

    init(method: FocusMethod, intent: SessionIntent = .mixed, workContext: WorkContext? = nil) {
        self.id = UUID()
        self.method = method
        self.intent = intent
        self.workContext = workContext
        self.startTime = Date()
        self.isActive = true
        self.isBreak = false
        self.isPaused = false
        self.interruptions = []
        self.backgroundEvents = []
    }

    /// Toplam odak süresi (saniye)
    var totalFocusDuration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime) - totalInterruptionDuration
    }

    /// Toplam bölünme süresi (saniye)
    var totalInterruptionDuration: TimeInterval {
        interruptions.reduce(0) { $0 + $1.duration }
    }

    /// Bölünme sayısı
    var interruptionCount: Int {
        interruptions.count
    }

    /// Odak akışı kalitesi (0.0 - 1.0)
    /// Hem tamamlama oranını hem de bölünme oranını hesaba katar
    /// - Tamamlama oranı: Planlanan sürenin ne kadarı yapıldı?
    /// - Akış sürekliliği: Yapılan sürenin ne kadarı gerçek odaktı?
    var focusFlowQuality: Double {
        guard totalFocusDuration > 0 else { return 0 }

        let plannedDuration = Double(method.focusDuration * 60)
        let actualDuration = totalFocusDuration + totalInterruptionDuration

        // Tamamlama oranı (maksimum %100)
        let completionRatio = min(1.0, actualDuration / plannedDuration)

        // Akış sürekliliği (bölünme olmadığında 1.0)
        let flowContinuity = totalFocusDuration / actualDuration

        // İkisinin çarpımı: hem tamamlamak hem de odaklı kalmak önemli
        return completionRatio * flowContinuity
    }

    /// Seansı bitir
    mutating func complete(feedback: SessionFeedback? = nil) {
        self.endTime = Date()
        self.isActive = false
        self.feedback = feedback
    }

    /// Bölünme ekle
    mutating func addInterruption(_ interruption: Interruption) {
        self.interruptions.append(interruption)
    }

    /// Arka plan eventi ekle
    mutating func addBackgroundEvent(_ event: BackgroundEvent) {
        self.backgroundEvents.append(event)
    }
}

/// Bölünme kaydı
struct Interruption: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    init(startTime: Date, endTime: Date) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// Arka plan event'i (uygulama minimize edildiğinde)
struct BackgroundEvent: Codable {
    let timestamp: Date
    let event: EventType

    enum EventType: String, Codable {
        case didEnterBackground
        case willEnterForeground
    }
}

/// Seans sonu geri bildirimi
struct SessionFeedback: Codable {
    let wasDifficult: Bool?
    let didStayFocused: Bool?
    let wasDurationAppropriate: Bool?
    let additionalNotes: String?

    /// Basit puanlama (1-5)
    var overallRating: Int {
        var rating = 3 // Neutral başlangıç

        if let focused = didStayFocused {
            rating += focused ? 1 : -1
        }

        if let difficult = wasDifficult {
            rating += difficult ? -1 : 1
        }

        if let appropriate = wasDurationAppropriate {
            rating += appropriate ? 1 : -1
        }

        return max(1, min(5, rating))
    }
}

/// Günlük özet
struct DailySummary: Codable {
    let date: Date
    let sessions: [FocusSession]

    /// Toplam odak süresi (dakika)
    var totalFocusTime: Int {
        let totalSeconds = sessions.reduce(0) { $0 + $1.totalFocusDuration }
        return Int(totalSeconds / 60)
    }

    /// En çok kullanılan metod
    var mostUsedMethod: FocusMethod? {
        let methodCounts = Dictionary(grouping: sessions, by: { $0.method })
        return methodCounts.max(by: { $0.value.count < $1.value.count })?.key
    }

    /// Gün durumu
    var dayStatus: DayStatus {
        let avgQuality = sessions.reduce(0.0) { $0 + $1.focusFlowQuality } / Double(sessions.count)

        if avgQuality >= 0.8 {
            return .stable
        } else if avgQuality >= 0.5 {
            return .fluctuating
        } else {
            return .tough
        }
    }

    enum DayStatus: String, Codable {
        case stable = "stable"           // 🟢 Stabil
        case fluctuating = "fluctuating" // 🟡 Dalgalı
        case tough = "tough"             // 🔵 Zor Gün
    }
}
