import SwiftUI

/// Çalışma bağlamlarını yönetme ekranı
/// Ayarlar veya profil sayfasından erişilebilir
struct WorkContextManagementView: View {
    @ObservedObject var contextManager: WorkContextManager
    @State private var showingAddNew = false
    @State private var editingContext: WorkContext?
    @State private var showingDeleteConfirmation = false
    @State private var contextToDelete: WorkContext?

    var body: some View {
        List {
            // Varsayılan "Genel" context (silinemez)
            Section {
                WorkContextRow(context: .general, isDefault: true)
            } header: {
                Text("workcontext.section.default")
            }

            // Kullanıcının eklediği context'ler
            if !contextManager.contexts.filter({ !$0.isDefault }).isEmpty {
                Section {
                    ForEach(contextManager.contexts.filter { !$0.isDefault }) { context in
                        WorkContextRow(context: context, isDefault: false)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    contextToDelete = context
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label(String(localized: "common.button.delete"), systemImage: "trash")
                                }

                                Button {
                                    editingContext = context
                                } label: {
                                    Label(String(localized: "common.button.edit"), systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                    }
                    .onMove { source, destination in
                        contextManager.moveContexts(from: source, to: destination)
                        HapticManager.shared.selection()
                    }
                } header: {
                    Text("workcontext.section.my_contexts")
                } footer: {
                    Text("workcontext.section.reorder_hint")
                }
            }

            // Yeni ekle
            Section {
                Button(action: { showingAddNew = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.focusGreen)

                        Text("workcontext.button.add_new")
                            .foregroundColor(.focusGreen)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "workcontext.management.title"))
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAddNew) {
            AddWorkContextView(contextManager: contextManager) { _ in
                showingAddNew = false
            }
        }
        .sheet(item: $editingContext) { context in
            EditWorkContextView(contextManager: contextManager, context: context) {
                editingContext = nil
            }
        }
        .alert(String(localized: "workcontext.delete.title"), isPresented: $showingDeleteConfirmation) {
            Button(String(localized: "common.button.cancel"), role: .cancel) {
                contextToDelete = nil
            }
            Button(String(localized: "common.button.delete"), role: .destructive) {
                if let context = contextToDelete {
                    contextManager.deleteContext(context)
                }
                contextToDelete = nil
            }
        } message: {
            if let context = contextToDelete {
                Text("workcontext.delete.message \(context.name)")
            }
        }
    }
}

/// Context satırı
struct WorkContextRow: View {
    let context: WorkContext
    let isDefault: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(context.icon)
                .font(.title2)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.name)
                    .font(.body)
                    .foregroundColor(.textPrimary)

                if isDefault {
                    Text("workcontext.row.default_label")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
            }

            Spacer()

            if isDefault {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Context düzenleme ekranı
struct EditWorkContextView: View {
    @ObservedObject var contextManager: WorkContextManager
    let context: WorkContext
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedIcon: String = ""

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        // Aynı isim başka bir context'te var mı?
        let existingWithSameName = contextManager.getAllContexts().first {
            $0.id != context.id && $0.name.lowercased() == trimmedName.lowercased()
        }
        return existingWithSameName == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Önizleme
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

                    // İsim girişi
                    VStack(alignment: .leading, spacing: 8) {
                        Text("workcontext.add.name_label")
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        TextField(String(localized: "workcontext.add.name_placeholder"), text: $name)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                    }

                    // Icon seçimi
                    VStack(alignment: .leading, spacing: 12) {
                        Text("workcontext.add.select_icon")
                            .font(.caption)
                            .foregroundColor(.textSecondary)

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
                .padding()
            }
            .background(Color.appBackground)
            .navigationTitle(String(localized: "workcontext.edit.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.button.cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.button.save")) {
                        saveChanges()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                name = context.name
                selectedIcon = context.icon
            }
        }
    }

    private func saveChanges() {
        var updatedContext = context
        updatedContext.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedContext.icon = selectedIcon
        contextManager.updateContext(updatedContext)
        HapticManager.shared.success()
        onDone()
        dismiss()
    }
}
