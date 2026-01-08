import SwiftUI

/// Ana yönlendirme view'ı
/// Onboarding tamamlanmışsa HomeView, yoksa OnboardingView gösterir
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding, appState.userProfile != nil {
                HomeView()
            } else {
                OnboardingView()
            }
        }
    }
}
