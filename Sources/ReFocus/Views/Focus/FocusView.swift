import SwiftUI

/// Odak ekranı wrapper - Platform bazlı görünüm
struct FocusView: View {
    @ObservedObject var sessionManager: SessionManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        #if os(macOS)
        MacOSFocusView(sessionManager: sessionManager)
        #else
        IOSFocusView(sessionManager: sessionManager)
        #endif
    }
}

/// iOS Odak ekranı - Büyük timer, minimal UI
struct IOSFocusView: View {
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
        .alert(String(localized: "focus.alert.end_title"), isPresented: $showingEndConfirmation) {
            Button(String(localized: "common.button.cancel"), role: .cancel) { }
            Button(String(localized: "common.button.end"), role: .destructive) {
                endSession()
            }
        } message: {
            Text("focus.alert.end_message")
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

                    HStack(spacing: 6) {
                        Text(sessionManager.isBreak ? String(localized: "common.label.break") : String(localized: "common.label.focus"))
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        // Çalışma bağlamı (varsa)
                        if let workContext = session.workContext, !workContext.isDefault {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.textTertiary)

                            Text("\(workContext.icon) \(workContext.name)")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }

            Spacer()
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

                    HStack(spacing: 8) {
                        Text(sessionManager.isBreak ? String(localized: "common.label.break") : String(localized: "common.label.focus"))
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        // Çalışma bağlamı (varsa ve varsayılan değilse)
                        if let workContext = session.workContext, !workContext.isDefault {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.textTertiary)

                            HStack(spacing: 4) {
                                Text(workContext.icon)
                                    .font(.caption)
                                Text(workContext.name)
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                }
            }

            Spacer()
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
                    Text(sessionManager.isBreak ? String(localized: "common.label.break") : String(localized: "common.label.focus"))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .accessibilityLabel(String(localized: "focus.accessibility.time_remaining \(Int(sessionManager.timeRemaining / 60)) \(Int(sessionManager.timeRemaining) % 60)"))
    }

    private var statusMessage: some View {
        Group {
            if sessionManager.isBreak {
                Text("focus.break_message")
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
                    Text("focus.button.skip_break")
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
                    Text("focus.button.end_session")
                        .font(.button)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                }
                .accessibilityLabel(String(localized: "focus.button.end_session"))
                .accessibilityHint(String(localized: "focus.accessibility.end_hint"))
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

// MARK: - macOS Flip Clock Timer

#if os(macOS)
import AppKit

/// macOS Dock badge yöneticisi
class DockBadgeManager {
    static let shared = DockBadgeManager()
    private init() {}

    func updateBadge(timeRemaining: TimeInterval, isBreak: Bool) {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        // Daha kısa format - sadece dakika veya dakika:saniye
        let badgeText: String
        if minutes > 0 {
            badgeText = "\(minutes)m"
        } else {
            badgeText = "\(seconds)s"
        }
        DispatchQueue.main.async {
            NSApp.dockTile.badgeLabel = badgeText
            print("🔴 Dock badge updated: \(badgeText)") // Debug
        }
    }

    func clearBadge() {
        DispatchQueue.main.async {
            NSApp.dockTile.badgeLabel = nil
            print("🔴 Dock badge cleared") // Debug
        }
    }

    func updateForSession(isActive: Bool, timeRemaining: TimeInterval, isBreak: Bool) {
        if isActive {
            updateBadge(timeRemaining: timeRemaining, isBreak: isBreak)
        } else {
            clearBadge()
        }
    }
}

/// Flip Clock stili timer - macOS için optimize edilmiş, responsive
struct FlipClockView: View {
    let timeRemaining: TimeInterval
    let isBreak: Bool
    let scale: CGFloat // 0.5 - 2.0 arası ölçek
    var isActive: Bool = true // Animasyon aktif mi?

    private var minutes: Int {
        Int(timeRemaining) / 60
    }

    private var seconds: Int {
        Int(timeRemaining) % 60
    }

    var body: some View {
        HStack(spacing: 16 * scale) {
            // Dakika
            FlipDigitPair(value: minutes, label: String(localized: "common.unit.minute"), scale: scale, isActive: isActive)

            // Ayırıcı
            Text(":")
                .font(.system(size: 80 * scale, weight: .bold, design: .rounded))
                .foregroundColor(isBreak ? .breakBlue : .focusGreen)
                .offset(y: -10 * scale)

            // Saniye
            FlipDigitPair(value: seconds, label: String(localized: "common.unit.second"), scale: scale, isActive: isActive)
        }
    }
}

/// İki basamaklı flip digit çifti
struct FlipDigitPair: View {
    let value: Int
    let label: String
    let scale: CGFloat
    var isActive: Bool = true

    private var tensDigit: Int {
        value / 10
    }

    private var onesDigit: Int {
        value % 10
    }

    var body: some View {
        VStack(spacing: 8 * scale) {
            HStack(spacing: 8 * scale) {
                FlipDigitCard(digit: tensDigit, scale: scale, isActive: isActive)
                FlipDigitCard(digit: onesDigit, scale: scale, isActive: isActive)
            }

            Text(label)
                .font(.system(size: 12 * scale))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

/// Tek bir flip digit kartı - smooth flip-clock animasyonu
struct FlipDigitCard: View {
    let digit: Int
    let scale: CGFloat
    var isActive: Bool = true

    @State private var previousDigit: Int = 0
    @State private var topRotation: Double = 0
    @State private var bottomRotation: Double = 90
    @State private var isAnimating: Bool = false

    private var cardWidth: CGFloat { 80 * scale }
    private var cardHeight: CGFloat { 120 * scale }
    private var halfHeight: CGFloat { 60 * scale }
    private var cornerRadius: CGFloat { 12 * scale }
    private var fontSize: CGFloat { 72 * scale }

    var body: some View {
        ZStack {
            // Alt katman - yeni sayı (sabit)
            VStack(spacing: 0) {
                halfCard(digit: digit, isTop: true)
                halfCard(digit: digit, isTop: false)
            }

            // Üst yarı flip - eski sayı aşağı dönüyor (sadece aktifken)
            if isActive {
                halfCard(digit: previousDigit, isTop: true)
                    .rotation3DEffect(
                        .degrees(topRotation),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.4
                    )
                    .offset(y: -halfHeight / 2)
                    .opacity(topRotation < -90 ? 0 : 1)

                // Alt yarı flip - yeni sayı yukarı geliyor
                halfCard(digit: digit, isTop: false)
                    .rotation3DEffect(
                        .degrees(bottomRotation),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.4
                    )
                    .offset(y: halfHeight / 2)
                    .opacity(bottomRotation > 0 ? 0 : 1)
            }

            // Orta çizgi
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .frame(height: 2 * scale)
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: .black.opacity(0.3), radius: 4 * scale, y: 2 * scale)
        .onChange(of: digit) { oldValue, newValue in
            // Aktif değilse animasyon yapma
            guard isActive, oldValue != newValue, !isAnimating else { return }

            // Animasyon hazırlığı
            previousDigit = oldValue
            topRotation = 0
            bottomRotation = 90
            isAnimating = true

            // Üst yarı flip animasyonu (eski sayı aşağı düşüyor)
            withAnimation(.easeIn(duration: 0.25)) {
                topRotation = -90
            }

            // Alt yarı flip animasyonu (yeni sayı yukarı geliyor)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.25)) {
                    bottomRotation = 0
                }
            }

            // Animasyon tamamlandı
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnimating = false
            }
        }
        .onChange(of: isActive) { _, newValue in
            // isActive false olunca animasyonu sıfırla
            if !newValue {
                isAnimating = false
                topRotation = -90
                bottomRotation = 0
                previousDigit = digit
            }
        }
        .onAppear {
            previousDigit = digit
            topRotation = -90
            bottomRotation = 0
        }
    }

    /// Yarım kart (üst veya alt)
    private func halfCard(digit: Int, isTop: Bool) -> some View {
        ZStack {
            // Arka plan gradient
            RoundedRectangle(cornerRadius: isTop ? cornerRadius : cornerRadius)
                .fill(
                    LinearGradient(
                        colors: isTop
                            ? [Color(hex: "#3A9183"), Color(hex: "#2E7D6F")]
                            : [Color(hex: "#256B5F"), Color(hex: "#1A4A42")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Sayı - offset ile yarısı gösterilir
            Text("\(digit)")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .offset(y: isTop ? halfHeight / 2 : -halfHeight / 2)
        }
        .frame(width: cardWidth, height: halfHeight)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: isTop ? cornerRadius : 0,
                bottomLeadingRadius: isTop ? 0 : cornerRadius,
                bottomTrailingRadius: isTop ? 0 : cornerRadius,
                topTrailingRadius: isTop ? cornerRadius : 0
            )
        )
    }
}

/// macOS için tam ekran flip clock view - responsive
struct MacOSFocusView: View {
    @ObservedObject var sessionManager: SessionManager
    @EnvironmentObject var appState: AppState
    @State private var showingEndConfirmation = false
    @State private var showingFeedback = false

    var body: some View {
        GeometryReader { geometry in
            let scale = calculateScale(for: geometry.size)

            ZStack {
                // Arka plan - koyu tema
                Color(hex: "#1A1A2E")
                    .ignoresSafeArea()

                VStack(spacing: 40 * scale) {
                    // Üst bar
                    macOSTopBar(scale: scale)

                    Spacer()

                    // Flip Clock - responsive
                    FlipClockView(
                        timeRemaining: sessionManager.timeRemaining,
                        isBreak: sessionManager.isBreak,
                        scale: scale,
                        isActive: !showingFeedback && !showingEndConfirmation
                    )

                    // Durum etiketi
                    HStack(spacing: 12 * scale) {
                        Circle()
                            .fill(sessionManager.isBreak ? Color.breakBlue : Color.focusGreen)
                            .frame(width: 12 * scale, height: 12 * scale)

                        Text(sessionManager.isBreak ? String(localized: "common.label.break") : String(localized: "focus.status.focusing"))
                            .font(.system(size: 18 * scale))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 20 * scale)

                    Spacer()

                    // Alt kontroller
                    macOSControls(scale: scale)
                        .padding(.bottom, 40 * scale)
                }
                .padding(.horizontal, 60 * scale)
            }
        }
        .sheet(isPresented: $showingFeedback) {
            if let session = sessionManager.currentSession {
                FeedbackView(session: session, sessionManager: sessionManager)
            }
        }
        .alert(String(localized: "focus.alert.end_title"), isPresented: $showingEndConfirmation) {
            Button(String(localized: "common.button.cancel"), role: .cancel) { }
            Button(String(localized: "common.button.end"), role: .destructive) {
                sessionManager.freezeSession()
                showingFeedback = true
            }
        } message: {
            Text("focus.alert.end_message")
        }
        // Dock badge güncelleme
        .onAppear {
            DockBadgeManager.shared.updateForSession(
                isActive: sessionManager.isActive,
                timeRemaining: sessionManager.timeRemaining,
                isBreak: sessionManager.isBreak
            )
        }
        .onChange(of: sessionManager.timeRemaining) { _, newValue in
            DockBadgeManager.shared.updateForSession(
                isActive: sessionManager.isActive,
                timeRemaining: newValue,
                isBreak: sessionManager.isBreak
            )
        }
        // Menu Bar veya Mini Timer'dan freezeSession() çağrıldığında feedback göster
        .onChange(of: sessionManager.currentSession?.endTime) { oldValue, newValue in
            if oldValue == nil && newValue != nil && !showingFeedback {
                showingFeedback = true
            }
        }
        .onChange(of: sessionManager.isActive) { _, newValue in
            if !newValue {
                DockBadgeManager.shared.clearBadge()
            }
        }
        .onDisappear {
            DockBadgeManager.shared.clearBadge()
        }
    }

    /// Pencere boyutuna göre ölçek hesapla
    private func calculateScale(for size: CGSize) -> CGFloat {
        // Referans boyut: 1200x800 (tipik macOS pencere boyutu)
        let referenceWidth: CGFloat = 1200
        let referenceHeight: CGFloat = 800

        let widthScale = size.width / referenceWidth
        let heightScale = size.height / referenceHeight

        // En küçük ölçeği kullan (aspect ratio korunsun)
        let scale = min(widthScale, heightScale)

        // Min 0.5, max 2.0 arası sınırla
        return min(max(scale, 0.5), 2.0)
    }

    private func macOSTopBar(scale: CGFloat) -> some View {
        HStack {
            if let session = sessionManager.currentSession {
                VStack(alignment: .leading, spacing: 4 * scale) {
                    HStack(spacing: 8 * scale) {
                        Text(session.method.rawValue)
                            .font(.system(size: 22 * scale, weight: .semibold))
                            .foregroundColor(.white)

                        Text(session.intent.icon)
                            .font(.system(size: 18 * scale))
                    }

                    // Çalışma bağlamı
                    if let workContext = session.workContext, !workContext.isDefault {
                        HStack(spacing: 4 * scale) {
                            Text(workContext.icon)
                            Text(workContext.name)
                        }
                        .font(.system(size: 14 * scale))
                        .foregroundColor(.white.opacity(0.6))
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 20 * scale)
    }

    private func macOSControls(scale: CGFloat) -> some View {
        HStack(spacing: 20 * scale) {
            if sessionManager.isBreak {
                Button(action: { sessionManager.skipBreak() }) {
                    Text("focus.button.skip_break")
                        .font(.system(size: 16 * scale, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32 * scale)
                        .padding(.vertical, 16 * scale)
                        .background(Color.focusGreen)
                        .cornerRadius(12 * scale)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { showingEndConfirmation = true }) {
                    Text("focus.button.end_session")
                        .font(.system(size: 16 * scale, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 32 * scale)
                        .padding(.vertical, 16 * scale)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12 * scale)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
#endif
