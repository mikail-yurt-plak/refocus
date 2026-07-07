#if os(iOS)
import Foundation
import Combine
import WatchConnectivity

/// iPhone tarafı Watch köprüsü.
/// Seans durumu değiştikçe saate anlık görüntü yayınlar (applicationContext)
/// ve saatten gelen başlat/bitir komutlarını SessionManager'a iletir.
final class PhoneWatchBridge: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchBridge()

    private weak var appState: AppState?
    private var cancellable: AnyCancellable?
    private var lastSnapshot: [String: String] = [:]

    private override init() {
        super.init()
    }

    func configure(appState: AppState) {
        guard WCSession.isSupported() else { return }
        self.appState = appState
        WCSession.default.delegate = self
        WCSession.default.activate()

        // timeRemaining her saniye değişir; yalnızca anlamlı durum
        // (başladı/bitti/faz değişti) farklıysa yayınla
        cancellable = appState.sessionManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pushStateIfChanged()
            }
        pushStateIfChanged()
    }

    private func recommendedMethod() -> FocusMethod {
        guard let appState else { return .pomodoro }
        let fallback = OnboardingAnswers(
            workType: .knowledgeWorker, struggleTime: .medium,
            hardestPart: .starting, phoneCheckingFrequency: .sometimes)
        return MethodSelectionEngine.selectMethod(
            for: appState.userProfile ?? UserProfile(onboardingAnswers: fallback),
            previousSessions: appState.sessionManager.getAllSessions(),
            todaysMood: nil
        )
    }

    /// Pazartesi başlangıçlı takvim haftası (Geçmiş ekranıyla aynı tanım)
    private func mondayOfCurrentWeek() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today) ?? today
    }

    private func snapshot() -> [String: String] {
        guard let manager = appState?.sessionManager else { return ["active": "0"] }

        let calendar = Calendar.current
        let monday = mondayOfCurrentWeek()
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        func minutes(since start: Date) -> Int {
            manager.getAllSessions()
                .filter { $0.startTime >= start }
                .reduce(0) { $0 + Int($1.totalFocusDuration / 60) }
        }

        let todayMinutes = manager.getTodaysSessions()
            .reduce(0) { $0 + Int($1.totalFocusDuration / 60) }
        var dict = [
            "active": "0",
            "recommended": recommendedMethod().rawValue,
            "todayMinutes": String(todayMinutes),
            "weekMinutes": String(minutes(since: monday)),
            "monthMinutes": String(minutes(since: monthStart))
        ]
        if let session = manager.currentSession,
           let endDate = manager.phaseEndDateForWatch {
            dict["active"] = "1"
            dict["isBreak"] = manager.isBreak ? "1" : "0"
            dict["method"] = session.method.rawValue
            dict["endDate"] = String(endDate.timeIntervalSince1970)
        }
        return dict
    }

    private func pushStateIfChanged() {
        let current = snapshot()
        guard current != lastSnapshot else { return }
        lastSnapshot = current

        let isActive = current["active"] == "1"
        let endDate = Double(current["endDate"] ?? "").map(Date.init(timeIntervalSince1970:))
        let isBreak = current["isBreak"] == "1"

        // 1. Saate yayınla
        if WCSession.default.activationState == .activated {
            var context: [String: Any] = [
                "active": isActive,
                "recommended": current["recommended"] ?? "",
                "todayMinutes": Int(current["todayMinutes"] ?? "") ?? 0
            ]
            if isActive {
                context["isBreak"] = isBreak
                context["method"] = current["method"] ?? ""
                context["endDate"] = (endDate ?? Date()).timeIntervalSince1970
            }
            try? WCSession.default.updateApplicationContext(context)
        }

        // 2. iPhone widget'larını besle (ana ekran + kilit ekranı)
        WidgetFeed.publish(
            endDate: isActive ? endDate : nil,
            isBreak: isBreak,
            todayMinutes: Int(current["todayMinutes"] ?? "") ?? 0,
            weekMinutes: Int(current["weekMinutes"] ?? "") ?? 0,
            monthMinutes: Int(current["monthMinutes"] ?? "") ?? 0
        )

        // 3. Dynamic Island / Live Activity
        LiveActivityManager.shared.sync(
            methodName: current["method"],
            endDate: isActive ? endDate : nil,
            isBreak: isBreak
        )
    }

    // MARK: - Saatten gelen komutlar

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            guard let appState = self?.appState else { return }
            let manager = appState.sessionManager

            switch command {
            case "start":
                guard manager.currentSession == nil else { break }
                // Saatte seçilen metod; seçilmediyse telefonun önerisi.
                // Niyet ve bağlam her zaman alışılmış olanlar (karar yükü yok).
                let method = (message["method"] as? String)
                    .flatMap(FocusMethod.init(rawValue:))
                    ?? self?.recommendedMethod() ?? .pomodoro
                let context = WorkContextManager.shared.selectedContext
                manager.startSession(
                    method: method,
                    intent: IntentMemory.recall(for: context),
                    workContext: context
                )
                appState.startSession(manager.currentSession!)
            case "end":
                manager.endSession()
                appState.endSession()
            case "skipBreak":
                manager.skipBreak()
            default:
                break
            }
        }
    }

    // MARK: - WCSessionDelegate zorunlulukları

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.lastSnapshot = [:]
            self?.pushStateIfChanged()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
#endif
