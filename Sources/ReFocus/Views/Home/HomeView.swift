import SwiftUI

/// Ana ekran - Günlük öneri
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var navigationAction = NavigationAction()
    @ObservedObject private var contextManager = WorkContextManager.shared

    /// Shared SessionManager - AppState üzerinden erişilir
    private var sessionManager: SessionManager { appState.sessionManager }
    @State private var recommendedMethod: FocusMethod?
    @State private var showingFocusView = false
    @State private var showingSummary = false
    @State private var showingHeatmap = false
    @State private var showingSoundPicker = false
    @State private var showingDailyCheckIn = false
    @State private var showingMethodPicker = false
    @State private var showingIntentPicker = false
    @State private var showingLanguagePicker = false
    @State private var showingFriends = false
    @State private var showingCloudStatus = false
    @State private var todaysMood: DailyMood?
    @State private var selectedIntent: SessionIntent = .mixed
    @State private var selectedWorkContext: WorkContext? = .general

    /// macOS pencere başlığı
    private var windowTitle: String {
        if let session = sessionManager.currentSession {
            let timeStr = sessionManager.timeRemaining.formattedTime
            let status = sessionManager.isBreak ? String(localized: "common.label.break") : String(localized: "common.label.focus")
            return "\(status) - \(timeStr) • \(session.method.rawValue)"
        }
        return "ReFocus"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if sessionManager.currentSession != nil {
                    // Aktif seans varsa FocusView göster
                    FocusView(sessionManager: sessionManager)
                        .supportsAllOrientations()
                } else {
                    // Ana ekran - yalnızca dikey mod
                    mainContent
                        .portraitOnly()
                }
            }
            #if os(macOS)
            .navigationTitle(windowTitle)
            #endif
            .toolbar {
                if sessionManager.currentSession == nil {
                    ToolbarItem(placement: .topBarTrailingCompat) {
                        Button {
                            showingCloudStatus = true
                        } label: {
                            Image(systemName: "icloud")
                                .foregroundColor(.textSecondary)
                        }
                        .accessibilityLabel(Text("cloudstatus.title"))
                    }
                    ToolbarItem(placement: .topBarTrailingCompat) {
                        Button {
                            showingFriends = true
                        } label: {
                            Image(systemName: "person.2")
                                .foregroundColor(.textSecondary)
                        }
                        .accessibilityLabel(Text("friends.title"))
                    }
                    ToolbarItem(placement: .topBarTrailingCompat) {
                        Button {
                            showingLanguagePicker = true
                        } label: {
                            Image(systemName: "globe")
                                .foregroundColor(.textSecondary)
                        }
                        .accessibilityLabel(Text("language.title"))
                    }
                }
            }
            .sheet(isPresented: $showingLanguagePicker) {
                LanguagePickerView()
            }
            .sheet(isPresented: $showingFriends) {
                FriendsView()
            }
            .sheet(isPresented: $showingCloudStatus) {
                CloudStatusView(sessionManager: sessionManager)
            }
            .onAppear {
                requestNotificationPermission()
                checkDailyCheckIn()
                setupNavigationActions()
            }
            .onChange(of: todaysMood) { _, _ in
                saveDailyCheckIn()
                loadRecommendation()
            }
            .sheet(isPresented: $showingDailyCheckIn, onDismiss: {
                loadRecommendation()
            }) {
                DailyCheckInView(todaysMood: $todaysMood)
            }
            .sheet(isPresented: $showingSummary) {
                if let summary = sessionManager.getDailySummary(for: Date()) {
                    SummaryView(summary: summary)
                }
            }
            .sheet(isPresented: $showingHeatmap) {
                HeatmapView(sessionManager: sessionManager)
            }
            .sheet(isPresented: $showingSoundPicker) {
                SoundPickerView()
            }
            .sheet(isPresented: $showingMethodPicker) {
                MethodPickerView(selectedMethod: $recommendedMethod)
            }
            .sheet(isPresented: $showingIntentPicker) {
                if let method = recommendedMethod {
                    SessionStartSheet(
                        method: method,
                        selectedIntent: $selectedIntent,
                        selectedWorkContext: $selectedWorkContext,
                        contextManager: contextManager,
                        onStart: {
                            showingIntentPicker = false
                            startSession()
                        }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
        // macOS keyboard shortcuts için FocusedValues
        .focusedSceneValue(\.sessionManager, sessionManager)
        .focusedSceneValue(\.navigationAction, navigationAction)
    }

    /// Navigasyon aksiyonlarını ayarla (keyboard shortcuts için)
    private func setupNavigationActions() {
        navigationAction.startNewSession = { [self] in
            if sessionManager.currentSession == nil {
                showingIntentPicker = true
            }
        }
        navigationAction.showSummary = { [self] in
            showingSummary = true
        }
    }

    private func requestNotificationPermission() {
        Task {
            await NotificationManager.shared.requestAuthorization()
        }
    }

    private func checkDailyCheckIn() {
        // Bugün check-in yapılmış mı kontrol et
        let lastCheckInDate = UserDefaults.standard.object(forKey: "lastDailyCheckIn") as? Date

        if let lastDate = lastCheckInDate, Calendar.current.isDateInToday(lastDate) {
            // Bugün zaten yapılmışsa, kaydedilen mood'u yükle
            if let moodString = UserDefaults.standard.string(forKey: "todaysMood"),
               let mood = DailyMood(rawValue: moodString) {
                todaysMood = mood
            }
            loadRecommendation()
            return
        }

        // Bugün ilk kez açılıyorsa, check-in göster
        showingDailyCheckIn = true
        // Arka planda öneriyi de yükle (check-in atlanırsa kullanılır)
        loadRecommendation()
    }

    private func saveDailyCheckIn() {
        UserDefaults.standard.set(Date(), forKey: "lastDailyCheckIn")
        if let mood = todaysMood {
            UserDefaults.standard.set(mood.rawValue, forKey: "todaysMood")
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Üst kısım - Özet bilgiler
                topSection
                    .padding(.top, 20)

                // Öneri kartı
                if let method = recommendedMethod {
                    recommendationCard(for: method)
                }

                // Alt kısım - Özet istatistikler
                bottomSection
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var topSection: some View {
        VStack(spacing: 12) {
            Text(greetingForTimeOfDay())
                .font(.heading1)
                .foregroundColor(.textPrimary)

            if let summary = sessionManager.getDailySummary(for: Date()) {
                Text("home.today_focus_time \(summary.totalFocusTime)")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            } else if sessionManager.getAllSessions().isEmpty {
                // İlk kez kullanan kullanıcı için hoşgeldin mesajı
                Text("home.first_session_welcome")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            } else {
                // Bugün seans yok ama daha önce kullanmış
                Text("home.no_sessions_today")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            }

            // Mood gösterimi - tıklanınca değiştirilebilir
            if let mood = todaysMood {
                Button(action: { showingDailyCheckIn = true }) {
                    HStack(spacing: 8) {
                        Text(mood.emoji)
                            .font(.title3)
                        Text(mood.title)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.cardBackground)
                    .cornerRadius(20)
                }
            }
        }
    }

    private func recommendationCard(for method: FocusMethod) -> some View {
        VStack(spacing: 24) {
            // İkon
            Text(method.icon)
                .font(.system(size: 64))

            // Metod adı ve değiştir butonu
            HStack(spacing: 12) {
                Text(method.rawValue)
                    .font(.heading1)
                    .foregroundColor(.textPrimary)

                Button(action: { showingMethodPicker = true }) {
                    HStack(spacing: 4) {
                        Text("common.button.change")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.focusGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.focusGreen.opacity(0.1))
                    .cornerRadius(12)
                }
            }

            // Açıklama
            Text(method.description)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            // Süre bilgisi
            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("\(method.focusDuration)")
                        .font(.heading2)
                        .foregroundColor(.focusGreen)
                    Text("common.label.focus")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                VStack(spacing: 4) {
                    Text("\(method.breakDuration)")
                        .font(.heading2)
                        .foregroundColor(.breakAccent)
                    Text("common.label.break")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)

            // Başla butonu - intent picker'ı açar
            Button(action: { showingIntentPicker = true }) {
                Text("common.button.start")
                    .font(.buttonLarge)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.focusGreen)
                    .cornerRadius(20)
            }
            .primaryButtonStyle()
            .accessibilityLabel("\(method.rawValue) seansı başlat")
            .accessibilityHint("\(method.focusDuration) dakikalık odak seansı başlatmak için çift tıkla")
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
        .background(Color.cardBackground)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
        .padding(.horizontal, 24)
    }

    private var bottomSection: some View {
        HStack(spacing: 24) {
            // Bugünkü seanslar - tıklanınca günlük özet açılır
            Button(action: { showingSummary = true }) {
                StatCard(
                    icon: "chart.bar.fill",
                    value: "\(sessionManager.getTodaysSessions().count)",
                    label: String(localized: "common.label.session")
                )
            }
            .disabled(sessionManager.getTodaysSessions().isEmpty)

            // Bu hafta - tıklanınca heatmap açılır
            Button(action: { showingHeatmap = true }) {
                StatCard(
                    icon: "calendar",
                    value: "\(getWeeklySessions())",
                    label: String(localized: "home.this_week")
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private func loadRecommendation() {
        guard let profile = appState.userProfile else {
            // Profil yoksa varsayılan Pomodoro öner
            recommendedMethod = .pomodoro
            return
        }
        let sessions = sessionManager.getAllSessions()
        recommendedMethod = MethodSelectionEngine.selectMethod(
            for: profile,
            previousSessions: sessions,
            todaysMood: todaysMood
        )
    }

    private func startSession() {
        guard let method = recommendedMethod else { return }
        sessionManager.startSession(method: method, intent: selectedIntent, workContext: selectedWorkContext)
        appState.startSession(sessionManager.currentSession!)
    }

    private func greetingForTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "home.greeting.morning")
        case 12..<17: return String(localized: "home.greeting.afternoon")
        case 17..<21: return String(localized: "home.greeting.evening")
        default: return String(localized: "home.greeting.default")
        }
    }

    private func getWeeklySessions() -> Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return sessionManager.getAllSessions().filter { $0.startTime >= weekAgo }.count
    }
}

/// İstatistik kartı
struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.focusGreen)
                .accessibilityHidden(true)

            Text(value)
                .font(.heading2)
                .foregroundColor(.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

/// Seans başlatma sheet'i
/// Niyet seçimi, çalışma bağlamı ve başlat butonu içerir
struct SessionStartSheet: View {
    let method: FocusMethod
    @Binding var selectedIntent: SessionIntent
    @Binding var selectedWorkContext: WorkContext?
    @ObservedObject var contextManager: WorkContextManager
    let onStart: () -> Void

    @State private var showingAddContext = false

    var body: some View {
        scrollContent
            .onAppear {
                selectedIntent = IntentMemory.recall(for: selectedWorkContext)
            }
            .onChange(of: selectedWorkContext) { _, newContext in
                // Bağlam değişince o bağlamın alışkanlığını getir
                selectedIntent = IntentMemory.recall(for: newContext)
            }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Başlık
                VStack(spacing: 8) {
                    Text(method.icon)
                        .font(.system(size: 48))

                    Text(method.rawValue)
                        .font(.heading2)
                        .foregroundColor(.textPrimary)

                    Text("\(method.focusDuration) dk odak / \(method.breakDuration) dk mola")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 16)

                // Çalışma bağlamı seçici
                WorkContextPickerView(
                    contextManager: contextManager,
                    selectedContext: $selectedWorkContext,
                    onAddNew: { showingAddContext = true }
                )
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)

                // Niyet seçici
                VStack(spacing: 12) {
                    Text("home.intent_prompt")
                        .font(.bodyLarge)
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 12) {
                        ForEach(SessionIntent.allCases, id: \.self) { intent in
                            IntentButton(
                                intent: intent,
                                isSelected: selectedIntent == intent
                            ) {
                                HapticManager.shared.selection()
                                selectedIntent = intent
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Seçili niyetin açıklaması: mod ne için, kural ne
                Text(intentDescription)
                    .font(.footnote)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .animation(.easeInOut(duration: 0.15), value: selectedIntent)

                // Başla butonu
                Button(action: {
                    HapticManager.shared.sessionStarted()
                    onStart()
                }) {
                    Text("home.start_session")
                        .font(.buttonLarge)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.focusGreen)
                        .cornerRadius(16)
                }
                .primaryButtonStyle()
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showingAddContext) {
            AddWorkContextView(contextManager: contextManager) { newContext in
                selectedWorkContext = newContext
                showingAddContext = false
            }
        }
    }

    private var intentDescription: String {
        switch selectedIntent {
        case .reading:
            return String(localized: "intent.description.reading")
        case .watching:
            return String(localized: "intent.description.watching")
        case .mixed:
            return String(localized: "intent.description.mixed")
        }
    }
}

/// Tekil niyet butonu
struct IntentButton: View {
    let intent: SessionIntent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(intent.icon)
                    .font(.title2)

                Text(intent.shortLabel)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.focusGreen : Color.appBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(intent.label) modu")
        .accessibilityHint(isSelected ? "Seçili" : "Seçmek için çift tıkla")
    }
}
