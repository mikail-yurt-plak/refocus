import Foundation
import WatchConnectivity

/// Watch tarafı bağlantı yöneticisi.
/// iPhone'dan gelen seans durumunu tutar, başlat/bitir komutlarını gönderir.
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    /// iPhone'dan gelen seans anlık görüntüsü
    struct SessionState: Equatable {
        let isBreak: Bool
        let methodName: String
        /// Fazın duvar saatine göre bitişi; sayaç buradan hesaplanır
        let endDate: Date
    }

    @Published private(set) var state: SessionState?
    @Published private(set) var isReachable = false

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Komutlar

    func startSession() {
        WCSession.default.sendMessage(["command": "start"], replyHandler: nil)
    }

    func endSession() {
        WCSession.default.sendMessage(["command": "end"], replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.apply(context: session.receivedApplicationContext)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.apply(context: applicationContext)
        }
    }

    private func apply(context: [String: Any]) {
        guard context["active"] as? Bool == true,
              let end = context["endDate"] as? TimeInterval else {
            state = nil
            return
        }
        state = SessionState(
            isBreak: context["isBreak"] as? Bool ?? false,
            methodName: context["method"] as? String ?? "",
            endDate: Date(timeIntervalSince1970: end)
        )
    }
}
