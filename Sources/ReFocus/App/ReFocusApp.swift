import SwiftUI

// MARK: - FocusedValues for keyboard shortcuts

struct SessionManagerKey: FocusedValueKey {
    typealias Value = SessionManager
}

struct NavigationActionKey: FocusedValueKey {
    typealias Value = NavigationAction
}

/// Navigasyon aksiyonları için helper
class NavigationAction: ObservableObject {
    var startNewSession: (() -> Void)?
    var showSettings: (() -> Void)?
    var showSummary: (() -> Void)?
}

extension FocusedValues {
    var sessionManager: SessionManager? {
        get { self[SessionManagerKey.self] }
        set { self[SessionManagerKey.self] = newValue }
    }

    var navigationAction: NavigationAction? {
        get { self[NavigationActionKey.self] }
        set { self[NavigationActionKey.self] = newValue }
    }
}

@main
struct ReFocusApp: App {
    // AppDelegate bağlantısı - platform bazlı
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @StateObject private var appState = AppState()

    init() {
        #if DEBUG
        // Vitrin modu: store ekran görüntüleri için örnek veriyi,
        // AppState/SessionManager oluşturulmadan önce yaz
        MarketingTour.seedIfNeeded()
        #endif

        // NotificationManager'ı erken başlat - delegate'in ayarlanması için gerekli
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        #if os(macOS)
        .commands {
            // File menüsü yerine Session menüsü
            CommandGroup(replacing: .newItem) {
                SessionCommands()
            }

            // View menüsüne Summary ve Mini Timer ekle
            CommandGroup(after: .sidebar) {
                ViewCommands()

                Divider()

                MiniTimerCommand()
            }

            // Help menüsü öncesi - About
            CommandGroup(replacing: .appInfo) {
                Button("ReFocus Hakkında") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "ReFocus",
                            .applicationVersion: "1.0.0",
                            .credits: NSAttributedString(string: "Kişiye özel odak ve zaman yönetimi asistanı")
                        ]
                    )
                }
            }
        }
        .defaultSize(width: 1000, height: 700)
        #endif

        // macOS Mini Timer penceresi (tek pencere)
        #if os(macOS)
        Window("Mini Timer", id: "mini-timer") {
            MiniTimerView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)

        // macOS Ayarlar penceresi
        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        // macOS Menu Bar Timer
        MenuBarExtra {
            MenuBarTimerView()
                .environmentObject(appState)
        } label: {
            MenuBarTimerLabel()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

// MARK: - macOS Menu Commands

#if os(macOS)
struct MiniTimerCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Mini Timer Aç") {
            openWindow(id: "mini-timer")
        }
        .keyboardShortcut("m", modifiers: [.command, .shift])
    }
}

struct SessionCommands: View {
    @FocusedValue(\.sessionManager) var sessionManager
    @FocusedValue(\.navigationAction) var navigationAction

    var body: some View {
        // Yeni seans başlat
        Button("Yeni Seans Başlat") {
            navigationAction?.startNewSession?()
        }
        .keyboardShortcut("n", modifiers: .command)
        .disabled(sessionManager?.isActive == true)

        Divider()

        // Seansı duraklat/devam ettir
        if sessionManager?.isActive == true {
            if sessionManager?.currentSession?.isPaused == true {
                Button("Seansa Devam Et") {
                    sessionManager?.resumeSession()
                }
                .keyboardShortcut("p", modifiers: .command)
            } else {
                Button("Seansı Duraklat") {
                    sessionManager?.pauseSession()
                }
                .keyboardShortcut("p", modifiers: .command)
            }

            Button("Seansı Bitir") {
                sessionManager?.freezeSession()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }
    }
}

struct ViewCommands: View {
    @FocusedValue(\.navigationAction) var navigationAction

    var body: some View {
        Button("Özet Görünümü") {
            navigationAction?.showSummary?()
        }
        .keyboardShortcut("s", modifiers: [.command, .shift])
    }
}

// MARK: - Mini Timer View

/// Mini timer penceresi - Küçük, her zaman üstte kalan timer
struct MiniTimerView: View {
    @EnvironmentObject var appState: AppState

    // State değişkenleri - timer ile güncellenir
    @State private var timeRemaining: TimeInterval = 0
    @State private var isActive: Bool = false
    @State private var isBreak: Bool = false
    @State private var isPaused: Bool = false
    @State private var methodName: String = ""

    /// Timer for updating the view
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            if isActive {
                activeSessionView
            } else {
                noSessionView
            }
        }
        .padding(16)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#1A1A2E"))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        )
        .onAppear {
            setWindowAlwaysOnTop()
            updateFromSessionManager()
        }
        .onReceive(timer) { _ in
            updateFromSessionManager()
        }
    }

    private func updateFromSessionManager() {
        let sm = appState.sessionManager
        timeRemaining = sm.timeRemaining
        isActive = sm.isActive && sm.currentSession != nil
        isBreak = sm.isBreak
        isPaused = sm.currentSession?.isPaused ?? false
        methodName = sm.currentSession?.method.rawValue ?? ""
    }

    private var activeSessionView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isBreak ? Color.breakBlue : Color.focusGreen)
                    .frame(width: 8, height: 8)

                Text(isBreak ? "Mola" : "Odak")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(timeRemaining.formattedTime)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(methodName)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 12) {
                Button(action: {
                    let sm = appState.sessionManager
                    if sm.currentSession?.isPaused == true {
                        sm.resumeSession()
                    } else {
                        sm.pauseSession()
                    }
                    updateFromSessionManager()
                }) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(action: {
                    appState.sessionManager.freezeSession()
                    // Ana pencereyi öne getir - feedback orada gösterilecek
                    NSApp.activate(ignoringOtherApps: true)
                    if let mainWindow = NSApp.windows.first(where: { $0.canBecomeMain && !$0.title.contains("Mini") }) {
                        mainWindow.makeKeyAndOrderFront(nil)
                    }
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noSessionView: some View {
        VStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.5))

            Text("Aktif seans yok")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            Text("Ana pencereden\nseans başlatın")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private func setWindowAlwaysOnTop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Mini Timer" }) {
                window.level = .floating
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isMovableByWindowBackground = true
                window.backgroundColor = .clear
            }
        }
    }
}

// MARK: - Menu Bar Timer

/// Menu bar'da gösterilen timer label
struct MenuBarTimerLabel: View {
    @EnvironmentObject var appState: AppState
    @State private var timeRemaining: TimeInterval = 0
    @State private var isActive: Bool = false
    @State private var isBreak: Bool = false

    /// Timer for updating the label
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if isActive {
                // Aktif seans - süre göster
                HStack(spacing: 4) {
                    Image(systemName: isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                        .symbolRenderingMode(.hierarchical)
                    Text(timeRemaining.formattedTime)
                        .monospacedDigit()
                }
            } else {
                // Seans yok - sadece icon
                Image(systemName: "brain.head.profile")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .onReceive(timer) { _ in
            updateFromSessionManager()
        }
        .onAppear {
            updateFromSessionManager()
        }
    }

    private func updateFromSessionManager() {
        let sm = appState.sessionManager
        timeRemaining = sm.timeRemaining
        isActive = sm.isActive && sm.currentSession != nil
        isBreak = sm.isBreak
    }
}

/// Menu bar tıklanınca açılan popup
struct MenuBarTimerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    private var sm: SessionManager { appState.sessionManager }

    var body: some View {
        VStack(spacing: 0) {
            if sm.isActive, let session = sm.currentSession {
                // Aktif seans görünümü
                activeSessionContent(session: session)
            } else {
                // Seans yok görünümü
                noSessionContent
            }

            Divider()
                .padding(.vertical, 8)

            // Alt menü
            bottomMenu
        }
        .padding(12)
        .frame(width: 220)
    }

    private func activeSessionContent(session: FocusSession) -> some View {
        VStack(spacing: 12) {
            // Durum ve metod
            HStack {
                Circle()
                    .fill(sm.isBreak ? Color.breakBlue : Color.focusGreen)
                    .frame(width: 8, height: 8)

                Text(sm.isBreak ? "Mola" : "Odaklanıyor")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(session.method.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Büyük timer
            Text(sm.timeRemaining.formattedTime)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .monospacedDigit()

            // Kontrol butonları
            HStack(spacing: 12) {
                // Duraklat/Devam
                Button(action: {
                    if session.isPaused {
                        sm.resumeSession()
                    } else {
                        sm.pauseSession()
                    }
                }) {
                    Label(
                        session.isPaused ? "Devam" : "Duraklat",
                        systemImage: session.isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Bitir - Ana pencereye yönlendir (feedback için)
                Button(action: {
                    sm.freezeSession()
                    // Ana pencereyi öne getir - feedback orada gösterilecek
                    NSApp.activate(ignoringOtherApps: true)
                    if let mainWindow = NSApp.windows.first(where: { $0.canBecomeMain && !$0.title.contains("Mini") }) {
                        mainWindow.makeKeyAndOrderFront(nil)
                    }
                }) {
                    Label("Bitir", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private var noSessionContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 32))
                .foregroundColor(.focusGreen)

            Text("Aktif seans yok")
                .font(.headline)

            Text("Ana pencereden seans başlatın")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var bottomMenu: some View {
        VStack(spacing: 4) {
            Button(action: {
                // Ana pencereyi öne getir
                NSApp.activate(ignoringOtherApps: true)
                // Ana pencereyi bul ve öne getir
                if let mainWindow = NSApp.windows.first(where: {
                    $0.title == "ReFocus" || ($0.identifier?.rawValue.contains("main") ?? false) ||
                    (!$0.title.contains("Mini Timer") && $0.isVisible && $0.canBecomeMain)
                }) {
                    mainWindow.makeKeyAndOrderFront(nil)
                } else if let firstWindow = NSApp.windows.first(where: { $0.canBecomeMain && !$0.title.contains("Mini") }) {
                    firstWindow.makeKeyAndOrderFront(nil)
                }
            }) {
                HStack {
                    Label("Ana Pencere", systemImage: "macwindow")
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: {
                openWindow(id: "mini-timer")
            }) {
                HStack {
                    Label("Mini Timer", systemImage: "pip")
                    Spacer()
                    Text("⌘⇧M")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.vertical, 4)

            Button(action: {
                NSApp.terminate(nil)
            }) {
                HStack {
                    Label("Çıkış", systemImage: "power")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Settings View

/// macOS Ayarlar penceresi
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("Genel", systemImage: "gear")
                }

            NotificationSettingsTab()
                .tabItem {
                    Label("Bildirimler", systemImage: "bell")
                }

            SoundSettingsTab()
                .tabItem {
                    Label("Ses", systemImage: "speaker.wave.2")
                }

            AboutTab()
                .tabItem {
                    Label("Hakkında", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showDockBadge") private var showDockBadge = true

    var body: some View {
        Form {
            Section {
                Toggle("Giriş yaparken başlat", isOn: $launchAtLogin)
                Toggle("Dock'ta kalan süreyi göster", isOn: $showDockBadge)
            } header: {
                Text("Başlangıç")
            }

            Section {
                LabeledContent("Varsayılan pencere boyutu") {
                    Text("1000 × 700")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Pencere")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct NotificationSettingsTab: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableSoundNotifications") private var enableSoundNotifications = true
    @AppStorage("enableBackgroundNudges") private var enableBackgroundNudges = true

    var body: some View {
        Form {
            Section {
                Toggle("Bildirimleri etkinleştir", isOn: $enableNotifications)
                Toggle("Sesli bildirimler", isOn: $enableSoundNotifications)
                    .disabled(!enableNotifications)
                Toggle("Arka plan hatırlatmaları", isOn: $enableBackgroundNudges)
                    .disabled(!enableNotifications)
            } header: {
                Text("Bildirim Ayarları")
            }

            Section {
                Text("Seans sonu, mola sonu ve nazik hatırlatmalar için bildirim alırsınız.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Bilgi")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct SoundSettingsTab: View {
    @AppStorage("enableAmbientSounds") private var enableAmbientSounds = false
    @AppStorage("ambientVolume") private var ambientVolume = 0.5

    var body: some View {
        Form {
            Section {
                Toggle("Ortam seslerini etkinleştir", isOn: $enableAmbientSounds)

                if enableAmbientSounds {
                    LabeledContent("Ses seviyesi") {
                        Slider(value: $ambientVolume, in: 0...1)
                            .frame(width: 150)
                    }
                }
            } header: {
                Text("Ortam Sesleri")
            }

            Section {
                Text("Yağmur, orman, beyaz gürültü ve lo-fi sesleri odak seansları sırasında kullanılabilir.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Bilgi")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.focusGreen)

            Text("ReFocus")
                .font(.title)
                .fontWeight(.semibold)

            Text("Sürüm 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            Text("Kişiye özel odak ve zaman yönetimi asistanı")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("© 2024 ReFocus")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif

/// AppState - Ana uygulama durumu yöneticisi
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var userProfile: UserProfile?
    @Published var currentSession: FocusSession?

    /// Shared SessionManager - tüm pencereler arasında paylaşılır
    let sessionManager = SessionManager()

    init() {
        // UserDefaults'tan onboarding durumunu yükle
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // Kaydedilmiş profili yükle
        if let profileData = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            self.userProfile = profile
        }

        mergeProfileFromCloud()

        #if os(iOS)
        // Apple Watch köprüsü: durum yayını + saatten komut alma
        PhoneWatchBridge.shared.configure(appState: self)
        #endif
    }

    func completeOnboarding(profile: UserProfile) {
        self.userProfile = profile
        self.hasCompletedOnboarding = true

        // Kaydet
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        ProfileEngine.persist(profile)
    }

    /// iCloud'daki profil daha yeniyse onu benimse; yerel profil buluta hiç
    /// gitmemişse gönder. Başka cihazda onboarding tamamlanmışsa burada atlanır.
    func mergeProfileFromCloud() {
        guard CloudStore.shared.isAvailable else { return }

        let localDate = UserDefaults.standard.object(forKey: "userProfileUpdatedAt") as? Date ?? .distantPast
        let cloud = CloudStore.shared.fetchAll(UserProfile.self, kind: .profile)
            .first { $0.id == "userProfile" }

        if let cloud, cloud.updatedAt > localDate || userProfile == nil {
            userProfile = cloud.value
            hasCompletedOnboarding = true
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            if let encoded = try? JSONEncoder().encode(cloud.value) {
                UserDefaults.standard.set(encoded, forKey: "userProfile")
                UserDefaults.standard.set(cloud.updatedAt, forKey: "userProfileUpdatedAt")
            }
        } else if cloud == nil, let profile = userProfile {
            // İlk taşıma: mevcut yerel profili buluta gönder
            CloudStore.shared.upsert(profile, kind: .profile, id: "userProfile", updatedAt: localDate)
        }
    }

    /// Uygulama öne geldiğinde iCloud'dan gelen değişiklikleri al
    func refreshFromCloud() {
        mergeProfileFromCloud()
        sessionManager.mergeSessionsFromCloud()
        WorkContextManager.shared.mergeFromCloud()

        // Arkadaş özetlerini tazele ve kendi bugününü yayınla
        FriendSyncManager.shared.publishToday(sessions: sessionManager.getAllSessions())
        Task { await FriendSyncManager.shared.refreshFriends() }
    }

    func startSession(_ session: FocusSession) {
        self.currentSession = session
    }

    func endSession() {
        self.currentSession = nil
    }
}
