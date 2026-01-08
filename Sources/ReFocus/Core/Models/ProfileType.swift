import Foundation

/// Kullanıcı profil tipleri
/// Bu tipler kullanıcıya gösterilmez, arka planda metod seçimi için kullanılır
enum ProfileType: String, Codable {
    case shortFocus = "short_focus"      // Kısa Odaklı
    case mediumFocus = "medium_focus"    // Orta Odaklı
    case deepFocus = "deep_focus"        // Derin Odaklı
    case fluctuating = "fluctuating"     // Dalgalı Odaklı

    /// Bu profil tipi için önerilen metod
    var recommendedMethod: FocusMethod {
        switch self {
        case .shortFocus:
            return .pomodoro
        case .mediumFocus:
            return .extended
        case .deepFocus:
            return .deepWork
        case .fluctuating:
            return .optimal
        }
    }

    /// Profil tipi açıklaması (debug için)
    var description: String {
        switch self {
        case .shortFocus:
            return "Kısa süreli odak, sık mola ihtiyacı"
        case .mediumFocus:
            return "Orta süreli odak, dengeli çalışma"
        case .deepFocus:
            return "Uzun süreli kesintisiz odak"
        case .fluctuating:
            return "Değişken odak, gün içi dalgalanma"
        }
    }
}

/// Onboarding soruları ve cevapları
struct OnboardingAnswers: Codable {
    let workType: WorkType
    let struggleTime: StruggleTime
    let hardestPart: HardestPart
    let phoneCheckingFrequency: PhoneCheckingFrequency

    enum WorkType: String, Codable {
        case student = "student"
        case knowledgeWorker = "knowledge_worker"
        case creative = "creative"
        case manager = "manager"
    }

    enum StruggleTime: String, Codable {
        case short = "10-15"      // 10-15 dakika
        case medium = "20-30"     // 20-30 dakika
        case long = "40+"         // 40+ dakika
    }

    enum HardestPart: String, Codable {
        case starting = "starting"
        case continuing = "continuing"
        case finishing = "finishing"
    }

    enum PhoneCheckingFrequency: String, Codable {
        case veryOften = "very_often"
        case sometimes = "sometimes"
        case rarely = "rarely"
    }
}

/// Kullanıcı profili
struct UserProfile: Codable {
    let id: UUID
    let createdAt: Date
    var profileType: ProfileType
    let onboardingAnswers: OnboardingAnswers

    // Davranışsal veriler (zaman içinde güncellenir)
    var averageFocusDuration: TimeInterval?
    var averageInterruptionCount: Int?
    var preferredMethod: FocusMethod?
    var totalSessions: Int
    var successfulSessions: Int

    init(onboardingAnswers: OnboardingAnswers) {
        self.id = UUID()
        self.createdAt = Date()
        self.onboardingAnswers = onboardingAnswers
        self.profileType = Self.determineProfileType(from: onboardingAnswers)
        self.totalSessions = 0
        self.successfulSessions = 0
    }

    /// Onboarding cevaplarından profil tipini belirle
    static func determineProfileType(from answers: OnboardingAnswers) -> ProfileType {
        // Kural tabanlı profil belirleme

        // Eğer mücadele süresi kısaysa ve telefon kontrolü sıksa -> Kısa Odak
        if answers.struggleTime == .short && answers.phoneCheckingFrequency == .veryOften {
            return .shortFocus
        }

        // Eğer mücadele süresi uzunsa ve telefon kontrolü az -> Derin Odak
        if answers.struggleTime == .long && answers.phoneCheckingFrequency == .rarely {
            return .deepFocus
        }

        // Eğer başlangıç zorsa ve telefon kontrolü sık -> Dalgalı Odak
        if answers.hardestPart == .starting && answers.phoneCheckingFrequency != .rarely {
            return .fluctuating
        }

        // Varsayılan: Orta Odak
        if answers.struggleTime == .medium {
            return .mediumFocus
        }

        // Diğer durumlar için dalgalı odak
        return .fluctuating
    }

    /// Profili davranışa göre güncelle
    mutating func updateFromBehavior(
        sessionDuration: TimeInterval,
        interruptionCount: Int,
        wasSuccessful: Bool
    ) {
        totalSessions += 1
        if wasSuccessful {
            successfulSessions += 1
        }

        // Ortalama odak süresini güncelle
        if let currentAverage = averageFocusDuration {
            averageFocusDuration = (currentAverage + sessionDuration) / 2
        } else {
            averageFocusDuration = sessionDuration
        }

        // Ortalama bölünme sayısını güncelle
        if let currentAverage = averageInterruptionCount {
            averageInterruptionCount = (currentAverage + interruptionCount) / 2
        } else {
            averageInterruptionCount = interruptionCount
        }
    }
}
