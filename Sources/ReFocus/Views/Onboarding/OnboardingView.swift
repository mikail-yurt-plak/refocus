import SwiftUI

/// Onboarding ekranı - 4 soru + özet, kart bazlı
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var workType: OnboardingAnswers.WorkType?
    @State private var struggleTime: OnboardingAnswers.StruggleTime?
    @State private var hardestPart: OnboardingAnswers.HardestPart?
    @State private var phoneFrequency: OnboardingAnswers.PhoneCheckingFrequency?

    private let totalSteps = 5 // 4 soru + 1 özet

    /// Kullanıcının profil tipini belirle
    private var profileType: String {
        guard let struggleTime = struggleTime else { return "Orta Odaklı" }

        switch struggleTime {
        case .short: return "Kısa Odaklı"
        case .medium: return "Orta Odaklı"
        case .long: return "Derin Odaklı"
        }
    }

    /// Profil açıklaması
    private var profileDescription: String {
        guard let struggleTime = struggleTime else { return "20-30 dakikalık seanslar sana uygun." }

        switch struggleTime {
        case .short: return "10-15 dakikalık kısa seanslar sana en uygun.\nSık molalarla verimli çalışabilirsin."
        case .medium: return "20-30 dakikalık seanslar sana uygun.\nDengeli bir tempo yakalayabilirsin."
        case .long: return "40+ dakikalık derin odak seansları\nsana en uygun."
        }
    }

    /// Önerilen başlangıç metodu
    private var suggestedMethod: FocusMethod {
        guard let struggleTime = struggleTime else { return .pomodoro }

        switch struggleTime {
        case .short: return .pomodoro
        case .medium: return .extended
        case .long: return .deepWork
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                // Progress bar
                ProgressView(value: Double(currentStep), total: Double(totalSteps))
                    .tint(.focusGreen)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                Spacer()

                // Soru kartı
                questionCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                Spacer()

                // Butonlar
                actionButtons
                    .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    @ViewBuilder
    private var questionCard: some View {
        switch currentStep {
        case 0:
            QuestionCard(
                question: "Ne tür iş yapıyorsun?",
                options: [
                    ("Öğrenci", "student"),
                    ("Bilgi Çalışanı", "knowledge_worker"),
                    ("Yaratıcı", "creative"),
                    ("Yönetici", "manager")
                ],
                selection: Binding(
                    get: { workType?.rawValue },
                    set: { workType = $0.flatMap { OnboardingAnswers.WorkType(rawValue: $0) } }
                )
            )
        case 1:
            QuestionCard(
                question: "Bir işe başladıktan sonra ne zaman zorlanırsın?",
                options: [
                    ("10–15 dakika", "10-15"),
                    ("20–30 dakika", "20-30"),
                    ("40+ dakika", "40+")
                ],
                selection: Binding(
                    get: { struggleTime?.rawValue },
                    set: { struggleTime = $0.flatMap { OnboardingAnswers.StruggleTime(rawValue: $0) } }
                )
            )
        case 2:
            QuestionCard(
                question: "En zor olan hangisi?",
                options: [
                    ("Başlamak", "starting"),
                    ("Sürdürmek", "continuing"),
                    ("Bitirmek", "finishing")
                ],
                selection: Binding(
                    get: { hardestPart?.rawValue },
                    set: { hardestPart = $0.flatMap { OnboardingAnswers.HardestPart(rawValue: $0) } }
                )
            )
        case 3:
            QuestionCard(
                question: "Çalışırken telefona bakma dürtüsü ne sıklıkta gelir?",
                options: [
                    ("Çok sık", "very_often"),
                    ("Bazen", "sometimes"),
                    ("Nadiren", "rarely")
                ],
                selection: Binding(
                    get: { phoneFrequency?.rawValue },
                    set: { phoneFrequency = $0.flatMap { OnboardingAnswers.PhoneCheckingFrequency(rawValue: $0) } }
                )
            )
        case 4:
            // Özet ekranı
            profileSummaryCard
        default:
            EmptyView()
        }
    }

    /// Profil özet kartı
    private var profileSummaryCard: some View {
        VStack(spacing: 24) {
            Text("🎯")
                .font(.system(size: 64))

            Text("Senin Profilin")
                .font(.heading2)
                .foregroundColor(.textPrimary)

            Text(profileType)
                .font(.heading1)
                .foregroundColor(.focusGreen)

            Text(profileDescription)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            // Önerilen metod
            VStack(spacing: 8) {
                Text("İlk seansın için öneri:")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                HStack(spacing: 12) {
                    Text(suggestedMethod.icon)
                        .font(.title)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestedMethod.rawValue)
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)

                        Text("\(suggestedMethod.focusDuration) dk odak / \(suggestedMethod.breakDuration) dk mola")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.cardBackground)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            }
            .padding(.top, 8)

            Text("Kullanımına göre önerilerimizi\nsürekli iyileştireceğiz.")
                .font(.caption)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button(action: { currentStep -= 1 }) {
                    Text("Geri")
                        .font(.button)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                }
            }

            Button(action: handleNext) {
                Text(currentStep == totalSteps - 1 ? "Hadi Başlayalım!" : "İleri")
                    .font(.button)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isCurrentStepValid ? Color.focusGreen : Color.gray)
                    .cornerRadius(16)
            }
            .primaryButtonStyle()
            .disabled(!isCurrentStepValid)
        }
        .padding(.horizontal, 40)
    }

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return workType != nil
        case 1: return struggleTime != nil
        case 2: return hardestPart != nil
        case 3: return phoneFrequency != nil
        case 4: return true // Özet ekranı her zaman geçerli
        default: return false
        }
    }

    private func handleNext() {
        HapticManager.shared.buttonTap()
        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        guard let workType = workType,
              let struggleTime = struggleTime,
              let hardestPart = hardestPart,
              let phoneFrequency = phoneFrequency else {
            return
        }

        let answers = OnboardingAnswers(
            workType: workType,
            struggleTime: struggleTime,
            hardestPart: hardestPart,
            phoneCheckingFrequency: phoneFrequency
        )

        let profile = UserProfile(onboardingAnswers: answers)
        appState.completeOnboarding(profile: profile)
    }
}

/// Soru kartı component
struct QuestionCard: View {
    let question: String
    let options: [(label: String, value: String)]
    @Binding var selection: String?

    var body: some View {
        VStack(spacing: 24) {
            Text(question)
                .font(.heading2)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                ForEach(options, id: \.value) { option in
                    Button(action: {
                        HapticManager.shared.selection()
                        selection = option.value
                    }) {
                        HStack {
                            Text(option.label)
                                .font(.bodyLarge)
                                .foregroundColor(selection == option.value ? .white : .textPrimary)

                            Spacer()

                            if selection == option.value {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 24)
                        .frame(height: 60)
                        .background(selection == option.value ? Color.focusGreen : Color.cardBackground)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }
}
