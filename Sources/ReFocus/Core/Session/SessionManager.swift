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

    /// Aktif fazın (odak/mola) duvar saatine göre bitiş anı.
    /// Kalan süre her zaman bu tarihten hesaplanır; timer yalnızca ekranı
    /// tazeler. Uygulama askıya alınsa/öldürülse bile süre doğru kalır.
    private var phaseEndDate: Date?

    /// Duraklatma anında kalan süre (devamda yeniden çapalanır)
    private var pausedRemaining: TimeInterval?

    /// Arka plana alınma zamanı (timer'ı yakalamak için)
    private var backgroundStartTime: Date?

    /// Bu arka plan dönemi ekran kilidiyle mi başladı?
    /// Telefonu kilitleyip bırakmak (kitaptan çalışma, ders sesi dinleme)
    /// dikkat dağınıklığı değildir — hiçbir modda kesinti sayılmaz.
    private var backgroundIsScreenLock = false

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
        IntentMemory.save(intent, for: workContext)
        let duration = TimeInterval(method.focusDuration * 60)
        timeRemaining = duration
        phaseEndDate = Date().addingTimeInterval(duration)
        pausedRemaining = nil
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

        // Kalan süreyi sabitle; bitiş çapası devamda yeniden kurulur
        pausedRemaining = max(0, phaseEndDate?.timeIntervalSinceNow ?? timeRemaining)
        timeRemaining = pausedRemaining ?? timeRemaining
        phaseEndDate = nil
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

        // Bitiş anını kalan süreyle yeniden çapala
        let remaining = pausedRemaining ?? timeRemaining
        timeRemaining = remaining
        phaseEndDate = Date().addingTimeInterval(remaining)
        pausedRemaining = nil
        startTimer()

        // Bildirim yeniden planla
        if isBreak {
            NotificationManager.shared.scheduleBreakEndNotification(in: remaining)
        } else {
            NotificationManager.shared.scheduleSessionEndNotification(
                for: session.method,
                in: remaining
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
        phaseEndDate = nil
        pausedRemaining = nil
        stopTimer()
    }

    /// Molayı başlat
    /// - Parameter anchor: molanın başlangıç anı; odak süresi arka plandayken
    ///   bittiyse gerçek bitiş anından başlatılır ki mola da doğru işlesin
    func startBreak(from anchor: Date = Date()) {
        guard let session = currentSession else { return }
        let duration = TimeInterval(session.method.breakDuration * 60)
        let endDate = anchor.addingTimeInterval(duration)
        phaseEndDate = endDate
        timeRemaining = max(0, endDate.timeIntervalSinceNow)
        isBreak = true
        isActive = true
        startTimer()

        // Mola bitiş bildirimi planla (mola zaten geçmişte bitmediyse)
        if timeRemaining > 0 {
            NotificationManager.shared.scheduleBreakEndNotification(in: timeRemaining)
        }
    }

    /// Molayı atla
    func skipBreak() {
        isBreak = false
        isActive = false
        phaseEndDate = nil
        stopTimer()
    }

    #if DEBUG
    /// Vitrin modu: ekran görüntüsü için yan etkisiz (bildirim/presence yok)
    /// sahte bir seans başlatır
    func startDemoSession(remaining: TimeInterval) {
        guard currentSession == nil else { return }
        currentSession = FocusSession(
            method: .pomodoro,
            intent: .mixed,
            workContext: WorkContext.suggestions.first
        )
        isActive = true
        isBreak = false
        phaseEndDate = Date().addingTimeInterval(remaining)
        timeRemaining = remaining
        startTimer()
    }
    #endif

    /// Watch köprüsü için aktif fazın bitiş anı (salt okunur)
    var phaseEndDateForWatch: Date? { phaseEndDate }

    // MARK: - Timer Management

    private func startTimer() {
        stopTimer() // Önceki timer'ı temizle

        updateTimeRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateTimeRemaining()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Kalan süreyi duvar saatinden yeniden hesaplar.
    /// Timer yalnızca bunu tetikler; süre hiçbir zaman "azaltılarak" tutulmaz.
    private func updateTimeRemaining() {
        guard let endDate = phaseEndDate else { return }

        let remaining = endDate.timeIntervalSinceNow
        if remaining > 0 {
            timeRemaining = remaining.rounded(.up)
        } else {
            timeRemaining = 0
            handleTimerComplete(phaseEndedAt: endDate)
        }
    }

    private func handleTimerComplete(phaseEndedAt: Date) {
        stopTimer()
        phaseEndDate = nil

        if isBreak {
            // Mola bitti
            isBreak = false
            isActive = false
        } else {
            // Odak süresi bitti; mola gerçek bitiş anından başlar
            // (arka planda geçen süre molaya da doğru yansır)
            startBreak(from: phaseEndedAt)
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

        // Ekran kilidi sinyali: cihaz kilitlenince tetiklenir (uygulama
        // değiştirmede tetiklenmez) — kilit ile app switch'i böyle ayırırız
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceDidLock),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
        #endif
    }

    #if os(iOS)
    @objc private func deviceDidLock() {
        guard currentSession != nil else { return }
        backgroundIsScreenLock = true

        // Kilitli telefon = odak; dürtme bildirimi anlamsız olur
        NotificationManager.shared.cancelBackgroundNudgeNotifications()
        print("🔒 Ekran kilitlendi - bu dönem kesinti sayılmayacak")
    }
    #endif

    @objc private func appDidEnterBackground() {
        guard var session = currentSession else { return }

        // Arka plana alınma zamanını kaydet
        backgroundStartTime = Date()

        // Background event ekle
        let event = BackgroundEvent(timestamp: Date(), event: .didEnterBackground)
        session.addBackgroundEvent(event)
        currentSession = session

        // Aktif seans varsa ve mola değilse, nazik hatırlatma bildirimlerini planla
        // İstisnalar: izleme modu (video izliyor olabilir) ve ekran kilidi
        // (kitaptan çalışıyor olabilir — kilit sinyali bazen bu çağrıdan
        // önce gelir, o durumda hiç planlama)
        if isActive && !isBreak && session.intent != .watching && !backgroundIsScreenLock {
            print("📴 Uygulama arka plana alındı - nazik hatırlatmalar planlanıyor")
            NotificationManager.shared.scheduleBackgroundNudgeNotifications()
        }
    }

    @objc private func appWillEnterForeground() {
        // Sayacı duvar saatine göre hemen düzelt; faz arka plandayken
        // bittiyse geçişleri (mola/bitiş) burada tetiklenir
        updateTimeRemaining()

        guard var session = currentSession else { return }

        // Arka plan bildirimlerini iptal et (kullanıcı döndü)
        NotificationManager.shared.cancelBackgroundNudgeNotifications()
        print("📱 Uygulama ön plana döndü - hatırlatmalar iptal edildi")

        let now = Date()
        let wasScreenLock = backgroundIsScreenLock
        backgroundIsScreenLock = false

        if wasScreenLock {
            // Ekran kilidiyle başlayan dönem: kesinti DEĞİL, app switch de
            // değil. Kitaptan çalışma / ders sesi dinleme odak sayılır.
            print("🔓 Kilitten dönüldü - kesinti sayılmadı")
            backgroundStartTime = nil
        } else {
            // App switch'i kaydet (düzensizlik tespiti için)
            recentAppSwitches.append(now)

            // Eski switch'leri temizle (time window dışındakileri)
            let timeWindow = SessionIntent.watchingModeTimeWindow
            recentAppSwitches = recentAppSwitches.filter { now.timeIntervalSince($0) < timeWindow }

            // Arka planda geçen süreyi hesapla
            // (kalan süre düzeltmesi yukarıda updateTimeRemaining ile yapıldı)
            if let startTime = backgroundStartTime {
                let elapsedTime = now.timeIntervalSince(startTime)

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
