import Foundation

/// Kullanıcı profili ve davranışlarına göre en uygun metodu seçen motor
/// MVP: Kural tabanlı sistem (AI gerekmez)
class MethodSelectionEngine {
    /// Kullanıcı için bugünün önerilen metodunu seçer
    static func selectMethod(
        for profile: UserProfile,
        previousSessions: [FocusSession] = [],
        todaysMood: DailyMood? = nil
    ) -> FocusMethod {
        // 1. Eğer bugün mood seçildiyse ve etkisi yüksekse, ona göre öner
        if let mood = todaysMood, mood.methodInfluence > 0.7 {
            return mood.recommendedMethod
        }

        // 2. Eğer kullanıcı tercih ettiği bir metod varsa ve başarılıysa, onu öner
        if let preferred = profile.preferredMethod,
           profile.successfulSessions > 3 {
            // Mood varsa ve yorgun/dağınık ise, tercih etse bile daha kısa metod öner
            if let mood = todaysMood, (mood == .tired || mood == .scattered) {
                return adjustMethodForMood(preferred, mood: mood)
            }
            return preferred
        }

        // 3. Bugün önceki seanslar varsa, onları değerlendir
        let todaySessions = previousSessions.filter { Calendar.current.isDateInToday($0.startTime) }

        if !todaySessions.isEmpty {
            let baseMethod = selectBasedOnTodaysSessions(todaySessions, profile: profile)
            // Mood'a göre ayarla
            if let mood = todaysMood {
                return adjustMethodForMood(baseMethod, mood: mood)
            }
            return baseMethod
        }

        // 4. Bugün seans yoksa, profil tipine göre öner
        let baseMethod = selectBasedOnProfile(profile)

        // Mood'a göre ayarla
        if let mood = todaysMood {
            return adjustMethodForMood(baseMethod, mood: mood)
        }

        return baseMethod
    }

    /// Mood'a göre metodu ayarla
    private static func adjustMethodForMood(_ method: FocusMethod, mood: DailyMood) -> FocusMethod {
        switch mood {
        case .energetic:
            // Daha uzun metoda yükselt
            switch method {
            case .pomodoro: return .extended
            case .extended: return .optimal
            case .optimal: return .deepWork
            case .deepWork: return .deepWork
            }
        case .normal:
            // Değiştirme
            return method
        case .tired, .scattered:
            // Daha kısa metoda düşür
            switch method {
            case .deepWork: return .optimal
            case .optimal: return .extended
            case .extended: return .pomodoro
            case .pomodoro: return .pomodoro
            }
        }
    }

    /// Bugünkü seanslara göre metod seç
    private static func selectBasedOnTodaysSessions(_ sessions: [FocusSession], profile: UserProfile) -> FocusMethod {
        let lastSession = sessions.last!
        let avgQuality = sessions.reduce(0.0) { $0 + $1.focusFlowQuality } / Double(sessions.count)

        // Eğer bugün çok bölünme yaşanıyorsa, daha kısa metod öner
        if avgQuality < 0.5 {
            switch lastSession.method {
            case .deepWork:
                return .optimal
            case .optimal:
                return .extended
            case .extended:
                return .pomodoro
            case .pomodoro:
                return .pomodoro // En kısa metod, değiştirme
            }
        }

        // Eğer son seans çok iyiyse ve kısa metodsa, daha uzun dene
        if lastSession.focusFlowQuality >= 0.85 {
            switch lastSession.method {
            case .pomodoro:
                return .extended
            case .extended:
                return .optimal
            case .optimal:
                return .deepWork
            case .deepWork:
                return .deepWork // En uzun metod, değiştirme
            }
        }

        // Durumu sürdür
        return lastSession.method
    }

    /// Profil tipine göre metod seç (ilk seans)
    private static func selectBasedOnProfile(_ profile: UserProfile) -> FocusMethod {
        // Temel kural: Profil tipi -> Önerilen metod
        let baseMethod = profile.profileType.recommendedMethod

        // Davranışsal verilere göre ince ayar
        if let avgInterruptions = profile.averageInterruptionCount {
            // Çok bölünme varsa, daha kısa metod
            if avgInterruptions > 5 {
                return .pomodoro
            }
            // Az bölünme varsa, daha uzun metod deneyebilir
            else if avgInterruptions <= 2 {
                return baseMethod == .pomodoro ? .extended : baseMethod
            }
        }

        return baseMethod
    }

    /// Kullanıcıya gösterilecek öneri mesajı
    static func getRecommendationMessage(for method: FocusMethod, profile: UserProfile) -> String {
        let greeting = greetingForTimeOfDay()

        switch method {
        case .pomodoro:
            return "\(greeting)\n\nBugün senin için **Pomodoro** uygun görünüyor.\nKısa, yoğun odak seanslarıyla başlayalım."

        case .extended:
            return "\(greeting)\n\nBugün **40/10** metodunu deneyelim.\nBiraz daha uzun odaklanmaya hazırsın."

        case .optimal:
            return "\(greeting)\n\nBugün **52/17** senin için ideal.\nDengeli ve sürdürülebilir bir ritim."

        case .deepWork:
            return "\(greeting)\n\nBugün **Deep Work** günü.\nKesintisiz, derin odak için hazırsın."
        }
    }

    /// Günün saatine göre selamlama
    private static func greetingForTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Günaydın ☀️"
        case 12..<17:
            return "İyi günler 🌤️"
        case 17..<21:
            return "İyi akşamlar 🌙"
        default:
            return "Merhaba 🌟"
        }
    }

    /// Metod değişikliği önerisi (seans sonu)
    static func suggestMethodAdjustment(
        from session: FocusSession,
        feedback: SessionFeedback?
    ) -> FocusMethod? {
        // Eğer kullanıcı süreyi uygun buldu ve odaklıysa, değiştirme
        if let feedback = feedback,
           feedback.wasDurationAppropriate == true,
           feedback.didStayFocused == true {
            return nil
        }

        // Eğer çok bölünme olduysa, daha kısa metod öner
        if session.focusFlowQuality < 0.4 {
            switch session.method {
            case .deepWork: return .optimal
            case .optimal: return .extended
            case .extended: return .pomodoro
            case .pomodoro: return nil // Zaten en kısa
            }
        }

        // Eğer süre kısa geldiyse, daha uzun öner
        if let feedback = feedback,
           feedback.wasDurationAppropriate == false,
           feedback.wasDifficult == false {
            switch session.method {
            case .pomodoro: return .extended
            case .extended: return .optimal
            case .optimal: return .deepWork
            case .deepWork: return nil // Zaten en uzun
            }
        }

        return nil
    }
}
