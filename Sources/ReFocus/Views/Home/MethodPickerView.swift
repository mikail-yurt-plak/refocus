import SwiftUI

/// Manuel metod seçimi için picker view
struct MethodPickerView: View {
    @Binding var selectedMethod: FocusMethod?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Başlık
                        VStack(spacing: 8) {
                            Text("methodpicker.title")
                                .font(.heading2)
                                .foregroundColor(.textPrimary)

                            Text("methodpicker.subtitle")
                                .font(.body)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, 16)

                        // Metod kartları
                        VStack(spacing: 16) {
                            ForEach(FocusMethod.allCases, id: \.self) { method in
                                MethodCard(
                                    method: method,
                                    isSelected: selectedMethod == method,
                                    action: {
                                        selectedMethod = method
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
            }
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailingCompat) {
                    Button(String(localized: "common.button.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

/// Metod kartı
struct MethodCard: View {
    let method: FocusMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // İkon
                    Text(method.icon)
                        .font(.system(size: 40))

                    VStack(alignment: .leading, spacing: 4) {
                        // Metod adı
                        Text(method.rawValue)
                            .font(.heading3)
                            .foregroundColor(isSelected ? .white : .textPrimary)

                        // Süre bilgisi
                        Text("common.duration_format \(method.focusDuration) \(method.breakDuration)")
                            .font(.bodySmall)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .textSecondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                }

                // Açıklama
                Text(method.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .textTertiary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .background(isSelected ? Color.focusGreen : Color.cardBackground)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }
}

#Preview {
    MethodPickerView(selectedMethod: .constant(.pomodoro))
}
