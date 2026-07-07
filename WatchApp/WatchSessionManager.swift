import Foundation
import WatchConnectivity
import WatchKit
import WidgetKit

/// Watch tarafı bağlantı yöneticisi.
/// iPhone'dan gelen seans durumunu tutar, başlat/bitir/atla komutlarını
/// gönderir, faz sonunda bilek haptiği verir ve komplikasyonu besler.
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
    /// Telefonun bugün için önerdiği metod (rawValue)
    @Published private(set) var recommendedMethod: String?
    /// Bugün tamamlanan odak dakikaları
    @Published private(set) var todayMinutes = 0

    private var hapticTimer: Timer?
    private static let appGroup = "group.com.mikailyurt.refocus"

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Komutlar

    /// Seçilen metodla (nil = telefonun önerdiğiyle) seans başlatır
    func startSession(method: FocusMethod? = nil) {
        var message: [String: Any] = ["command": "start"]
        if let method { message["method"] = method.rawValue }
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func endSession() {
        WCSession.default.sendMessage(["command": "end"], replyHandler: nil)
    }

    func skipBreak() {
        WCSession.default.sendMessage(["command": "skipBreak"], replyHandler: nil)
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
        recommendedMethod = context["recommended"] as? String
        todayMinutes = context["todayMinutes"] as? Int ?? 0

        let previous = state
        if context["active"] as? Bool == true,
           let end = context["endDate"] as? TimeInterval {
            state = SessionState(
                isBreak: context["isBreak"] as? Bool ?? false,
                methodName: context["method"] as? String ?? "",
                endDate: Date(timeIntervalSince1970: end)
            )
        } else {
            state = nil
        }

        if state != previous {
            scheduleEndHaptic()
            publishToComplication()
        }
    }

    // MARK: - Faz sonu bilek haptiği

    /// Uygulama bilekte açıkken faz bittiği an nazik bir titreşim verir.
    /// (Arka plandayken telefonun bildirimleri saate zaten yansır.)
    private func scheduleEndHaptic() {
        hapticTimer?.invalidate()
        hapticTimer = nil

        guard let state, state.endDate > Date() else { return }
        let interval = state.endDate.timeIntervalSinceNow
        hapticTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            WKInterfaceDevice.current().play(.notification)
        }
    }

    // MARK: - Komplikasyon beslemesi

    /// Kadran widget'ının okuyacağı ortak veriyi yazar
    private func publishToComplication() {
        guard let defaults = UserDefaults(suiteName: Self.appGroup) else { return }
        if let state {
            defaults.set(state.endDate.timeIntervalSince1970, forKey: "phaseEnd")
            defaults.set(state.isBreak, forKey: "isBreak")
        } else {
            defaults.removeObject(forKey: "phaseEnd")
            defaults.removeObject(forKey: "isBreak")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
