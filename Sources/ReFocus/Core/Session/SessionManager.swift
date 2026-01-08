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

    init() {
        self.interruptionTracker = InterruptionTracker()
        loadSessionHistory()

        // Uygulama yaşam döngüsü bildirimlerini dinle
        setupLifecycleObservers()
    }

    // MARK: - Session Control

    /// Yeni seans başlat
    func startSession(method: FocusMethod) {
        let session = FocusSession(method: method)
        currentSession = session
        timeRemaining = TimeInterval(method.focusDuration * 60)
        isActive = true
        isBreak = false

        // Timer'ı başlat
        startTimer()

        // Interruption tracker'ı başlat
        interruptionTracker.startTracking(for: session)

        // Seans bitiş bildirimi planla
        NotificationManager.shared.scheduleSessionEndNotification(
            for: method,
            in: timeRemaining
        )

        // Debug: Bildirimleri listele
        print("🎯 Seans başladı: \(method.rawValue), \(timeRemaining) saniye")
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

    /// Seansı bitir
    func endSession(feedback: SessionFeedback? = nil) {
        guard var session = currentSession else { return }

        // Seansı tamamla
        session.complete(feedback: feedback)

        // Interruption tracker'ı durdur
        interruptionTracker.stopTracking()

        // Geçmişe ekle
        sessionHistory.append(session)
        saveSessionHistory()

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
        guard let session = currentSession else { return }
        interruptionTracker.recordBackgroundEvent(session: session, entering: true)

        // Aktif seans varsa ve mola değilse, nazik hatırlatma bildirimlerini planla
        if isActive && !isBreak {
            print("📴 Uygulama arka plana alındı - nazik hatırlatmalar planlanıyor")
            NotificationManager.shared.scheduleBackgroundNudgeNotifications()
        }
    }

    @objc private func appWillEnterForeground() {
        guard let session = currentSession else { return }
        interruptionTracker.recordBackgroundEvent(session: session, entering: false)

        // Arka plan bildirimlerini iptal et (kullanıcı döndü)
        NotificationManager.shared.cancelBackgroundNudgeNotifications()
        print("📱 Uygulama ön plana döndü - hatırlatmalar iptal edildi")
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
