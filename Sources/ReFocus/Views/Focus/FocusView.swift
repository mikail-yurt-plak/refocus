import SwiftUI

/// Odak ekranı - Büyük timer, minimal UI
struct FocusView: View {
    @ObservedObject var sessionManager: SessionManager
    @EnvironmentObject var appState: AppState
    @State private var showingEndConfirmation = false
    @State private var showingFeedback = false
    @State private var lastWarningTime: Int = -1 // Son uyarı zamanı (tekrar uyarı önlemek için)

    /// Son 10 saniye mi?
    private var isInFinalCountdown: Bool {
        sessionManager.timeRemaining <= 10 && sessionManager.timeRemaining > 0 && sessionManager.isActive
    }

    /// Son 5 saniye mi?
    private var isInCriticalCountdown: Bool {
        sessionManager.timeRemaining <= 5 && sessionManager.timeRemaining > 0 && sessionManager.isActive
    }

    /// Timer rengi (son saniyelerde değişir)
    private var timerColor: Color {
        if isInCriticalCountdown {
            return .orange
        } else if isInFinalCountdown {
            return Color.orange.opacity(0.8)
        }
        return .textPrimary
    }

    var body: some View {
        ZStack {
            // Arka plan rengi (odak vs mola)
            (sessionManager.isBreak ? Color.breakBlue : Color.appBackground)
                .ignoresSafeArea()

            GeometryReader { geometry in
                // Yatay mod tespiti - geometry'den doğrudan hesapla
                let isLandscapeMode = geometry.size.width > geometry.size.height

                if isLandscapeMode {
                    // Yatay mod düzeni
                    landscapeLayout(geometry: geometry)
                } else {
                    // Dikey mod düzeni
                    portraitLayout(geometry: geometry)
                }
            }
        }
        .sheet(isPresented: $showingFeedback) {
            if let session = sessionManager.currentSession {
                FeedbackView(session: session, sessionManager: sessionManager)
            }
        }
        .alert("Seansı Bitir?", isPresented: $showingEndConfirmation) {
            Button("İptal", role: .cancel) { }
            Button("Bitir", role: .destructive) {
                endSession()
            }
        } message: {
            Text("Seansı şimdi bitirmek istediğinden emin misin?")
        }
        .onChange(of: sessionManager.timeRemaining) { oldValue, newValue in
            handleTimerChange(newValue: newValue)
        }
    }

    /// Timer değişikliklerini işle (son saniyeler için haptic)
    private func handleTimerChange(newValue: TimeInterval) {
        let currentSecond = Int(newValue)

        // 10 saniye kaldığında uyar
        if currentSecond == 10 && lastWarningTime != 10 {
            HapticManager.shared.timerWarning()
            lastWarningTime = 10
        }

        // Son 5 saniyede her saniye hafif uyarı
        if currentSecond <= 5 && currentSecond > 0 && currentSecond != lastWarningTime {
            HapticManager.shared.timerWarning()
            lastWarningTime = currentSecond
        }

        // Timer bittiğinde
        if currentSecond == 0 && lastWarningTime != 0 {
            HapticManager.shared.timerCompleted()
            lastWarningTime = 0
        }
    }

    // MARK: - Portrait Layout

    private func portraitLayout(geometry: GeometryProxy) -> some View {
        let ringSize = min(geometry.size.width * 0.65, 280.0)

        return VStack(spacing: 32) {
            // Üst bar - Metod adı ve kapat butonu
            topBar

            Spacer()

            // Ana timer (süre çemberin içinde)
            timerSection(ringSize: ringSize, isLandscapeMode: false)

            // Durum mesajı
            statusMessage

            Spacer()

            // Kontrol butonları
            controlButtons
                .padding(.bottom, 40)
        }
        .padding(.top, 20)
    }

    // MARK: - Landscape Layout

    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        let ringSize = min(geometry.size.height * 0.6, 180.0)

        return HStack(spacing: 0) {
            // Sol taraf - Timer ve progress ring
            VStack {
                Spacer()
                timerSection(ringSize: ringSize, isLandscapeMode: true)
                Spacer()
            }
            .frame(width: geometry.size.width * 0.5)

            // Sağ taraf - Bilgi ve kontroller
            VStack(spacing: 16) {
                // Üst bar - Metod adı ve kapat
                landscapeTopBar

                Spacer()

                // Durum mesajı
                statusMessage
                    .padding(.horizontal, 16)

                Spacer()

                // Kontrol butonları
                controlButtons
            }
            .frame(width: geometry.size.width * 0.5)
            .padding(.vertical, 16)
        }
    }

    private var landscapeTopBar: some View {
        HStack {
            if let session = sessionManager.currentSession {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(session.method.rawValue)
                            .font(.heading3)
                            .foregroundColor(.textPrimary)

                        // Niyet göstergesi
                        Text(session.intent.icon)
                            .font(.caption)
                    }

                    Text(sessionManager.isBreak ? "Mola" : "Odak")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Button(action: { showingEndConfirmation = true }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 24)
    }

    private var topBar: some View {
        HStack {
            if let session = sessionManager.currentSession {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(session.method.rawValue)
                            .font(.heading3)
                            .foregroundColor(.textPrimary)

                        // Niyet göstergesi
                        Text(session.intent.icon)
                            .font(.body)
                    }

                    Text(sessionManager.isBreak ? "Mola" : "Odak")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Button(action: { showingEndConfirmation = true }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 24)
    }

    private func timerSection(ringSize: CGFloat, isLandscapeMode: Bool) -> some View {
        // Progress ring with timer inside
        ZStack {
            if let session = sessionManager.currentSession {
                let ringColor: Color = {
                    if isInFinalCountdown && !sessionManager.isBreak {
                        return .orange
                    }
                    return sessionManager.isBreak ? .breakBlue : .focusGreen
                }()

                // Nefes animasyonu (arka planda)
                if !sessionManager.isBreak && sessionManager.isActive {
                    BreathingCircle(color: ringColor, size: ringSize + 40)
                }

                // Progress ring
                ProgressRing(
                    progress: calculateProgress(session: session),
                    color: ringColor
                )
                .frame(width: ringSize, height: ringSize)

                // Timer - çemberin içinde
                VStack(spacing: 4) {
                    Text(sessionManager.timeRemaining.formattedTime)
                        .font(isLandscapeMode ? .system(size: 36, weight: .medium, design: .rounded) : .system(size: 48, weight: .medium, design: .rounded))
                        .foregroundColor(timerColor)
                        .monospacedDigit()
                        .scaleEffect(isInCriticalCountdown ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isInCriticalCountdown)

                    // Mod etiketi (Odak/Mola)
                    Text(sessionManager.isBreak ? "Mola" : "Odak")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .accessibilityLabel("Kalan süre: \(Int(sessionManager.timeRemaining / 60)) dakika \(Int(sessionManager.timeRemaining) % 60) saniye")
    }

    private var statusMessage: some View {
        Group {
            if sessionManager.isBreak {
                Text("Biraz nefes al.\nBir sonraki seansa hazırlan.")
                    .gentleMessageStyle()
            } else if sessionManager.currentSession != nil, let profile = appState.userProfile {
                let engine = ProfileEngine(profile: profile)
                Text(engine.generateGentleMessage(for: .sessionStart))
                    .gentleMessageStyle()
            }
        }
        .padding(.horizontal, 40)
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            if sessionManager.isBreak {
                // Mola kontrolü
                Button(action: {
                    HapticManager.shared.buttonTap()
                    sessionManager.skipBreak()
                }) {
                    Text("Molayı Atla")
                        .font(.button)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                }
            } else {
                // Seansı bitir butonu
                Button(action: { showingEndConfirmation = true }) {
                    Text("Seansı Bitir")
                        .font(.button)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                }
                .accessibilityLabel("Seansı Bitir")
                .accessibilityHint("Odak seansını erken bitirmek için çift tıkla")
            }
        }
        .padding(.horizontal, 40)
    }

    private func calculateProgress(session: FocusSession) -> Double {
        let totalDuration = sessionManager.isBreak
            ? Double(session.method.breakDuration * 60)
            : Double(session.method.focusDuration * 60)

        return 1.0 - (sessionManager.timeRemaining / totalDuration)
    }

    private func endSession() {
        // Seansı dondur - süre sabitlensin, feedback view'da değişmesin
        sessionManager.freezeSession()
        showingFeedback = true
    }
}

/// Progress ring component
struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            // Arka plan çember
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // İlerleme çemberi
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Nefes animasyonu komponenti
/// Sakinleştirici, yavaş pulse efekti - GPU ile render edilir
struct BreathingCircle: View {
    @State private var isAnimating = false
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color.opacity(0.15))
            .frame(width: size, height: size)
            .scaleEffect(isAnimating ? 1.08 : 0.95)
            .opacity(isAnimating ? 0.7 : 0.3)
            .frame(width: size * 1.2, height: size * 1.2) // Scale için ekstra alan
            .drawingGroup() // GPU'ya yükle - CPU kullanımını azaltır
            .animation(
                .easeInOut(duration: 4)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}
