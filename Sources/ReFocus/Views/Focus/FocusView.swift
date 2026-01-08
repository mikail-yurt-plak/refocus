import SwiftUI

/// Odak ekranı - Büyük timer, minimal UI
struct FocusView: View {
    @ObservedObject var sessionManager: SessionManager
    @EnvironmentObject var appState: AppState
    @State private var showingEndConfirmation = false
    @State private var showingFeedback = false
    @Environment(\.verticalSizeClass) var verticalSizeClass

    /// Yatay mod kontrolü
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            // Arka plan rengi (odak vs mola)
            (sessionManager.isBreak ? Color.breakBlue : Color.appBackground)
                .ignoresSafeArea()

            GeometryReader { geometry in
                if isLandscape {
                    // Yatay mod düzeni
                    landscapeLayout(geometry: geometry)
                } else {
                    // Dikey mod düzeni
                    portraitLayout
                }
            }
        }
        .sheet(isPresented: $showingFeedback) {
            if let session = sessionManager.currentSession {
                FeedbackView(session: session, sessionManager: sessionManager)
            }
        }
        .alert("Seansı Bitir?", isPresented: $showingEndConfirmation) {
            Button("İptal", role: .cancel) {}
            Button("Bitir", role: .destructive) {
                endSession()
            }
        } message: {
            Text("Seansı şimdi bitirmek istediğinden emin misin?")
        }
    }

    // MARK: - Portrait Layout

    private var portraitLayout: some View {
        VStack(spacing: 40) {
            // Üst bar - Metod adı ve kapat butonu
            topBar

            Spacer()

            // Ana timer
            timerSection(ringSize: 200)

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
        HStack(spacing: 0) {
            // Sol taraf - Timer ve progress ring
            VStack(spacing: 16) {
                timerSection(ringSize: min(geometry.size.height * 0.5, 150))
            }
            .frame(width: geometry.size.width * 0.5)

            // Sağ taraf - Bilgi ve kontroller
            VStack(spacing: 20) {
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
                    Text(session.method.rawValue)
                        .font(.heading3)
                        .foregroundColor(.textPrimary)

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
                    Text(session.method.rawValue)
                        .font(.heading3)
                        .foregroundColor(.textPrimary)

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

    private func timerSection(ringSize: CGFloat) -> some View {
        VStack(spacing: isLandscape ? 8 : 16) {
            // Büyük timer
            Text(sessionManager.timeRemaining.formattedTime)
                .font(isLandscape ? .system(size: 48, weight: .medium, design: .rounded) : .timerLarge)
                .foregroundColor(.textPrimary)
                .monospacedDigit()

            // Progress ring
            if let session = sessionManager.currentSession {
                ProgressRing(
                    progress: calculateProgress(session: session),
                    color: sessionManager.isBreak ? .breakBlue : .focusGreen
                )
                .frame(width: ringSize, height: ringSize)
            }
        }
    }

    private var statusMessage: some View {
        Group {
            if sessionManager.isBreak {
                Text("Biraz nefes al.\nBir sonraki seansa hazırlan.")
                    .gentleMessageStyle()
            } else if let session = sessionManager.currentSession {
                let engine = ProfileEngine(profile: appState.userProfile!)
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
                Button(action: { sessionManager.skipBreak() }) {
                    Text("Molayı Atla")
                        .font(.button)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                }
            } else {
                // Odak kontrolü
                Button(action: togglePause) {
                    Image(systemName: sessionManager.isActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.focusGreen)
                }
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

    private func togglePause() {
        if sessionManager.isActive {
            sessionManager.pauseSession()
        } else {
            sessionManager.resumeSession()
        }
    }

    private func endSession() {
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
                .animation(.linear(duration: 1), value: progress)
        }
    }
}
