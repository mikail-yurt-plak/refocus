import Foundation
import Combine
import SwiftUI

/// Odak seanslarını yöneten ana sınıf
class SessionManager: ObservableObject {
    @Published var currentSession: FocusSession?
    @Published var timeRemaining: TimeInterval = 0
    @Published var isActive = false
    @Published var isBreak = false

    private var timer: Timer?
    private var sessionHistory: [FocusSession] = []
    private let interruptionTracker: InterruptionTracker

    /// Arka plana alınma zamanı (timer'ı yakalamak için)
    private var backgroundStartTime: Date?

    /// İzleme modunda düzensizlik tespiti için son app switch zamanları
    private var recentAppSwitches: [Date] = []

    init() {
        self.interruptionTracker = InterruptionTracker()
        loadSessionHistory()

        // Uygulama yaşam döngüsü bildirimlerini dinle
        setupLifecycleObservers()
    }

    // MARK: - Session Control

    /// Yeni seans başlat
    func startSession(method: FocusMethod, intent: SessionIntent = .mixed, workContext: WorkContext? = nil) {
        let session = FocusSession(method: method, intent: intent, workContext: workContext)
        currentSession = session
        timeRemaining = TimeInterval(method.focusDuration * 60)
        isActive = true
        isBreak = false

        // App switch geçmişini temizle
        recentAppSwitches = []

        // Timer'ı başlat
        startTimer()

        // Interruption tracker'ı başlat
        interruptionTracker.startTracking(for: session)

        // Seans bitiş bildirimi planla
        NotificationManager.shared.scheduleSessionEndNotification(
            for: method,
            in: timeRemaining
        )

        // Arkadaşlara "odakta" durumunu yayınla
        FriendSyncManager.shared.setPresence(focusing: true, since: session.startTime)

        // Debug: Bildirimleri listele
        print("🎯 Seans başladı: \(method.rawValue), niyet: \(intent.label), \(timeRemaining) saniye")
        NotificationManager.shared.listPendingNotifications()
    }

    /// Seansı duraklat
    func pauseSession() {
        guard var session = currentSession else { return }
        session.isPaused = true
        currentSession = session
        isActive = false
        stopTimer()

        // Bekleyen bildirimleri iptal et
        NotificationManager.shared.cancelAllPendingNotifications()
    }

    /// Seansı devam ettir
    func resumeSession() {
        guard var session = currentSession else { return }
        session.isPaused = false
        currentSession = session
        isActive = true
        startTimer()

        // Bildirim yeniden planla
        if isBreak {
            NotificationManager.shared.scheduleBreakEndNotification(in: timeRemaining)
        } else {
            NotificationManager.shared.scheduleSessionEndNotification(
                for: session.method,
                in: timeRemaining
            )
        }
    }

    /// Seansı dondur (geri bildirim için endTime'ı ayarla)
    /// Bu sayede totalFocusDuration değişmez
    func freezeSession() {
        guard var session = currentSession else { return }
        if session.endTime == nil {
            session.endTime = Date()
            currentSession = session
            print("❄️ Seans donduruldu - süre sabitlendi")
        }
    }

    /// Seansı bitir
    func endSession(feedback: SessionFeedback? = nil, sessionNote: String? = nil) {
        guard var session = currentSession else { return }

        // Eğer henüz dondurulmamışsa, şimdi dondur
        if session.endTime == nil {
            session.endTime = Date()
        }

        // Seansı tamamla (feedback ve not ekle, isActive = false)
        session.isActive = false
        session.feedback = feedback
        session.sessionNote = sessionNote

        // Interruption tracker'ı durdur
        interruptionTracker.stopTracking()

        // Geçmişe ekle
        sessionHistory.append(session)
        saveSessionHistory()
        CloudStore.shared.upsert(session, kind: .session, id: session.id.uuidString,
                                 updatedAt: session.endTime ?? Date())
        FriendSyncManager.shared.publishToday(sessions: sessionHistory)
        FriendSyncManager.shared.setPresence(focusing: false)

        // Bekleyen bildirimleri iptal et
        NotificationManager.shared.cancelAllPendingNotifications()

        // Temizle
        currentSession = nil
        isActive = false
        isBreak = false
        stopTimer()
    }

    /// Molayı başlat
    func startBreak() {
        guard let session = currentSession else { return }
        timeRemaining = TimeInterval(session.method.breakDuration * 60)
        isBreak = true
        isActive = true
        startTimer()

        // Mola bitiş bildirimi planla
        NotificationManager.shared.scheduleBreakEndNotification(in: timeRemaining)
    }

    /// Molayı atla
    func skipBreak() {
        isBreak = false
        isActive = false
        stopTimer()
    }

    // MARK: - Timer Management

    private func startTimer() {
        stopTimer() // Önceki timer'ı temizle

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.handleTimerComplete()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func handleTimerComplete() {
        stopTimer()

        if isBreak {
            // Mola bitti
            isBreak = false
            isActive = false
        } else {
            // Odak süresi bitti, mola başlat
            startBreak()
        }
    }

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        #endif
    }

    @objc private func appDidEnterBackground() {
        guard var session = currentSession else { return }

        // Arka plana alınma zamanını kaydet
        backgroundStartTime = Date()

        // Background event ekle
        let event = BackgroundEvent(timestamp: Date(), event: .didEnterBackground)
        session.addBackgroundEvent(event)
        currentSession = session

        // Aktif seans varsa ve mola değilse, nazik hatırlatma bildirimlerini planla
        // Ancak izleme modunda (watching) bildirim gönderme - kullanıcı video izliyor olabilir
        if isActive && !isBreak && session.intent != .watching {
            print("📴 Uygulama arka plana alındı - nazik hatırlatmalar planlanıyor")
            NotificationManager.shared.scheduleBackgroundNudgeNotifications()
        } else if session.intent == .watching {
            print("📺 İzleme modunda - arka plan bildirimi gönderilmiyor")
        }
    }

    @objc private func appWillEnterForeground() {
        guard var session = currentSession else { return }

        // Arka plan bildirimlerini iptal et (kullanıcı döndü)
        NotificationManager.shared.cancelBackgroundNudgeNotifications()
        print("📱 Uygulama ön plana döndü - hatırlatmalar iptal edildi")

        // App switch'i kaydet (düzensizlik tespiti için)
        let now = Date()
        recentAppSwitches.append(now)

        // Eski switch'leri temizle (time window dışındakileri)
        let timeWindow = SessionIntent.watchingModeTimeWindow
        recentAppSwitches = recentAppSwitches.filter { now.timeIntervalSince($0) < timeWindow }

        // Arka planda geçen süreyi hesapla
        if let startTime = backgroundStartTime {
            let elapsedTime = now.timeIntervalSince(startTime)

            // Timer'ı güncelle - geçen süreyi düş
            if isActive {
                timeRemaining = max(0, timeRemaining - elapsedTime)

                // Eğer süre bittiyse timer'ı tamamla
                if timeRemaining <= 0 {
                    handleTimerComplete()
                }
            }

            // Bölünme kaydı - niyete göre farklı mantık
            let shouldRecordInterruption = checkIfShouldRecordInterruption(
                intent: session.intent,
                elapsedTime: elapsedTime
            )

            if shouldRecordInterruption {
                let interruption = Interruption(startTime: startTime, endTime: now)
                session.addInterruption(interruption)
                print("⚠️ Bölünme kaydedildi: \(Int(elapsedTime)) saniye (niyet: \(session.intent.shortLabel))")
            }

            backgroundStartTime = nil
        }

        // Foreground event ekle
        let event = BackgroundEvent(timestamp: now, event: .willEnterForeground)
        session.addBackgroundEvent(event)
        currentSession = session
    }

    /// Niyete göre bölünme kaydedilmeli mi?
    private func checkIfShouldRecordInterruption(intent: SessionIntent, elapsedTime: TimeInterval) -> Bool {
        switch intent {
        case .reading:
            // Okuma modunda: threshold süresinden uzun = bölünme
            return elapsedTime > intent.interruptionThreshold

        case .watching:
            // İzleme modunda: süre değil, düzensizlik önemli
            // Çok sık app switch = bölünme sinyali
            let switchCount = recentAppSwitches.count
            let isIrregular = switchCount >= SessionIntent.watchingModeAppSwitchThreshold
            if isIrregular {
                print("📊 İzleme modunda düzensizlik tespit edildi: \(switchCount) switch son 2 dakikada")
            }
            return isIrregular

        case .mixed:
            // Karışık modda: daha uzun threshold
            return elapsedTime > intent.interruptionThreshold
        }
    }

    // MARK: - Data Persistence

    private func saveSessionHistory() {
        if let encoded = try? JSONEncoder().encode(sessionHistory) {
            UserDefaults.standard.set(encoded, forKey: "sessionHistory")
        }
    }

    private func loadSessionHistory() {
        if let data = UserDefaults.standard.data(forKey: "sessionHistory"),
           let history = try? JSONDecoder().decode([FocusSession].self, from: data) {
            sessionHistory = history
        }
        mergeSessionsFromCloud()
    }

    /// iCloud'dan gelen seansları yerel geçmişle birleştirir.
    /// Seanslar salt-eklemeli olduğu için id bazında birleşim güvenlidir;
    /// henüz buluta gitmemiş yerel seanslar da bu sırada yüklenir.
    func mergeSessionsFromCloud() {
        guard CloudStore.shared.isAvailable else { return }

        let cloudSessions = CloudStore.shared.fetchAll(FocusSession.self, kind: .session)
        let localIDs = Set(sessionHistory.map { $0.id })
        let cloudIDs = Set(cloudSessions.map { $0.value.id })

        // Bulutta olup yerelde olmayanları ekle
        let incoming = cloudSessions.map(\.value).filter { !localIDs.contains($0.id) }

        // Yerelde olup bulutta olmayanları buluta gönder (ilk taşıma dahil)
        for session in sessionHistory where !cloudIDs.contains(session.id) {
            CloudStore.shared.upsert(session, kind: .session, id: session.id.uuidString,
                                     updatedAt: session.endTime ?? session.startTime)
        }

        guard !incoming.isEmpty else { return }
        objectWillChange.send()
        sessionHistory.append(contentsOf: incoming)
        sessionHistory.sort { $0.startTime < $1.startTime }
        saveSessionHistory()
    }

    // MARK: - Session History Access

    func getTodaysSessions() -> [FocusSession] {
        sessionHistory.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    func getDailySummary(for date: Date) -> DailySummary? {
        let sessions = sessionHistory.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }
        guard !sessions.isEmpty else { return nil }
        return DailySummary(date: date, sessions: sessions)
    }

    func getAllSessions() -> [FocusSession] {
        sessionHistory
    }
}

/// Timer formatları için yardımcı extension
extension TimeInterval {
    /// "25:00" formatında string
    var formattedTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// "25 dk" formatında string
    var shortFormat: String {
        let minutes = Int(self) / 60
        return "\(minutes) dk"
    }
}
