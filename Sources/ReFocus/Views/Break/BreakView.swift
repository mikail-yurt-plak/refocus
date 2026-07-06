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
            Text("common.label.break")
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
                Text("focus.button.skip_break")
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
                    Text("break.button.continue")
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
    let id: String
    let icon: String

    var title: String {
        String(localized: String.LocalizationValue("break.suggestion.\(id).title"))
    }

    var description: String {
        String(localized: String.LocalizationValue("break.suggestion.\(id).description"))
    }

    static func == (lhs: BreakSuggestion, rhs: BreakSuggestion) -> Bool {
        lhs.id == rhs.id
    }

    static let suggestions: [BreakSuggestion] = [
        BreakSuggestion(id: "breathe", icon: "🧘"),
        BreakSuggestion(id: "walk", icon: "🚶"),
        BreakSuggestion(id: "water", icon: "💧"),
        BreakSuggestion(id: "eyes", icon: "👀"),
        BreakSuggestion(id: "window", icon: "🌿"),
        BreakSuggestion(id: "stretch", icon: "🙆")
    ]

    static func random() -> BreakSuggestion {
        suggestions.randomElement() ?? suggestions[0]
    }

    static func random(excluding current: BreakSuggestion) -> BreakSuggestion {
        let filtered = suggestions.filter { $0.id != current.id }
        return filtered.randomElement() ?? suggestions[0]
    }
}
