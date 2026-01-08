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
            Text("Düşük")
                .font(.caption)
                .foregroundColor(.textSecondary)

            HStack(spacing: 2) {
                ForEach([0.1, 0.3, 0.5, 0.7, 0.9], id: \.self) { quality in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForQuality(quality))
                        .frame(width: 16, height: 16)
                }
            }

            Text("Yüksek")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.top, 8)
    }

    private func selectedDayDetail(summary: DailySummary) -> some View {
        let avgQuality = summary.sessions.reduce(0.0) { $0 + $1.focusFlowQuality } / Double(summary.sessions.count)
        let totalInterruptions = summary.sessions.reduce(0) { $0 + $1.interruptionCount }
        let totalInterruptionDuration = summary.sessions.reduce(0.0) { $0 + $1.totalInterruptionDuration }

        return VStack(spacing: 16) {
            // Başlık
            HStack {
                Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.heading3)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(statusEmoji(for: summary.dayStatus))
                    .font(.title2)
            }

            // Özet istatistikler
            HStack(spacing: 16) {
                // Odak kalitesi
                VStack(spacing: 4) {
                    Text("\(Int(avgQuality * 100))%")
                        .font(.heading2)
                        .foregroundColor(qualityColor(avgQuality))
                    Text("kalite")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // Toplam odak
                VStack(spacing: 4) {
                    Text("\(summary.totalFocusTime)")
                        .font(.heading2)
                        .foregroundColor(.focusGreen)
                    Text("dk odak")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // Bölünmeler
                VStack(spacing: 4) {
                    Text("\(totalInterruptions)")
                        .font(.heading2)
                        .foregroundColor(totalInterruptions > 0 ? .orange : .focusGreen)
                    Text("bölünme")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Bölünme süresi (varsa)
            if totalInterruptionDuration > 0 {
                HStack {
                    Circle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("Toplam bölünme: \(formatDuration(totalInterruptionDuration))")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
            }

            Divider()

            // Seans listesi
            VStack(spacing: 12) {
                Text("Seanslar")
                    .font(.captionBold)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(summary.sessions) { session in
                    HeatmapSessionRow(session: session)
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

    private func qualityColor(_ quality: Double) -> Color {
        if quality >= 0.8 {
            return .focusGreen
        } else if quality >= 0.5 {
            return .orange
        } else {
            return .orange.opacity(0.7)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)dk \(seconds)sn"
        } else {
            return "\(seconds)sn"
        }
    }

    private var encouragementMessage: some View {
        Group {
            let message = getEncouragementMessage()
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

    /// Hiç seans yoksa gösterilecek boş durum
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Text("🌱")
                .font(.system(size: 48))

            Text("Henüz yeterli verin yok")
                .font(.heading3)
                .foregroundColor(.textPrimary)

            Text("Birkaç seans tamamladıktan sonra\nburada güzel bir görselleştirme olacak.")
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
        .padding(.horizontal, 24)
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
        // Kaliteye göre renk skalası
        if quality >= 0.8 {
            return Color.focusGreen.opacity(0.9)
        } else if quality >= 0.6 {
            return Color.focusGreen.opacity(0.6)
        } else if quality >= 0.4 {
            return Color.orange.opacity(0.5)
        } else if quality >= 0.2 {
            return Color.orange.opacity(0.7)
        } else {
            return Color.orange.opacity(0.3)
        }
    }

    private func statusEmoji(for status: DailySummary.DayStatus) -> String {
        switch status {
        case .stable: return "✨"
        case .fluctuating: return "🌊"
        case .tough: return "💪"
        }
    }

    private func getEncouragementMessage() -> String {
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
            return "İlk seansını tamamladığında burada güzel istatistikler göreceksin."
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

    /// Hiç seans olup olmadığını kontrol et
    private var hasAnySessions: Bool {
        !sessionManager.getAllSessions().isEmpty
    }
}

/// Heatmap'teki seans satırı
struct HeatmapSessionRow: View {
    let session: FocusSession

    private var plannedDuration: Double {
        Double(session.method.focusDuration * 60)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(session.method.icon)
                    .font(.body)

                Text(session.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                Spacer()

                // Kalite yüzdesi
                Text("\(Int(session.focusFlowQuality * 100))%")
                    .font(.caption)
                    .foregroundColor(session.focusFlowQuality >= 0.8 ? .focusGreen : .orange)

                // Süre
                Text("\(Int(session.totalFocusDuration / 60))dk")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            // Progress bar
            SessionProgressBar(session: session)

            // Bölünme bilgisi
            if !session.interruptions.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text("\(session.interruptionCount) bölünme")
                        .font(.system(size: 10))
                        .foregroundColor(.textTertiary)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.appBackground)
        .cornerRadius(10)
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
        // Kaliteye göre renk skalası
        if quality >= 0.8 {
            return Color.focusGreen.opacity(0.9)
        } else if quality >= 0.6 {
            return Color.focusGreen.opacity(0.6)
        } else if quality >= 0.4 {
            return Color.orange.opacity(0.5)
        } else if quality >= 0.2 {
            return Color.orange.opacity(0.7)
        } else {
            return Color.orange.opacity(0.3)
        }
    }
}
