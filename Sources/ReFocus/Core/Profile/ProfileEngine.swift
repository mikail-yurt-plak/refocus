import Foundation

/// Kullanıcı profilini yöneten ve güncelleyen motor
class ProfileEngine: ObservableObject {
    @Published var profile: UserProfile

    init(profile: UserProfile) {
        self.profile = profile
    }

    /// Seans sonrası profili güncelle
    func updateProfile(from session: FocusSession) {
        let wasSuccessful = session.focusFlowQuality >= 0.6 // %60+ odak başarılı sayılır

        profile.updateFromBehavior(
            sessionDuration: session.totalFocusDuration,
            interruptionCount: session.interruptionCount,
            wasSuccessful: wasSuccessful
        )

        // Profil tipini yeniden değerlendir
        reevaluateProfileType()

        // Profili kaydet
        saveProfile()
    }

    /// Davranışa göre profil tipini yeniden değerlendir
    private func reevaluateProfileType() {
        guard let avgFocusDuration = profile.averageFocusDuration,
              let avgInterruptions = profile.averageInterruptionCount,
              profile.totalSessions >= 5 else {
            return // En az 5 seans olana kadar değiştirme
        }

        let avgFocusMinutes = avgFocusDuration / 60

        // Kısa odak: Ortalama 20 dakikadan az odak + çok bölünme
        if avgFocusMinutes < 20 && avgInterruptions > 5 {
            profile.profileType = .shortFocus
        }
        // Derin odak: Ortalama 60+ dakika odak + az bölünme
        else if avgFocusMinutes >= 60 && avgInterruptions <= 2 {
            profile.profileType = .deepFocus
        }
        // Orta odak: Ortalama 30-50 dakika odak
        else if avgFocusMinutes >= 30 && avgFocusMinutes < 60 {
            profile.profileType = .mediumFocus
        }
        // Dalgalı: Diğer durumlar
        else if avgInterruptions > 3 {
            profile.profileType = .fluctuating
        }
    }

    /// Tercih edilen metodu güncelle
    func updatePreferredMethod(from feedback: SessionFeedback, method: FocusMethod) {
        // Eğer kullanıcı bu metodu beğendiyse, tercih olarak kaydet
        if feedback.overallRating >= 4 {
            profile.preferredMethod = method
            saveProfile()
        }
    }

    /// Profili kaydet
    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userProfile")
        }
    }

    /// Kullanıcıya nazik mesajlar oluştur
    func generateGentleMessage(for situation: MessageSituation) -> String {
        switch situation {
        case .sessionStart:
            return "Bu seans sırasında dikkatin dağılabilir.\nFark ettiğinde geri dönmen yeterli."

        case .shortBackground:
            return "Bir süreliğine ara verdin.\nHazırsan kaldığın yerden devam edebiliriz."

        case .longBackground:
            return "Dönmek zor olabilir.\nİstersen bu seansı kısa tutabiliriz."

        case .sessionEndWithInterruptions:
            return "Bu seans sırasında birkaç kez bölündün.\nBu çok yaygın. Önemli olan geri dönmendi."

        case .sessionEndSuccessful:
            return "Odak akışın genel olarak korundu."

        case .improvementDetected:
            return "Geçen haftaya göre daha hızlı geri dönüyorsun."

        case .toughDay:
            return "Zor bir gün oldu.\nYarın yeni bir başlangıç."
        }
    }

    enum MessageSituation {
        case sessionStart
        case shortBackground      // 30-60 saniye
        case longBackground       // 2-3 dakika
        case sessionEndWithInterruptions
        case sessionEndSuccessful
        case improvementDetected
        case toughDay
    }
}
