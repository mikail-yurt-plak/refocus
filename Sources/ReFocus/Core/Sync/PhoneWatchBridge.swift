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

    private func snapshot() -> [String: String] {
        guard let manager = appState?.sessionManager,
              let session = manager.currentSession,
              let endDate = manager.phaseEndDateForWatch else {
            return ["active": "0"]
        }
        return [
            "active": "1",
            "isBreak": manager.isBreak ? "1" : "0",
            "method": session.method.rawValue,
            "endDate": String(endDate.timeIntervalSince1970)
        ]
    }

    private func pushStateIfChanged() {
        let current = snapshot()
        guard current != lastSnapshot,
              WCSession.default.activationState == .activated else { return }
        lastSnapshot = current

        var context: [String: Any] = ["active": current["active"] == "1"]
        if current["active"] == "1" {
            context["isBreak"] = current["isBreak"] == "1"
            context["method"] = current["method"] ?? ""
            context["endDate"] = Double(current["endDate"] ?? "") ?? 0
        }
        try? WCSession.default.updateApplicationContext(context)
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
                // Telefondaki mantıkla aynı: önerilen metod + alışılmış niyet/bağlam
                let method = MethodSelectionEngine.selectMethod(
                    for: appState.userProfile ?? UserProfile(onboardingAnswers: OnboardingAnswers(
                        workType: .knowledgeWorker, struggleTime: .medium,
                        hardestPart: .starting, phoneCheckingFrequency: .sometimes)),
                    previousSessions: manager.getAllSessions(),
                    todaysMood: nil
                )
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
