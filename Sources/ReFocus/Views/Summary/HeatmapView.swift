import SwiftUI

/// Haftalık/aylık retrospektif heatmap
/// Renk yoğunluğu = odak akışı kalitesi
/// Sayı ve karşılaştırma yok
struct HeatmapView: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var selectedPeriod: Period
    @State private var selectedDate: Date?
    /// 0 = güncel hafta/ay, -1 = bir önceki, ...
    @State private var periodOffset = 0

    init(sessionManager: SessionManager, initialPeriod: Period = .week) {
        self.sessionManager = sessionManager
        _selectedPeriod = State(initialValue: initialPeriod)
    }

    enum Period: CaseIterable {
        case week
        case month

        var label: String {
            switch self {
            case .week: return String(localized: "heatmap.period.week")
            case .month: return String(localized: "heatmap.period.month")
            }
        }
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
            .navigationTitle(String(localized: "heatmap.title"))
            .largeNavigationTitle()
            .onChange(of: selectedPeriod) { _, _ in
                periodOffset = 0
                selectedDate = nil
            }
        }
    }

    private var periodPicker: some View {
        Picker(String(localized: "heatmap.period"), selection: $selectedPeriod) {
            ForEach(Period.allCases, id: \.self) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 24)
    }

    private var heatmapGrid: some View {
        VStack(spacing: 8) {
            // Dönem gezintisi: önceki/sonraki hafta veya ay
            periodNavigator

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

            // Heatmap grid (nil = ay hizalaması için boş hücre)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(datesForPeriod.enumerated()), id: \.offset) { _, date in
                    if let date {
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
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
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

    private var periodNavigator: some View {
        HStack {
            Button {
                withAnimation {
                    periodOffset -= 1
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.appBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(periodTitle)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.textPrimary)

            Spacer()

            Button {
                withAnimation {
                    periodOffset += 1
                    selectedDate = nil
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.appBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(periodOffset >= 0)
            .opacity(periodOffset >= 0 ? 0.3 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }

    /// Gösterilen dönemin başlığı: "Temmuz 2026" veya "30 Haz – 6 Tem"
    private var periodTitle: String {
        switch selectedPeriod {
        case .month:
            return displayedMonthStart.formatted(.dateTime.month(.wide).year())
        case .week:
            let start = displayedWeekStart
            let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
            let startText = start.formatted(.dateTime.day().month(.abbreviated))
            let endText = end.formatted(.dateTime.day().month(.abbreviated))
            return "\(startText) – \(endText)"
        }
    }

    private var colorScale: some View {
        HStack(spacing: 8) {
            Text("heatmap.scale.low")
                .font(.caption)
                .foregroundColor(.textSecondary)

            HStack(spacing: 2) {
                ForEach([0.1, 0.3, 0.5, 0.7, 0.9], id: \.self) { quality in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForQuality(quality))
                        .frame(width: 16, height: 16)
                }
            }

            Text("heatmap.scale.high")
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
                    Text("heatmap.stat.quality")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // Toplam odak
                VStack(spacing: 4) {
                    Text("\(summary.totalFocusTime)")
                        .font(.heading2)
                        .foregroundColor(.focusGreen)
                    Text("heatmap.stat.focus_min")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // Bölünmeler
                VStack(spacing: 4) {
                    Text("\(totalInterruptions)")
                        .font(.heading2)
                        .foregroundColor(totalInterruptions > 0 ? .orange : .focusGreen)
                    Text("heatmap.stat.interruption")
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
                    Text("heatmap.total_interruption \(formatDuration(totalInterruptionDuration))")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
            }

            Divider()

            // Seans listesi
            VStack(spacing: 12) {
                Text("heatmap.sessions")
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

            Text("heatmap.empty.title")
                .font(.heading3)
                .foregroundColor(.textPrimary)

            Text("heatmap.empty.message")
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
        [
            String(localized: "heatmap.weekday.mon"),
            String(localized: "heatmap.weekday.tue"),
            String(localized: "heatmap.weekday.wed"),
            String(localized: "heatmap.weekday.thu"),
            String(localized: "heatmap.weekday.fri"),
            String(localized: "heatmap.weekday.sat"),
            String(localized: "heatmap.weekday.sun")
        ]
    }

    /// Gösterilen haftanın pazartesi başlangıcı (etiketler Pzt..Paz sıralı)
    private var displayedWeekStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) // 1 = Pazar
        let mondayOffset = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today) ?? today
        return calendar.date(byAdding: .day, value: periodOffset * 7, to: monday) ?? monday
    }

    /// Gösterilen ayın ilk günü
    private var displayedMonthStart: Date {
        let calendar = Calendar.current
        let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return calendar.date(byAdding: .month, value: periodOffset, to: thisMonth) ?? thisMonth
    }

    /// Grid hücreleri; ay görünümünde ilk haftanın hizalanması için
    /// baştaki boşluklar nil olarak döner
    private var datesForPeriod: [Date?] {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .week:
            let start = displayedWeekStart
            return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start) }

        case .month:
            let start = displayedMonthStart
            let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
            let weekday = calendar.component(.weekday, from: start)
            let leadingBlanks = (weekday + 5) % 7 // Pazartesi hizalı
            var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
            cells += (0..<dayCount).map { calendar.date(byAdding: .day, value: $0, to: start) }
            return cells
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
            return String(localized: "heatmap.encouragement.first_session")
        }

        if previousWeekSessions.isEmpty {
            return String(localized: "heatmap.encouragement.first_week")
        }

        if lastWeekAvg > prevWeekAvg {
            return String(localized: "heatmap.encouragement.improving")
        } else if lastWeekAvg < prevWeekAvg - 0.1 {
            return String(localized: "heatmap.encouragement.tough_week")
        }

        return String(localized: "heatmap.encouragement.stable")
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

                VStack(alignment: .leading, spacing: 2) {
                    // Çalışma bağlamı (varsa)
                    if let workContext = session.workContext, !workContext.isDefault {
                        HStack(spacing: 4) {
                            Text(workContext.icon)
                                .font(.caption)
                            Text(workContext.name)
                                .font(.caption)
                                .foregroundColor(.textPrimary)
                        }
                    }

                    Text(session.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }

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

            // Seans notu (varsa)
            if let note = session.sessionNote, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
            }

            // Progress bar
            SessionProgressBar(session: session)

            // Bölünme bilgisi
            if !session.interruptions.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 6, height: 6)
                    Text("heatmap.interruption_count \(session.interruptionCount)")
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

/// Heatmap hücresi - ayın gününü de gösterir
struct HeatmapCell: View {
    let date: Date
    let quality: Double?
    let isSelected: Bool

    private var isFuture: Bool {
        date > Date()
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: date))"
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(cellColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Text(dayNumber)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(quality != nil ? .white : .textTertiary)
                    .opacity(isFuture ? 0.35 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        isSelected ? Color.focusGreen
                        : Calendar.current.isDateInToday(date) ? Color.focusGreen.opacity(0.4)
                        : Color.clear,
                        lineWidth: isSelected ? 2 : 1
                    )
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
