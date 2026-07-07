#if os(iOS)
import ActivityKit
import Foundation

/// Dynamic Island / kilit ekranı Live Activity'sini seans durumuyla eşler.
/// PhoneWatchBridge her anlamlı durum değişiminde sync çağırır.
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var activity: Activity<FocusActivityAttributes>?

    private init() {}

    /// Seans durumunu Live Activity'ye yansıt:
    /// başlarken oluştur, faz değişince güncelle, bitince kapat
    func sync(methodName: String?, endDate: Date?, isBreak: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        guard let endDate, let methodName else {
            endActivity()
            return
        }

        let state = FocusActivityAttributes.ContentState(endDate: endDate, isBreak: isBreak)
        let content = ActivityContent(state: state, staleDate: endDate)

        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(
                attributes: FocusActivityAttributes(methodName: methodName),
                content: content
            )
        }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
#endif
