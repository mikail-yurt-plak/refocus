import SwiftUI

/// Seans sonu geri bildirim ekranı
struct FeedbackView: View {
    let session: FocusSession
    @ObservedObject var sessionManager: SessionManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var wasDifficult: Bool?
    @State private var didStayFocused: Bool?
    @State private var wasDurationAppropriate: Bool?
    @State private var quickMood: QuickMood?

    // Mesajı bir kere hesapla ve sakla
    @State private var qualityMessage: String = ""

    /// Kısa seans mı? (15 dakikadan az)
    private var isShortSession: Bool {
        session.totalFocusDuration < 15 * 60
    }

    /// Hızlı geri bildirim ruh hali seçenekleri
    enum QuickMood: String, CaseIterable {
        case great = "great"
        case okay = "okay"
        case struggled = "struggled"

        var emoji: String {
            switch self {
            case .great: return "😊"
            case .okay: return "😐"
            case .struggled: return "😔"
            }
        }

        var label: String {
            switch self {
            case .great: return "İyi hissediyorum"
            case .okay: return "Fena değildi"
            case .struggled: return "Zorlandım"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Başlık
                        headerSection

                        // Odak akışı görselleştirmesi
                        focusFlowSection

                        // Geri bildirim - kısa veya uzun seans için
                        if isShortSession {
                            quickFeedbackSection
                        } else {
                            feedbackQuestions
                        }

                        // Tamamla butonu
                        completeButton

                        // Atla seçeneği
                        skipButton
                    }
                    .padding(.vertical, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Seans Tamamlandı")
                        .font(.heading3)
                }
            }
            .onAppear {
                // Mesajı bir kere hesapla
                if qualityMessage.isEmpty {
                    qualityMessage = InterruptionTracker.getFocusQualityMessage(for: session)
                }
            }
        }
    }

    /// Kısa seanslar için hızlı emoji feedback
    private var quickFeedbackSection: some View {
        VStack(spacing: 16) {
            Text("Nasıl hissettin?")
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)

            HStack(spacing: 16) {
                ForEach(QuickMood.allCases, id: \.self) { mood in
                    Button(action: {
                        HapticManager.shared.selection()
                        quickMood = mood
                    }) {
                        VStack(spacing: 8) {
                            Text(mood.emoji)
                                .font(.system(size: 40))

                            Text(mood.label)
                                .font(.caption)
                                .foregroundColor(quickMood == mood ? .white : .textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(quickMood == mood ? Color.focusGreen : Color.cardBackground)
                        .cornerRadius(16)
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .padding(.horizontal, 24)
    }

    /// Atla butonu - zorlamama prensibi
    private var skipButton: some View {
        Button(action: skipFeedback) {
            Text("Atla")
                .font(.button)
                .foregroundColor(.textSecondary)
        }
        .padding(.top, 8)
    }

    private func skipFeedback() {
        HapticManager.shared.buttonTap()
        sessionManager.endSession(feedback: nil)
        appState.endSession()
        dismiss()
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Text(session.method.icon)
                .font(.system(size: 64))

            Text("\(Int(session.totalFocusDuration / 60)) dakika odaklandın")
                .font(.heading2)
                .foregroundColor(.textPrimary)

            Text(qualityMessage)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 40)
    }

    private var focusFlowSection: some View {
        VStack(spacing: 16) {
            Text("Seans İlerlemesi")
                .font(.captionBold)
                .foregroundColor(.textSecondary)

            // Progress bar
            SessionProgressBar(session: session)

            // Süre bilgisi
            HStack {
                Text("\(Int(session.totalFocusDuration / 60)) dk")
                    .font(.caption)
                    .foregroundColor(.focusGreen)

                Spacer()

                Text("\(session.method.focusDuration) dk")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }

            // Legend with durations
            HStack(spacing: 16) {
                let plannedDuration = Double(session.method.focusDuration * 60)
                let actualDuration = session.totalFocusDuration + session.totalInterruptionDuration
                let remainingDuration = max(0, plannedDuration - actualDuration)

                LegendItem(
                    color: .focusGreen,
                    label: "Odak",
                    duration: session.totalFocusDuration
                )
                if !session.interruptions.isEmpty {
                    LegendItem(
                        color: .orange.opacity(0.6),
                        label: "Bölünme",
                        duration: session.totalInterruptionDuration
                    )
                }
                LegendItem(
                    color: Color.gray.opacity(0.2),
                    label: "Kalan",
                    duration: remainingDuration
                )
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .padding(.horizontal, 24)
    }

    private var feedbackQuestions: some View {
        VStack(spacing: 20) {
            FeedbackQuestion(
                question: "Zor muydu?",
                yesLabel: "Evet, zorlandım",
                noLabel: "Hayır, iyiydi",
                selection: $wasDifficult
            )

            FeedbackQuestion(
                question: "Odaklandın mı?",
                yesLabel: "Evet, odaklıydım",
                noLabel: "Hayır, dağıldım",
                selection: $didStayFocused
            )

            FeedbackQuestion(
                question: "Süre uygun muydu?",
                yesLabel: "Evet, uygundu",
                noLabel: "Hayır, değildi",
                selection: $wasDurationAppropriate
            )
        }
        .padding(.horizontal, 24)
    }

    private var completeButton: some View {
        Button(action: completeFeedback) {
            Text("Tamamla")
                .font(.buttonLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.focusGreen)
                .cornerRadius(16)
        }
        .padding(.horizontal, 40)
        .padding(.top, 16)
    }

    private func completeFeedback() {
        HapticManager.shared.sessionCompleted()

        // Kısa seans için quick mood'u normal feedback'e dönüştür
        let finalWasDifficult: Bool?
        let finalDidStayFocused: Bool?

        if isShortSession, let mood = quickMood {
            switch mood {
            case .great:
                finalWasDifficult = false
                finalDidStayFocused = true
            case .okay:
                finalWasDifficult = false
                finalDidStayFocused = true
            case .struggled:
                finalWasDifficult = true
                finalDidStayFocused = false
            }
        } else {
            finalWasDifficult = wasDifficult
            finalDidStayFocused = didStayFocused
        }

        let feedback = SessionFeedback(
            wasDifficult: finalWasDifficult,
            didStayFocused: finalDidStayFocused,
            wasDurationAppropriate: wasDurationAppropriate,
            additionalNotes: nil
        )

        sessionManager.endSession(feedback: feedback)

        // Profili güncelle
        if var profile = appState.userProfile {
            var profileEngine = ProfileEngine(profile: profile)
            profileEngine.updateProfile(from: session)
            appState.userProfile = profileEngine.profile
        }

        appState.endSession()
        dismiss()
    }
}

/// Geri bildirim sorusu komponenti
struct FeedbackQuestion: View {
    let question: String
    let yesLabel: String
    let noLabel: String
    @Binding var selection: Bool?

    var body: some View {
        VStack(spacing: 12) {
            Text(question)
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)

            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.selection()
                    selection = true
                }) {
                    Text(yesLabel)
                        .font(.button)
                        .foregroundColor(selection == true ? .white : .textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selection == true ? Color.focusGreen : Color.cardBackground)
                        .cornerRadius(12)
                }

                Button(action: {
                    HapticManager.shared.selection()
                    selection = false
                }) {
                    Text(noLabel)
                        .font(.button)
                        .foregroundColor(selection == false ? .white : .textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selection == false ? Color.focusGreen : Color.cardBackground)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

/// Seans ilerleme çubuğu
struct SessionProgressBar: View {
    let session: FocusSession

    private var plannedDuration: Double {
        Double(session.method.focusDuration * 60)
    }

    private var completionRatio: Double {
        let actual = session.totalFocusDuration + session.totalInterruptionDuration
        return min(1.0, actual / plannedDuration)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height: CGFloat = 12

            ZStack(alignment: .leading) {
                // Arka plan (kalan kısım)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)

                // Tamamlanan kısım
                if completionRatio > 0 {
                    // Bölünmeleri hesapla
                    let segments = calculateSegments(totalWidth: width * completionRatio)

                    HStack(spacing: 0) {
                        ForEach(segments.indices, id: \.self) { index in
                            let segment = segments[index]
                            Rectangle()
                                .fill(segment.isInterruption ? Color.orange.opacity(0.6) : Color.focusGreen)
                                .frame(width: segment.width)
                        }
                    }
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: height / 2))
                }
            }
        }
        .frame(height: 12)
    }

    private struct Segment {
        let width: CGFloat
        let isInterruption: Bool
    }

    private func calculateSegments(totalWidth: CGFloat) -> [Segment] {
        let actualDuration = session.totalFocusDuration + session.totalInterruptionDuration
        guard actualDuration > 0, totalWidth > 0 else {
            return [Segment(width: totalWidth, isInterruption: false)]
        }

        var segments: [Segment] = []
        var events: [(time: TimeInterval, isStart: Bool)] = []

        // Bölünme başlangıç ve bitişlerini topla
        for interruption in session.interruptions {
            let startTime = interruption.startTime.timeIntervalSince(session.startTime)
            let endTime = startTime + interruption.duration
            events.append((startTime, true))  // Bölünme başlangıcı
            events.append((endTime, false))   // Bölünme bitişi
        }

        // Hiç bölünme yoksa tek yeşil segment
        if events.isEmpty {
            return [Segment(width: totalWidth, isInterruption: false)]
        }

        // Eventleri sırala
        events.sort { $0.time < $1.time }

        var currentTime: TimeInterval = 0
        var inInterruption = false

        for event in events {
            let eventTime = min(event.time, actualDuration)

            if eventTime > currentTime {
                let segmentDuration = eventTime - currentTime
                let segmentWidth = CGFloat(segmentDuration / actualDuration) * totalWidth
                if segmentWidth > 0 {
                    segments.append(Segment(width: segmentWidth, isInterruption: inInterruption))
                }
                currentTime = eventTime
            }

            if event.isStart {
                inInterruption = true
            } else {
                inInterruption = false
            }
        }

        // Kalan süreyi ekle
        if currentTime < actualDuration {
            let remainingDuration = actualDuration - currentTime
            let remainingWidth = CGFloat(remainingDuration / actualDuration) * totalWidth
            if remainingWidth > 0 {
                segments.append(Segment(width: remainingWidth, isInterruption: inInterruption))
            }
        }

        return segments.isEmpty ? [Segment(width: totalWidth, isInterruption: false)] : segments
    }
}

/// Legend öğesi
struct LegendItem: View {
    let color: Color
    let label: String
    var duration: TimeInterval? = nil

    /// Süreyi formatla (dakika:saniye veya sadece saniye)
    private var formattedDuration: String {
        guard let duration = duration else { return "" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)dk \(seconds)sn"
        } else {
            return "\(seconds)sn"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            if duration != nil {
                Text(formattedDuration)
                    .font(.system(size: 10))
                    .foregroundColor(.textTertiary)
            }
        }
    }
}
