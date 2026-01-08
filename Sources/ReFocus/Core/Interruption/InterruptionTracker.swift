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
    /// Planlanan süreye göre ilerlemeyi ve bölünmeleri gösterir
    static func generateFocusFlowVisualization(for session: FocusSession) -> String {
        let barLength = 20
        let plannedDuration = Double(session.method.focusDuration * 60) // Planlanan süre (saniye)
        let actualDuration = session.totalFocusDuration + session.totalInterruptionDuration

        // Hiç süre geçmemişse boş bar
        guard actualDuration > 0 else {
            return "┃" + String(repeating: "░", count: barLength) + "┃"
        }

        // Planlanan sürenin ne kadarı tamamlandı?
        let completionRatio = min(1.0, actualDuration / plannedDuration)
        let completedBlocks = max(1, Int(completionRatio * Double(barLength)))

        // Tamamlanan kısım için timeline oluştur
        var timeline = Array(repeating: false, count: barLength) // false = boş

        // Tamamlanan blokları işaretle (varsayılan olarak odak)
        for i in 0..<completedBlocks {
            timeline[i] = true
        }

        // Bölünmeleri zaman çizgisine yerleştir (sadece tamamlanan kısımda)
        for interruption in session.interruptions {
            let interruptionStart = interruption.startTime.timeIntervalSince(session.startTime)
            let relativePosition = interruptionStart / plannedDuration
            let position = Int(relativePosition * Double(barLength))

            if position < completedBlocks {
                // Bölünme süresine göre kaç karakter kaplar
                let interruptionLength = max(1, Int((interruption.duration / plannedDuration) * Double(barLength)))
                for i in 0..<interruptionLength {
                    let index = position + i
                    if index < completedBlocks {
                        timeline[index] = false // Bölünme olarak işaretle
                    }
                }
            }
        }

        // Görselleştir: tamamlanan odak = █, bölünme = ▒, tamamlanmamış = ░
        var visualization = ""
        for i in 0..<barLength {
            if i < completedBlocks {
                visualization += timeline[i] ? "█" : "▒"
            } else {
                visualization += "░"
            }
        }

        return "┃\(visualization)┃"
    }

    /// Odak kalitesi mesajı
    static func getFocusQualityMessage(for session: FocusSession) -> String {
        let focusMinutes = Int(session.totalFocusDuration / 60)

        // Çok kısa seanslar için özel mesajlar
        if focusMinutes < 1 {
            let messages = [
                "Seans erken sonlandı.\nBir dahaki sefere daha uzun deneyebilirsin.",
                "Kısa bir deneme oldu.\nÖnemli olan başlamaktı.",
                "Bazen başlamak en zor kısım.\nBunu başardın.",
                "Bugün kısa sürdü.\nBu da sürecin bir parçası.",
                "Odaklanmak zor gelmiş olabilir.\nBunu fark etmek de değerli.",
                "Kısa bir temas oldu.\nHer deneme bir veri bırakır.",
                "Bugün burada kalmak zor oldu.\nBu çok yaygın.",
                "Henüz akışa girmemiş olabilirsin.\nZorlamana gerek yok.",
                "Bazen birkaç saniye bile yeterlidir.\nBaşladığını gördün.",
                "Bu seans kısa kaldı.\nYarın farklı olabilir."
            ]
            return messages.randomElement()!
        } else if focusMinutes < 5 {
            let messages = [
                "Kısa bir seans oldu.\nHer başlangıç değerlidir.",
                "\(focusMinutes) dakika odaklandın.\nKüçük adımlar da önemli.",
                "Kısa ama etkili olabilir.\nNasıl hissettin?",
                "Bugün kısa tuttun.\nBu bilinçli bir tercih olabilir.",
                "Az sürdü ama başladın.\nBu her zaman kolay değildir.",
                "Kısa bir odak anı yakaladın.\nBu da sayılır.",
                "Bu seans uzun değildi.\nAma gerçekti.",
                "Birkaç dakika bile zihni toparlayabilir.",
                "Bugün küçük tuttun.\nBu da sürecin parçası.",
                "Kısa seanslar da alışkanlık kurar."
            ]
            return messages.randomElement()!
        }

        // İzleme modunda farklı mesajlar
        if session.intent == .watching {
            return getWatchingModeMessage(for: session)
        }

        // Normal seanslar için kalite bazlı mesajlar
        let quality = session.focusFlowQuality

        if quality >= 0.85 {
            let messages = [
                "Odak akışın çok iyiydi.",
                "Bu seansı sakin ve dengeli yönettin.",
                "Dikkatini uzun süre korudun.",
                "Akışın neredeyse hiç bölünmedi.",
                "Bu seans oldukça pürüzsüz geçti.",
                "Zihnin işinle uyumluydu.",
                "Odaklanmak bugün daha kolay gelmiş olabilir.",
                "Bu seans iyi bir ritim yakaladı.",
                "Dikkatin istikrarlıydı.",
                "Bu akış hali sürdürülebilirdi."
            ]
            return messages.randomElement()!
        } else if quality >= 0.7 {
            let messages = [
                "Odak akışın genel olarak korundu.",
                "Güzel bir tempo yakaladın.",
                "Dengeli bir seans oldu.",
                "Çoğunlukla odaklı kaldın.",
                "Ufak dalgalanmalar olsa da akış sürdü.",
                "Zaman zaman bölünsen de geri döndün.",
                "Bu seans istikrarlıydı.",
                "Odağın büyük kısmı seninleydi.",
                "Bugün dengeyi iyi kurdun.",
                "Bu tempo uzun vadede işe yarar."
            ]
            return messages.randomElement()!
        } else if quality >= 0.5 {
            let messages = [
                "Birkaç kez bölündün ama geri dönmeyi başardın.",
                "Dalgalı bir seans oldu ama devam ettin.",
                "Zorlandığın anlar oldu ama tamamladın.",
                "Geri dönmek cesaret ister.\nBunu yaptın.",
                "Odak bugün kolay gelmemiş olabilir.",
                "Bölünmeler oldu ama pes etmedin.",
                "Bu seans inişli çıkışlıydı.",
                "Zor anlarda bile seansı sürdürdün.",
                "Akış sık sık kesildi ama geri geldin.",
                "Bugün direnç gösterdin."
            ]
            return messages.randomElement()!
        } else {
            let messages = [
                "Bu seans biraz zorlu geçti.\nBu çok yaygın. Önemli olan geri dönmendi.",
                "Bugün odaklanmak zor olmuş olabilir.\nYarın farklı olabilir.",
                "Her seans aynı olmak zorunda değil.\nKendinle nazik ol.",
                "Zor bir seanstı ama bitirdin.\nBu da bir adımdır.",
                "Bugün zihnin dağınık hissetmiş olabilir.",
                "Bu seans mücadeleliydi.\nBu da sürecin bir parçası.",
                "Odak bugün seni zorladı.\nBu seni tanımlamaz.",
                "Bazen sadece oturmak bile yeterlidir.",
                "Bu seans kolay değildi.\nYine de burada kaldın.",
                "Bugün zorlandığını fark ettin.\nBu farkındalık değerlidir."
            ]
            return messages.randomElement()!
        }
    }

    /// İzleme modu için özel mesajlar
    /// Bölünmeyi yargılamaz, izleme niyetini kabul eder
    private static func getWatchingModeMessage(for session: FocusSession) -> String {
        let focusMinutes = Int(session.totalFocusDuration / 60)
        let hasInterruptions = !session.interruptions.isEmpty

        if hasInterruptions {
            // Düzensizlik tespit edildi (çok sık app switch)
            let messages = [
                "Bu seansı izleyerek geçirdin.\nBiraz dağınık bir akış oldu.",
                "Video izlerken dikkat dağılmış olabilir.\nBu çok yaygın.",
                "İzleme seansı, birkaç geçiş oldu.\nBu da sürecin parçası.",
                "Bazen izlerken başka şeyler dikkatini çeker.\nNormal.",
                "Bu seans biraz parçalı geçti.\nBilinçli fark etmek değerli."
            ]
            return messages.randomElement()!
        } else {
            // Düzensizlik yok - iyi bir izleme seansı
            let messages = [
                "Bu seansı izleyerek geçirdin.\nAkışın genel olarak korundu.",
                "\(focusMinutes) dakika video izleyerek öğrendin.",
                "İzleme seansı tamamlandı.\nDikkatin korundu.",
                "Bu seans istikrarlı bir izleme seansıydı.",
                "Video izleme seansı başarıyla tamamlandı.",
                "İzlerken odaklı kaldın.\nGüzel bir seans oldu."
            ]
            return messages.randomElement()!
        }
    }
}
