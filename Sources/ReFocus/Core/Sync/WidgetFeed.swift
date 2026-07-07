#if os(iOS)
import Foundation
import WidgetKit

/// iPhone widget'larının (ana ekran + kilit ekranı) okuduğu ortak veri.
/// App group üzerinden paylaşılır; her anlamlı durum değişiminde yazılır.
enum WidgetFeed {
    private static let appGroup = "group.com.mikailyurt.refocus"

    static func publish(endDate: Date?, isBreak: Bool) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        if let endDate {
            defaults.set(endDate.timeIntervalSince1970, forKey: "phaseEnd")
            defaults.set(isBreak, forKey: "isBreak")
        } else {
            defaults.removeObject(forKey: "phaseEnd")
            defaults.removeObject(forKey: "isBreak")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
#endif
