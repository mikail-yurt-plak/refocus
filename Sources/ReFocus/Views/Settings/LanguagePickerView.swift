import SwiftUI

/// Dil seçimi ekranı - sistem dili veya desteklenen 20 dilden biri
struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showingRestartNote = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        languageRow(code: nil, name: String(localized: "language.system"))

                        ForEach(LanguageManager.supportedLanguages, id: \.code) { language in
                            languageRow(code: language.code, name: language.nativeName)
                        }

                        if showingRestartNote {
                            Text("language.restart_note")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gentleWarning)
                                .cornerRadius(12)
                                .transition(.opacity)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(Text("language.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button(String(localized: "common.button.close")) {
                        dismiss()
                    }
                    .foregroundColor(.focusGreen)
                }
            }
        }
    }

    private func languageRow(code: String?, name: String) -> some View {
        let isSelected = languageManager.selectedCode == code

        return Button {
            guard !isSelected else { return }
            languageManager.select(code)
            withAnimation(.easeInOut) {
                showingRestartNote = true
            }
        } label: {
            HStack {
                Text(name)
                    .font(.body)
                    .foregroundColor(.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.focusGreen)
                }
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguagePickerView()
}
