import Foundation
import UserNotifications

/// Bildirimleri yöneten sınıf
/// Minimal, nazik bildirimler - asla spam yok
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private override init() {
        super.init()

        // Delegate'i ayarla - bu sayede uygulama ön plandayken de bildirimler gösterilir
        UNUserNotificationCenter.current().delegate = self
        checkAuthorizationStatus()
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Uygulama ön plandayken bildirim geldiğinde
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Uygulama ön plandayken de banner ve ses göster
        completionHandler([.banner, .sound])
    }

    /// Kullanıcı bildirime tıkladığında
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Bildirim kategorisine göre aksiyon al
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        switch categoryIdentifier {
        case "SESSION_END":
            // Seans bitti bildirimine tıklandı
            NotificationCenter.default.post(name: .sessionEndNotificationTapped, object: nil)
        case "BREAK_END":
            // Mola bitti bildirimine tıklandı
            NotificationCenter.default.post(name: .breakEndNotificationTapped, object: nil)
        default:
            break
        }

        completionHandler()
    }

    // MARK: - Authorization

    /// Bildirim izni iste
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            print("📱 Bildirim izni: \(granted ? "✅ Verildi" : "❌ Reddedildi")")
            return granted
        } catch {
            print("❌ Bildirim izni hatası: \(error)")
            return false
        }
    }

    /// Mevcut izin durumunu kontrol et
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Session Notifications

    /// Seans bitiş bildirimi planla
    func scheduleSessionEndNotification(for method: FocusMethod, in seconds: TimeInterval) {
        // En az 1 saniye olmalı
        let safeInterval = max(1, seconds)

        let content = UNMutableNotificationContent()
        content.title = "Odak Seansı Tamamlandı"
        content.body = "Harika iş çıkardın! Şimdi \(method.breakDuration) dakikalık bir mola zamanı."
        content.sound = .default
        content.categoryIdentifier = "SESSION_END"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: safeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session_end_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Bildirim planlanamadı: \(error.localizedDescription)")
            } else {
                print("✅ Bildirim planlandı: \(safeInterval) saniye sonra")
            }
        }
    }

    /// Test bildirimi gönder (5 saniye sonra)
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Bildirimi"
        content.body = "Bildirimler çalışıyor!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test_notification",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Test bildirimi hatası: \(error.localizedDescription)")
            } else {
                print("✅ Test bildirimi 5 saniye sonra gelecek")
            }
        }
    }

    /// Mola bitiş bildirimi planla
    func scheduleBreakEndNotification(in seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Mola Bitti"
        content.body = "Hazırsan yeni bir seansa başlayabilirsin."
        content.sound = .default
        content.categoryIdentifier = "BREAK_END"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "break_end_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Background Nudge Notifications (Nazik Uyarılar)

    /// Arka plana geçildiğinde nazik hatırlatma bildirimleri planla
    func scheduleBackgroundNudgeNotifications() {
        // Önceki nudge bildirimlerini iptal et
        cancelBackgroundNudgeNotifications()

        // 30 saniye sonra ilk nazik hatırlatma
        let shortContent = UNMutableNotificationContent()
        shortContent.title = "Bir süreliğine ara verdin"
        shortContent.body = "Hazırsan kaldığın yerden devam edebiliriz."
        shortContent.sound = .default
        shortContent.categoryIdentifier = "BACKGROUND_SHORT"

        let shortTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        let shortRequest = UNNotificationRequest(
            identifier: "background_nudge_short",
            content: shortContent,
            trigger: shortTrigger
        )

        // 2 dakika sonra uzun bölünme hatırlatması
        let longContent = UNMutableNotificationContent()
        longContent.title = "Dönmek zor olabilir"
        longContent.body = "İstersen bu seansı kısa tutabiliriz."
        longContent.sound = .default
        longContent.categoryIdentifier = "BACKGROUND_LONG"

        let longTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 120, repeats: false)
        let longRequest = UNNotificationRequest(
            identifier: "background_nudge_long",
            content: longContent,
            trigger: longTrigger
        )

        UNUserNotificationCenter.current().add(shortRequest) { error in
            if let error = error {
                print("❌ Kısa bildirim hatası: \(error.localizedDescription)")
            } else {
                print("✅ 30 sn sonra nazik hatırlatma planlandı")
            }
        }

        UNUserNotificationCenter.current().add(longRequest) { error in
            if let error = error {
                print("❌ Uzun bildirim hatası: \(error.localizedDescription)")
            } else {
                print("✅ 2 dk sonra nazik hatırlatma planlandı")
            }
        }
    }

    /// Arka plan nudge bildirimlerini iptal et (uygulama ön plana dönünce)
    func cancelBackgroundNudgeNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["background_nudge_short", "background_nudge_long"]
        )
        print("🔕 Arka plan bildirimleri iptal edildi")
    }

    // MARK: - Daily Reminder

    /// Günlük hatırlatıcı ayarla (opsiyonel)
    func scheduleDailyReminder(at hour: Int, minute: Int) {
        // Önce mevcut günlük hatırlatıcıları temizle
        cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = "Bugün için hazır mısın?"
        content.body = "Senin için en uygun odak metodunu seçtik."
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER"

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Günlük hatırlatıcıyı iptal et
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["daily_reminder"]
        )
    }

    // MARK: - Day Summary

    /// Gün sonu sessiz özet bildirimi
    func scheduleDaySummaryNotification(totalFocusMinutes: Int, sessionsCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Günün Özeti"

        if totalFocusMinutes > 0 {
            content.body = "Bugün \(totalFocusMinutes) dakika odaklandın. \(sessionsCount) seans tamamladın."
        } else {
            content.body = "Yarın yeni bir başlangıç için hazır ol."
        }

        content.sound = nil // Sessiz bildirim
        content.categoryIdentifier = "DAY_SUMMARY"

        // Akşam 21:00'de gönder
        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "day_summary_\(Date().formatted(date: .numeric, time: .omitted))",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancellation

    /// Tüm bekleyen bildirimleri iptal et
    func cancelAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Belirli bir bildirimi iptal et
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }

    /// Debug: Bekleyen bildirimleri listele
    func listPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📬 Bekleyen bildirimler: \(requests.count)")
            for request in requests {
                print("  - \(request.identifier): \(request.content.title)")
                if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    print("    Kalan süre: \(trigger.timeInterval) saniye")
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sessionEndNotificationTapped = Notification.Name("sessionEndNotificationTapped")
    static let breakEndNotificationTapped = Notification.Name("breakEndNotificationTapped")
}
