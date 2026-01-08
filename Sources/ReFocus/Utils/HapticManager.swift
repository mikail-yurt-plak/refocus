import UIKit

/// Dokunsal geri bildirim yöneticisi
/// Calm bir deneyim için hafif, rahatsız etmeyen haptic'ler kullanılır
class HapticManager {
    static let shared = HapticManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        // Generator'ları hazırla (performans için)
        prepareGenerators()
    }

    /// Generator'ları önceden hazırla
    func prepareGenerators() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Session Events

    /// Seans başladığında
    func sessionStarted() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Seans tamamlandığında (başarılı)
    func sessionCompleted() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Seans iptal edildiğinde
    func sessionCancelled() {
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Mola başladığında
    func breakStarted() {
        mediumGenerator.impactOccurred()
    }

    /// Mola bittiğinde
    func breakEnded() {
        lightGenerator.impactOccurred()
    }

    // MARK: - Timer Events

    /// Timer son 10 saniye uyarısı
    func timerWarning() {
        lightGenerator.impactOccurred(intensity: 0.5)
    }

    /// Timer sıfırlandığında
    func timerCompleted() {
        mediumGenerator.impactOccurred()
    }

    // MARK: - UI Interactions

    /// Buton seçimi (onboarding, feedback vb.)
    func selection() {
        selectionGenerator.selectionChanged()
    }

    /// Buton basıldığında (Başla, Devam Et vb.)
    func buttonTap() {
        lightGenerator.impactOccurred(intensity: 0.6)
    }

    /// Toggle değiştiğinde
    func toggle() {
        lightGenerator.impactOccurred(intensity: 0.4)
    }

    /// Hatalı işlem
    func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    /// Başarılı işlem
    func success() {
        notificationGenerator.notificationOccurred(.success)
    }
}
