import SwiftUI

/// Günlük check-in view - Bugün nasıl hissediyorsun?
struct DailyCheckInView: View {
    @Binding var todaysMood: DailyMood?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 32) {
                    // Başlık
                    VStack(spacing: 12) {
                        Text("Bugün nasıl hissediyorsun?")
                            .font(.heading2)
                            .foregroundColor(.textPrimary)

                        Text("Bu bilgi, sana en uygun metodu seçmemize yardımcı olacak")
                            .font(.body)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)

                    // Mood seçenekleri
                    VStack(spacing: 16) {
                        ForEach(DailyMood.allCases) { mood in
                            MoodCard(
                                mood: mood,
                                isSelected: todaysMood == mood
                            ) {
                                todaysMood = mood
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Devam butonu
                    Button(action: { dismiss() }) {
                        Text(todaysMood != nil ? "Devam Et" : "Atla")
                            .font(.buttonLarge)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(todaysMood != nil ? Color.focusGreen : Color.gray)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Mood kartı
struct MoodCard: View {
    let mood: DailyMood
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(mood.emoji)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(mood.title)
                        .font(.bodyLarge)
                        .foregroundColor(isSelected ? .white : .textPrimary)

                    Text(mood.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding(20)
            .background(isSelected ? Color.focusGreen : Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }
}

/// Günlük ruh hali
enum DailyMood: String, CaseIterable, Identifiable, Codable {
    case energetic = "energetic"
    case normal = "normal"
    case tired = "tired"
    case scattered = "scattered"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .energetic: return "⚡️"
        case .normal: return "😊"
        case .tired: return "😴"
        case .scattered: return "🌀"
        }
    }

    var title: String {
        switch self {
        case .energetic: return "Enerjik"
        case .normal: return "Normal"
        case .tired: return "Yorgun"
        case .scattered: return "Dağınık"
        }
    }

    var description: String {
        switch self {
        case .energetic: return "Bugün çok enerjiyim, uzun süre odaklanabilirim"
        case .normal: return "Normal bir gün, dengeli çalışabilirim"
        case .tired: return "Biraz yorgunum, kısa seanslar daha iyi olur"
        case .scattered: return "Kafam dağınık, odaklanmakta zorlanıyorum"
        }
    }

    /// Bu mood için önerilen metod
    var recommendedMethod: FocusMethod {
        switch self {
        case .energetic: return .deepWork
        case .normal: return .optimal
        case .tired: return .pomodoro
        case .scattered: return .pomodoro
        }
    }

    /// Bu mood metod seçimini ne kadar etkiler (0.0 - 1.0)
    var methodInfluence: Double {
        switch self {
        case .energetic: return 0.8  // Güçlü etki
        case .normal: return 0.3     // Hafif etki
        case .tired: return 0.9      // Çok güçlü etki
        case .scattered: return 0.9  // Çok güçlü etki
        }
    }
}
