import SwiftUI

@main
struct ReFocusApp: App {
    @StateObject private var appState = AppState()

    init() {
        // NotificationManager'ı erken başlat - delegate'in ayarlanması için gerekli
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

/// AppState - Ana uygulama durumu yöneticisi
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var userProfile: UserProfile?
    @Published var currentSession: FocusSession?

    init() {
        // UserDefaults'tan onboarding durumunu yükle
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

        // Kaydedilmiş profili yükle
        if let profileData = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            self.userProfile = profile
        }
    }

    func completeOnboarding(profile: UserProfile) {
        self.userProfile = profile
        self.hasCompletedOnboarding = true

        // Kaydet
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userProfile")
        }
    }

    func startSession(_ session: FocusSession) {
        self.currentSession = session
    }

    func endSession() {
        self.currentSession = nil
    }
}
