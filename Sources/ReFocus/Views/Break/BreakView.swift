import SwiftUI

/// Mola ekranı - Nazik mola önerileri
struct BreakView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var currentSuggestion: BreakSuggestion

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        self._currentSuggestion = State(initialValue: BreakSuggestion.random())
    }

    var body: some View {
        ZStack {
            // Mola mavisi arka plan
            Color.breakBlue.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Timer
                timerSection

                // Mola önerisi
                suggestionCard

                Spacer()

                // Kontrol butonları
                controlButtons
                    .padding(.bottom, 40)
            }
        }
    }

    private var timerSection: some View {
        VStack(spacing: 16) {
            Text("Mola")
                .font(.heading3)
                .foregroundColor(.textSecondary)

            Text(sessionManager.timeRemaining.formattedTime)
                .font(.timerLarge)
                .foregroundColor(.textPrimary)
                .monospacedDigit()
        }
    }

    private var suggestionCard: some View {
        VStack(spacing: 16) {
            Text(currentSuggestion.icon)
                .font(.system(size: 48))

            Text(currentSuggestion.title)
                .font(.heading3)
                .foregroundColor(.textPrimary)

            Text(currentSuggestion.description)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(32)
        .background(Color.cardBackground)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
        .padding(.horizontal, 24)
        .onTapGesture {
            withAnimation {
                currentSuggestion = BreakSuggestion.random(excluding: currentSuggestion)
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            // Molayı atla
            Button(action: { sessionManager.skipBreak() }) {
                Text("Molayı Atla")
                    .font(.button)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.cardBackground)
                    .cornerRadius(16)
            }

            // Yeni seansa başla
            if sessionManager.timeRemaining <= 0 {
                Button(action: startNewSession) {
                    Text("Devam Et")
                        .font(.button)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.focusGreen)
                        .cornerRadius(16)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func startNewSession() {
        if let session = sessionManager.currentSession {
            sessionManager.startSession(method: session.method)
        }
    }
}

/// Mola önerileri
struct BreakSuggestion: Identifiable, Equatable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String

    static let suggestions: [BreakSuggestion] = [
        BreakSuggestion(
            icon: "🧘",
            title: "Derin Nefes Al",
            description: "4 saniye nefes al, 4 saniye tut, 4 saniye ver.\nBunu 3-4 kez tekrarla."
        ),
        BreakSuggestion(
            icon: "🚶",
            title: "Kısa Bir Yürüyüş",
            description: "Masandan kalk ve birkaç adım at.\nKan dolaşımını artır."
        ),
        BreakSuggestion(
            icon: "💧",
            title: "Su İç",
            description: "Bir bardak su iç.\nHidrasyon odaklanmayı artırır."
        ),
        BreakSuggestion(
            icon: "👀",
            title: "Gözlerini Dinlendir",
            description: "20 saniye boyunca 20 metre uzağa bak.\nEkran yorgunluğunu azalt."
        ),
        BreakSuggestion(
            icon: "🌿",
            title: "Pencereden Dışarı Bak",
            description: "Doğaya veya gökyüzüne bak.\nZihnini tazele."
        ),
        BreakSuggestion(
            icon: "🙆",
            title: "Germe Hareketleri",
            description: "Boyun, omuz ve sırt germe hareketleri yap.\nKaslarını gevşet."
        )
    ]

    static func random() -> BreakSuggestion {
        suggestions.randomElement() ?? suggestions[0]
    }

    static func random(excluding current: BreakSuggestion) -> BreakSuggestion {
        let filtered = suggestions.filter { $0.id != current.id }
        return filtered.randomElement() ?? suggestions[0]
    }
}
