import SwiftUI

/// Seans başlatırken çalışma bağlamı seçimi
/// Kompakt, yatay scroll edilebilir tasarım
struct WorkContextPickerView: View {
    @ObservedObject var contextManager: WorkContextManager
    @Binding var selectedContext: WorkContext?
    var onAddNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Başlık
            Text("workcontext.picker.title")
                .font(.bodyLarge)
                .foregroundColor(.textPrimary)

            #if os(macOS)
            // macOS: Wrap eden flow layout
            FlowLayout(spacing: 8) {
                // Mevcut context'ler
                ForEach(contextManager.getAllContexts()) { context in
                    WorkContextChip(
                        context: context,
                        isSelected: selectedContext?.id == context.id
                    ) {
                        selectedContext = context
                    }
                }

                // Yeni ekle butonu
                AddContextButton(action: onAddNew)
            }
            #else
            // iOS: Yatay scroll edilebilir context listesi
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Mevcut context'ler
                    ForEach(contextManager.getAllContexts()) { context in
                        WorkContextChip(
                            context: context,
                            isSelected: selectedContext?.id == context.id
                        ) {
                            HapticManager.shared.selection()
                            selectedContext = context
                        }
                    }

                    // Yeni ekle butonu
                    AddContextButton(action: onAddNew)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2) // Scroll için ekstra alan
            }
            .scrollClipDisabled() // Gölgelerin kesilmemesi için
            #endif

            // "Genel" seçiliyse veya hiç seçim yoksa açıklama
            if selectedContext == nil || selectedContext?.isDefault == true {
                Text("workcontext.picker.hint")
                    .font(.caption)
                    .foregroundColor(.textTertiary)
            }
        }
    }
}

/// Tekil context chip'i
struct WorkContextChip: View {
    let context: WorkContext
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(context.icon)
                    .font(.body)

                Text(context.name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.focusGreen : Color.cardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gray.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle()) // Tüm alan tıklanabilir
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "workcontext.accessibility.context \(context.name)"))
        .accessibilityHint(isSelected ? String(localized: "common.accessibility.selected") : String(localized: "common.accessibility.tap_to_select"))
    }
}

/// Yeni context ekleme butonu
struct AddContextButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.caption)

                Text("common.button.add")
                    .font(.caption)
            }
            .foregroundColor(.focusGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.focusGreen.opacity(0.1))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(String(localized: "workcontext.accessibility.add_new"))
    }
}

/// Kompakt context seçici (sadece icon gösterir, alan az olduğunda)
struct CompactWorkContextPicker: View {
    @ObservedObject var contextManager: WorkContextManager
    @Binding var selectedContext: WorkContext?
    @State private var showingPicker = false

    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack(spacing: 6) {
                Text(selectedContext?.icon ?? "🎯")
                    .font(.title3)

                Text(selectedContext?.name ?? String(localized: "workcontext.general"))
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingPicker) {
            WorkContextSelectionSheet(
                contextManager: contextManager,
                selectedContext: $selectedContext
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

/// Tam ekran context seçim sheet'i
struct WorkContextSelectionSheet: View {
    @ObservedObject var contextManager: WorkContextManager
    @Binding var selectedContext: WorkContext?
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddNew = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(contextManager.getAllContexts()) { context in
                        WorkContextGridItem(
                            context: context,
                            isSelected: selectedContext?.id == context.id
                        ) {
                            HapticManager.shared.selection()
                            selectedContext = context
                            dismiss()
                        }
                    }

                    // Yeni ekle
                    AddContextGridItem {
                        showingAddNew = true
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "workcontext.selection.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.button.cancel")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddNew) {
                AddWorkContextView(contextManager: contextManager) { newContext in
                    selectedContext = newContext
                    showingAddNew = false
                    dismiss()
                }
            }
        }
    }
}

/// Grid item for context selection
struct WorkContextGridItem: View {
    let context: WorkContext
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(context.icon)
                    .font(.system(size: 32))

                Text(context.name)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.focusGreen : Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected ? Color.clear : Color.gray.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Grid item for adding new context
struct AddContextGridItem: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.focusGreen)

                Text("workcontext.button.add_new")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.focusGreen.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.focusGreen.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Flow Layout (macOS için wrap eden layout)

#if os(macOS)
/// Wrap eden flow layout - öğeler sığmadığında alt satıra geçer
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            // Satıra sığmıyorsa yeni satıra geç
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + lineHeight

        return ArrangementResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }

    private struct ArrangementResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}
#endif
