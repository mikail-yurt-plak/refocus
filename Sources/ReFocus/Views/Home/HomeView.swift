import SwiftUI

/// Ana ekran - Günlük öneri
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var sessionManager = SessionManager()
    @State private var recommendedMethod: FocusMethod?
    @State private var showingFocusView = false
    @State private var showingSummary = false
    @State private var showingHeatmap = false
    @State private var showingSoundPicker = false
    @State private var showingDailyCheckIn = false
    @State private var showingMethodPicker = false
    @State private var showingIntentPicker = false
    @State private var todaysMood: DailyMood?
    @State private var selectedIntent: SessionIntent = .mixed

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
            .onAppear {
                requestNotificationPermission()
                checkDailyCheckIn()
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
                        onStart: {
                            showingIntentPicker = false
                            startSession()
                        }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
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
                Text("Bugün \(summary.totalFocusTime) dakika odaklandın")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            } else if sessionManager.getAllSessions().isEmpty {
                // İlk kez kullanan kullanıcı için hoşgeldin mesajı
                Text("İlk seansına başlamaya hazır mısın?")
                    .font(.bodySmall)
                    .foregroundColor(.textSecondary)
            } else {
                // Bugün seans yok ama daha önce kullanmış
                Text("Bugün henüz bir seans yapmadın")
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
                        Text("Değiştir")
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
                    Text("Odak")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                VStack(spacing: 4) {
                    Text("\(method.breakDuration)")
                        .font(.heading2)
                        .foregroundColor(.breakBlue)
                    Text("Mola")
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
                Text("Başla")
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
                    label: "Seans"
                )
            }
            .disabled(sessionManager.getTodaysSessions().isEmpty)

            // Bu hafta - tıklanınca heatmap açılır
            Button(action: { showingHeatmap = true }) {
                StatCard(
                    icon: "calendar",
                    value: "\(getWeeklySessions())",
                    label: "Bu Hafta"
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
        sessionManager.startSession(method: method, intent: selectedIntent)
        appState.startSession(sessionManager.currentSession!)
    }

    private func greetingForTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Günaydın"
        case 12..<17: return "İyi günler"
        case 17..<21: return "İyi akşamlar"
        default: return "Merhaba"
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
/// Niyet seçimi ve başlat butonu içerir
struct SessionStartSheet: View {
    let method: FocusMethod
    @Binding var selectedIntent: SessionIntent
    let onStart: () -> Void

    var body: some View {
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

            // Niyet seçici
            VStack(spacing: 12) {
                Text("Bu seansı nasıl kullanacaksın?")
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

            // Seçili niyetin açıklaması
            Text(intentDescription)
                .font(.caption)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Başla butonu
            Button(action: {
                HapticManager.shared.sessionStarted()
                onStart()
            }) {
                Text("Seansı Başlat")
                    .font(.buttonLarge)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.focusGreen)
                    .cornerRadius(16)
            }
            .primaryButtonStyle()
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.appBackground)
    }

    private var intentDescription: String {
        switch selectedIntent {
        case .reading:
            return "Okuma/yazma modunda 30 saniyeden uzun ayrılmalar bölünme sayılır."
        case .watching:
            return "Video izleme modunda kısa geçişler normal kabul edilir."
        case .mixed:
            return "Karışık modda 60 saniyeden uzun ayrılmalar bölünme sayılır."
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
