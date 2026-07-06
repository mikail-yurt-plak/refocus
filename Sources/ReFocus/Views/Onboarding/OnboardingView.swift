import SwiftUI

/// Onboarding ekranı - 4 soru + çalışma bağlamları + özet, kart bazlı
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var contextManager = WorkContextManager.shared
    @State private var currentStep = 0
    @State private var workType: OnboardingAnswers.WorkType?
    @State private var struggleTime: OnboardingAnswers.StruggleTime?
    @State private var hardestPart: OnboardingAnswers.HardestPart?
    @State private var phoneFrequency: OnboardingAnswers.PhoneCheckingFrequency?
    @State private var selectedContexts: Set<UUID> = []

    private let totalSteps = 6 // 4 soru + çalışma bağlamları + 1 özet

    /// Kullanıcının profil tipini belirle
    private var profileType: String {
        guard let struggleTime = struggleTime else { return String(localized: "onboarding.profile.medium") }

        switch struggleTime {
        case .short: return String(localized: "onboarding.profile.short")
        case .medium: return String(localized: "onboarding.profile.medium")
        case .long: return String(localized: "onboarding.profile.deep")
        }
    }

    /// Profil açıklaması
    private var profileDescription: String {
        guard let struggleTime = struggleTime else { return String(localized: "onboarding.profile_desc.medium") }

        switch struggleTime {
        case .short: return String(localized: "onboarding.profile_desc.short")
        case .medium: return String(localized: "onboarding.profile_desc.medium")
        case .long: return String(localized: "onboarding.profile_desc.deep")
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
            // Geniş pencerelerde (macOS/iPad) içerik yayılmasın, seçenekler okunur kalsın
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    @ViewBuilder
    private var questionCard: some View {
        switch currentStep {
        case 0:
            QuestionCard(
                question: String(localized: "onboarding.q1.question"),
                options: [
                    (String(localized: "onboarding.q1.student"), "student"),
                    (String(localized: "onboarding.q1.knowledge_worker"), "knowledge_worker"),
                    (String(localized: "onboarding.q1.creative"), "creative"),
                    (String(localized: "onboarding.q1.manager"), "manager")
                ],
                selection: Binding(
                    get: { workType?.rawValue },
                    set: { workType = $0.flatMap { OnboardingAnswers.WorkType(rawValue: $0) } }
                )
            )
        case 1:
            QuestionCard(
                question: String(localized: "onboarding.q2.question"),
                options: [
                    (String(localized: "onboarding.q2.short"), "10-15"),
                    (String(localized: "onboarding.q2.medium"), "20-30"),
                    (String(localized: "onboarding.q2.long"), "40+")
                ],
                selection: Binding(
                    get: { struggleTime?.rawValue },
                    set: { struggleTime = $0.flatMap { OnboardingAnswers.StruggleTime(rawValue: $0) } }
                )
            )
        case 2:
            QuestionCard(
                question: String(localized: "onboarding.q3.question"),
                options: [
                    (String(localized: "onboarding.q3.starting"), "starting"),
                    (String(localized: "onboarding.q3.continuing"), "continuing"),
                    (String(localized: "onboarding.q3.finishing"), "finishing")
                ],
                selection: Binding(
                    get: { hardestPart?.rawValue },
                    set: { hardestPart = $0.flatMap { OnboardingAnswers.HardestPart(rawValue: $0) } }
                )
            )
        case 3:
            QuestionCard(
                question: String(localized: "onboarding.q4.question"),
                options: [
                    (String(localized: "onboarding.q4.very_often"), "very_often"),
                    (String(localized: "onboarding.q4.sometimes"), "sometimes"),
                    (String(localized: "onboarding.q4.rarely"), "rarely")
                ],
                selection: Binding(
                    get: { phoneFrequency?.rawValue },
                    set: { phoneFrequency = $0.flatMap { OnboardingAnswers.PhoneCheckingFrequency(rawValue: $0) } }
                )
            )
        case 4:
            // Çalışma bağlamları seçimi
            workContextSelectionCard
        case 5:
            // Özet ekranı
            profileSummaryCard
        default:
            EmptyView()
        }
    }

    /// Çalışma bağlamları seçim kartı
    private var workContextSelectionCard: some View {
        VStack(spacing: 24) {
            Text("🎯")
                .font(.system(size: 48))

            Text("onboarding.context.title")
                .font(.heading2)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            Text("onboarding.context.subtitle")
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)

            // Önerilen bağlamlar grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(WorkContext.suggestions) { context in
                    WorkContextOnboardingChip(
                        context: context,
                        isSelected: selectedContexts.contains(context.id)
                    ) {
                        HapticManager.shared.selection()
                        if selectedContexts.contains(context.id) {
                            selectedContexts.remove(context.id)
                        } else {
                            selectedContexts.insert(context.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Text("onboarding.context.hint")
                .font(.caption)
                .foregroundColor(.textTertiary)
                .padding(.top, 8)
        }
    }

    /// Profil özet kartı
    private var profileSummaryCard: some View {
        VStack(spacing: 24) {
            Text("🎯")
                .font(.system(size: 64))

            Text("onboarding.summary.title")
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
                Text("onboarding.summary.suggestion")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                HStack(spacing: 12) {
                    Text(suggestedMethod.icon)
                        .font(.title)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestedMethod.rawValue)
                            .font(.bodyLarge)
                            .foregroundColor(.textPrimary)

                        Text("common.duration_format \(suggestedMethod.focusDuration) \(suggestedMethod.breakDuration)")
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

            Text("onboarding.summary.hint")
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
                    Text("common.button.back")
                        .font(.button)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                }
            }

            Button(action: handleNext) {
                Text(currentStep == totalSteps - 1 ? "onboarding.button.start" : "common.button.next")
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
        case 4: return true // Çalışma bağlamları opsiyonel, her zaman geçerli
        case 5: return true // Özet ekranı her zaman geçerli
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

        // Seçilen çalışma bağlamlarını kaydet
        let selectedSuggestions = WorkContext.suggestions.filter { selectedContexts.contains($0.id) }
        contextManager.addSuggestedContexts(selectedSuggestions)

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

/// Onboarding için çalışma bağlamı chip'i
struct WorkContextOnboardingChip: View {
    let context: WorkContext
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(context.icon)
                    .font(.title)

                Text(context.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .textPrimary)
                    .lineLimit(1)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.focusGreen : Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gray.opacity(0.25),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
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
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
        }
    }
}
