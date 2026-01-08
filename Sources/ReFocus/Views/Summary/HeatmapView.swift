import SwiftUI

/// Haftalık/aylık retrospektif heatmap
/// Renk yoğunluğu = odak akışı kalitesi
/// Sayı ve karşılaştırma yok
struct HeatmapView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedPeriod: Period = .week
    @State private var selectedDate: Date?

    enum Period: String, CaseIterable {
        case week = "Hafta"
        case month = "Ay"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Periyod seçici
                        periodPicker

                        // Heatmap
                        heatmapGrid

                        // Seçili gün detayı
                        if let date = selectedDate,
                           let summary = sessionManager.getDailySummary(for: date) {
                            selectedDayDetail(summary: summary)
                        }

                        // Genel mesaj
                        encouragementMessage

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Geçmişin")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var periodPicker: some View {
        Picker("Periyod", selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }

    private var heatmapGrid: some View {
        VStack(spacing: 8) {
            // Gün etiketleri
            HStack(spacing: 4) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 24)

            // Heatmap grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(datesForPeriod, id: \.self) { date in
                    HeatmapCell(
                        date: date,
                        quality: getQualityForDate(date),
                        isSelected: selectedDate == date
                    )
                    .onTapGesture {
                        withAnimation {
                            if selectedDate == date {
                                selectedDate = nil
                            } else {
                                selectedDate = date
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            // Renk skalası
            colorScale
        }
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
        .padding(.horizontal, 24)
    }

    private var colorScale: some View {
        HStack(spacing: 8) {
            Text("Az")
                .font(.caption)
                .foregroundColor(.textSecondary)

            HStack(spacing: 2) {
                ForEach([0.1, 0.3, 0.5, 0.7, 0.9], id: \.self) { quality in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForQuality(quality))
                        .frame(width: 16, height: 16)
                }
            }

            Text("Çok")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.top, 8)
    }

    private func selectedDayDetail(summary: DailySummary) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.heading3)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(statusEmoji(for: summary.dayStatus))
                    .font(.title2)
            }

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(summary.totalFocusTime)")
                        .font(.heading2)
                        .foregroundColor(.focusGreen)
                    Text("dakika")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                VStack(spacing: 4) {
                    Text("\(summary.sessions.count)")
                        .font(.heading2)
                        .foregroundColor(.focusGreen)
                    Text("seans")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

                if let method = summary.mostUsedMethod {
                    VStack(spacing: 4) {
                        Text(method.icon)
                            .font(.heading2)
                        Text(method.rawValue)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var encouragementMessage: some View {
        Group {
            if let message = getEncouragementMessage() {
                Text(message)
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color.gentleWarning.opacity(0.3))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Helper Functions

    private var weekdayLabels: [String] {
        ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    }

    private var datesForPeriod: [Date] {
        let calendar = Calendar.current
        let today = Date()

        switch selectedPeriod {
        case .week:
            return (0..<7).compactMap { offset in
                calendar.date(byAdding: .day, value: -6 + offset, to: today)
            }
        case .month:
            return (0..<28).compactMap { offset in
                calendar.date(byAdding: .day, value: -27 + offset, to: today)
            }
        }
    }

    private func getQualityForDate(_ date: Date) -> Double? {
        guard let summary = sessionManager.getDailySummary(for: date) else {
            return nil
        }
        let avgQuality = summary.sessions.reduce(0.0) { $0 + $1.focusFlowQuality } / Double(summary.sessions.count)
        return avgQuality
    }

    private func colorForQuality(_ quality: Double) -> Color {
        Color.focusGreen.opacity(quality)
    }

    private func statusEmoji(for status: DailySummary.DayStatus) -> String {
        switch status {
        case .stable: return "🟢"
        case .fluctuating: return "🟡"
        case .tough: return "🔵"
        }
    }

    private func getEncouragementMessage() -> String? {
        let sessions = sessionManager.getAllSessions()
        let lastWeekSessions = sessions.filter {
            $0.startTime > Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }
        let previousWeekSessions = sessions.filter {
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
            return $0.startTime > twoWeeksAgo && $0.startTime <= weekAgo
        }

        let lastWeekAvg = lastWeekSessions.reduce(0.0) { $0 + $1.focusFlowQuality } / Double(max(1, lastWeekSessions.count))
        let prevWeekAvg = previousWeekSessions.reduce(0.0) { $0 + $1.focusFlowQuality } / Double(max(1, previousWeekSessions.count))

        if lastWeekSessions.isEmpty {
            return nil
        }

        if previousWeekSessions.isEmpty {
            return "İlk haftanı tamamladın. Devam et!"
        }

        if lastWeekAvg > prevWeekAvg {
            return "Geçen haftaya göre daha iyi odaklanıyorsun."
        } else if lastWeekAvg < prevWeekAvg - 0.1 {
            return "Bu hafta biraz daha zordu. Bu normal, herkesin böyle haftaları olur."
        }

        return "İstikrarlı bir tempo yakaladın."
    }
}

/// Heatmap hücresi
struct HeatmapCell: View {
    let date: Date
    let quality: Double?
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(cellColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color.focusGreen : Color.clear, lineWidth: 2)
            )
    }

    private var cellColor: Color {
        guard let quality = quality else {
            return Color.gray.opacity(0.1)
        }
        return Color.focusGreen.opacity(max(0.1, quality))
    }
}
