import Foundation

/// Bölünmeleri izleyen ve kaydeden sınıf
class InterruptionTracker {
    private var currentSession: FocusSession?
    private var backgroundStartTime: Date?
    private var isTracking = false

    /// Bir seans için izlemeye başla
    func startTracking(for session: FocusSession) {
        self.currentSession = session
        self.isTracking = true
    }

    /// İzlemeyi durdur
    func stopTracking() {
        self.isTracking = false
        self.currentSession = nil
        self.backgroundStartTime = nil
    }

    /// Arka plan eventi kaydet
    func recordBackgroundEvent(session: FocusSession, entering: Bool) {
        guard isTracking else { return }

        if entering {
            // Uygulama arka plana alındı
            backgroundStartTime = Date()
            let event = BackgroundEvent(timestamp: Date(), event: .didEnterBackground)
            var updatedSession = session
            updatedSession.addBackgroundEvent(event)
            currentSession = updatedSession
        } else {
            // Uygulama ön plana döndü
            if let startTime = backgroundStartTime {
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)

                // Eğer 5 saniyeden uzun sürdüyse, bölünme olarak kaydet
                if duration > 5 {
                    let interruption = Interruption(startTime: startTime, endTime: endTime)
                    var updatedSession = session
                    updatedSession.addInterruption(interruption)
                    currentSession = updatedSession
                }

                backgroundStartTime = nil
            }

            let event = BackgroundEvent(timestamp: Date(), event: .willEnterForeground)
            var updatedSession = session
            updatedSession.addBackgroundEvent(event)
            currentSession = updatedSession
        }
    }

    /// Nazik mesaj durumu belirle
    func determineMessageSituation(for session: FocusSession) -> ProfileEngine.MessageSituation {
        guard let lastInterruption = session.interruptions.last else {
            return .sessionStart
        }

        let duration = lastInterruption.duration

        if duration < 60 {
            // 1 dakikadan kısa
            return .shortBackground
        } else if duration < 180 {
            // 1-3 dakika
            return .longBackground
        } else {
            // 3+ dakika
            return .longBackground
        }
    }

    /// Odak akışı görselleştirmesi oluştur
    static func generateFocusFlowVisualization(for session: FocusSession) -> String {
        let totalDuration = session.totalFocusDuration + session.totalInterruptionDuration
        guard totalDuration > 0 else { return "┃████████████████████┃" }

        let barLength = 20
        let focusRatio = session.totalFocusDuration / totalDuration

        // Bölünmeleri zaman çizgisine yerleştir
        var timeline = Array(repeating: true, count: barLength) // true = focus, false = interruption

        for interruption in session.interruptions {
            let interruptionStart = interruption.startTime.timeIntervalSince(session.startTime)
            let position = Int((interruptionStart / totalDuration) * Double(barLength))

            if position < barLength {
                // Bölünme süresine göre kaç karakter kaplar
                let interruptionLength = max(1, Int((interruption.duration / totalDuration) * Double(barLength)))
                for i in 0..<interruptionLength {
                    let index = position + i
                    if index < barLength {
                        timeline[index] = false
                    }
                }
            }
        }

        // Görselleştir
        let visualization = timeline.map { $0 ? "█" : "░" }.joined()
        return "┃\(visualization)┃"
    }

    /// Odak kalitesi mesajı
    static func getFocusQualityMessage(for session: FocusSession) -> String {
        let quality = session.focusFlowQuality

        if quality >= 0.85 {
            return "Odak akışın çok iyiydi."
        } else if quality >= 0.7 {
            return "Odak akışın genel olarak korundu."
        } else if quality >= 0.5 {
            return "Birkaç kez bölündün ama geri dönmeyi başardın."
        } else {
            return "Bu seans sırasında birkaç kez bölündün.\nBu çok yaygın. Önemli olan geri dönmendi."
        }
    }
}
