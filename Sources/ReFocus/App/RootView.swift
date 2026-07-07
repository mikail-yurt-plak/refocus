import SwiftUI

/// Ana yönlendirme view'ı
/// Onboarding tamamlanmışsa HomeView, yoksa OnboardingView gösterir
struct RootView: View {
    @EnvironmentObject var appState: AppState

    #if os(iOS)
    private let didBecomeActive = NotificationCenter.default
        .publisher(for: UIApplication.willEnterForegroundNotification)
    #else
    private let didBecomeActive = NotificationCenter.default
        .publisher(for: NSApplication.didBecomeActiveNotification)
    #endif

    var body: some View {
        Group {
            #if DEBUG
            if let shot = MarketingTour.shotNumber {
                MarketingShotView(shot: shot)
            } else {
                normalContent
            }
            #else
            normalContent
            #endif
        }
        .onReceive(didBecomeActive) { _ in
            // iCloud'dan gelen değişiklikleri al (cihazlar arası senkron)
            appState.refreshFromCloud()
        }
    }

    @ViewBuilder
    private var normalContent: some View {
        if appState.hasCompletedOnboarding, appState.userProfile != nil {
            HomeView()
        } else {
            OnboardingView()
        }
    }
}
