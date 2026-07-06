import SwiftUI

/// Yeni çalışma bağlamı ekleme ekranı
/// Icon seçimi çok önemli - kullanıcı kolayca emoji seçebilmeli
struct AddWorkContextView: View {
    @ObservedObject var contextManager: WorkContextManager
    var onAdd: (WorkContext) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = "🎯"
    @FocusState private var isNameFocused: Bool

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !contextManager.hasContext(named: name)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Önizleme
                    previewSection

                    // İsim girişi
                    nameInputSection

                    // Icon seçimi
                    iconSelectionSection
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(String(localized: "workcontext.add.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.button.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.button.add")) {
                        addContext()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }

    private var previewSection: some View {
        VStack(spacing: 12) {
            Text(selectedIcon)
                .font(.system(size: 64))

            Text(name.isEmpty ? String(localized: "workcontext.add.name_placeholder") : name)
                .font(.heading3)
                .foregroundColor(name.isEmpty ? .textTertiary : .textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("workcontext.add.name_label")
                .font(.caption)
                .foregroundColor(.textSecondary)

            TextField(String(localized: "workcontext.add.name_example"), text: $name)
                .textFieldStyle(.plain)
                .font(.body)
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(12)
                .focused($isNameFocused)
                .submitLabel(.done)

            if contextManager.hasContext(named: name) && !name.isEmpty {
                Text("workcontext.add.name_exists")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var iconSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("workcontext.add.select_icon")
                .font(.caption)
                .foregroundColor(.textSecondary)

            // Kategorilere göre icon grupları
            ForEach(IconCategory.categories) { category in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category.name)
                        .font(.caption2)
                        .foregroundColor(.textTertiary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(category.icons, id: \.self) { icon in
                            IconButton(
                                icon: icon,
                                isSelected: selectedIcon == icon
                            ) {
                                HapticManager.shared.selection()
                                selectedIcon = icon
                            }
                        }
                    }
                }
                .padding()
                .background(Color.cardBackground)
                .cornerRadius(16)
            }
        }
    }

    private func addContext() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newContext = WorkContext(name: trimmedName, icon: selectedIcon)
        contextManager.addContext(newContext)
        HapticManager.shared.success()
        onAdd(newContext)
    }
}

/// Tekil icon seçim butonu
struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(icon)
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.focusGreen.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isSelected ? Color.focusGreen : Color.clear,
                            lineWidth: 2
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(icon)
        .accessibilityHint(isSelected ? String(localized: "common.accessibility.selected") : String(localized: "common.accessibility.tap_to_select"))
    }
}
