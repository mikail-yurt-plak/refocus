import SwiftUI

/// Seans sonu geri bildirim ekranı
struct FeedbackView: View {
    let session: FocusSession
    @ObservedObject var sessionManager: SessionManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var wasDifficult: Bool?
    @State private var didStayFocused: Bool?
    @State private var wasDurationAppropriate: Bool?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Başlık
                        headerSection

                        // Odak akışı görselleştirmesi
                        focusFlowSection

                        // Geri bildirim soruları
                        feedbackQuestions

                        // Tamamla butonu
                        completeButton
                    }
                    .padding(.vertical, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Seans Tamamlandı")
                        .font(.heading3)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Text(session.method.icon)
                .font(.system(size: 64))

            Text("\(Int(session.totalFocusDuration / 60)) dakika odaklandın")
                .font(.heading2)
                .foregroundColor(.textPrimary)

            Text(InterruptionTracker.getFocusQualityMessage(for: session))
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 40)
    }

    private var focusFlowSection: some View {
        VStack(spacing: 12) {
            Text("Odak Akışı")
                .font(.captionBold)
                .foregroundColor(.textSecondary)

            Text(InterruptionTracker.generateFocusFlowVisualization(for: session))
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.textPrimary)

            HStack(spacing: 16) {
                Label("Odak", systemImage: "square.fill")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Label("Bölünme", systemImage: "square")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .padding(.horizontal, 24)
    }

    private var feedbackQuestions: some View {
        VStack(spacing: 20) {
            FeedbackQuestion(
                question: "Zor muydu?",
                yesLabel: "Evet, zorlandım",
                noLabel: "Hayır, iyiydi",
                selection: $wasDifficult
            )

            FeedbackQuestion(
                question: "Odaklandın mı?",
                yesLabel: "Evet, odaklıydım",
                noLabel: "Hayır, dağıldım",
                selection: $didStayFocused
            )

            FeedbackQuestion(
                question: "Süre uygun muydu?",
                yesLabel: "Evet, uygundu",
                noLabel: "Hayır, değildi",
                selection: $wasDurationAppropriate
            )
        }
        .padding(.horizontal, 24)
    }

    private var completeButton: some View {
        Button(action: completeFeedback) {
            Text("Tamamla")
                .font(.buttonLarge)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.focusGreen)
                .cornerRadius(16)
        }
        .padding(.horizontal, 40)
        .padding(.top, 16)
    }

    private func completeFeedback() {
        let feedback = SessionFeedback(
            wasDifficult: wasDifficult,
            didStayFocused: didStayFocused,
            wasDurationAppropriate: wasDurationAppropriate,
            additionalNotes: nil
        )

        sessionManager.endSession(feedback: feedback)

        // Profili güncelle
        if var profile = appState.userProfile {
            var profileEngine = ProfileEngine(profile: profile)
            profileEngine.updateProfile(from: session)
            appState.userProfile = profileEngine.profile
        }

        appState.endSession()
        dismiss()
    }
}

/// Geri bildirim sorusu komponenti
struct FeedbackQuestion: View {
    let question: String
    let yesLabel: String
    let noLabel: String
    @Binding var selection: Bool?

    var body: some View {
        VStack(spacing: 12) {
            Text(question)
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)

            HStack(spacing: 12) {
                Button(action: { selection = true }) {
                    Text(yesLabel)
                        .font(.button)
                        .foregroundColor(selection == true ? .white : .textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selection == true ? Color.focusGreen : Color.cardBackground)
                        .cornerRadius(12)
                }

                Button(action: { selection = false }) {
                    Text(noLabel)
                        .font(.button)
                        .foregroundColor(selection == false ? .white : .textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selection == false ? Color.focusGreen : Color.cardBackground)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}
