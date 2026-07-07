#if os(iOS)
import Foundation
import WidgetKit

/// iPhone widget'larının (ana ekran + kilit ekranı) okuduğu ortak veri.
/// App group üzerinden paylaşılır; her anlamlı durum değişiminde yazılır.
/// İstatistikler dönem damgalarıyla saklanır: widget tarafı, damga eskiyse
/// (gece yarısı / hafta / ay devrildiyse) değeri sıfır sayar.
enum WidgetFeed {
    private static let appGroup = "group.com.mikailyurt.refocus"

    static func publish(endDate: Date?, isBreak: Bool,
                        todayMinutes: Int, weekMinutes: Int, monthMinutes: Int) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        if let endDate {
            defaults.set(endDate.timeIntervalSince1970, forKey: "phaseEnd")
            defaults.set(isBreak, forKey: "isBreak")
        } else {
            defaults.removeObject(forKey: "phaseEnd")
            defaults.removeObject(forKey: "isBreak")
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())
        defaults.set(todayMinutes, forKey: "todayMinutes")
        defaults.set(dayStart.timeIntervalSince1970, forKey: "todayStamp")
        defaults.set(weekMinutes, forKey: "weekMinutes")
        defaults.set(monthMinutes, forKey: "monthMinutes")

        WidgetCenter.shared.reloadAllTimelines()
    }
}
#endif
