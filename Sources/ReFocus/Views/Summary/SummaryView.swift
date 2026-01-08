import SwiftUI

/// Gün sonu özet ekranı
struct SummaryView: View {
    let summary: DailySummary
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Başlık ve durum
                        headerSection

                        // İstatistikler
                        statsSection

                        // Odak akışı görselleştirmesi
                        focusFlowSection

                        // Yarın için öneri
                        tomorrowSection

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Günün Özeti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Durum ikonu
            Text(statusIcon)
                .font(.system(size: 64))

            // Durum mesajı
            Text(statusMessage)
                .font(.heading2)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            // Tarih
            Text(summary.date.formatted(date: .long, time: .omitted))
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 24)
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            // Toplam odak süresi
            StatBox(
                value: "\(summary.totalFocusTime)",
                unit: "dk",
                label: "Toplam Odak"
            )

            // Seans sayısı
            StatBox(
                value: "\(summary.sessions.count)",
                unit: "",
                label: "Seans"
            )

            // En çok kullanılan metod
            if let method = summary.mostUsedMethod {
                StatBox(
                    value: method.icon,
                    unit: "",
                    label: method.rawValue
                )
            }
        }
        .padding(.horizontal, 24)
    }

    private var focusFlowSection: some View {
        VStack(spacing: 16) {
            Text("Seansların")
                .font(.heading3)
                .foregroundColor(.textPrimary)

            VStack(spacing: 12) {
                ForEach(summary.sessions) { session in
                    SessionFlowRow(session: session)
                }
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
        .padding(.horizontal, 24)
    }

    private var tomorrowSection: some View {
        VStack(spacing: 16) {
            Text("Yarın için")
                .font(.caption)
                .foregroundColor(.textSecondary)

            Text(tomorrowMessage)
                .font(.body)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.gentleWarning.opacity(0.3))
        .cornerRadius(16)
        .padding(.horizontal, 24)
    }

    // MARK: - Computed Properties

    private var statusIcon: String {
        switch summary.dayStatus {
        case .stable: return "🟢"
        case .fluctuating: return "🟡"
        case .tough: return "🔵"
        }
    }

    private var statusMessage: String {
        switch summary.dayStatus {
        case .stable:
            return "Stabil bir gün geçirdin"
        case .fluctuating:
            return "Dalgalı bir gündü"
        case .tough:
            return "Zor bir gündü, ama bitirdin"
        }
    }

    private var tomorrowMessage: String {
        switch summary.dayStatus {
        case .stable:
            return "Bu tempoyu sürdür. Yarın da aynı metotla devam edebilirsin."
        case .fluctuating:
            return "Yarın daha kısa seanslarla başlamayı deneyebilirsin."
        case .tough:
            return "Yarın yeni bir başlangıç. Her gün farklı, bu normal."
        }
    }
}

/// İstatistik kutusu
struct StatBox: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.heading1)
                    .foregroundColor(.focusGreen)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

/// Seans akış satırı
struct SessionFlowRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
            // Metod ikonu
            Text(session.method.icon)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                // Saat
                Text(session.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                // Odak akışı
                Text(InterruptionTracker.generateFocusFlowVisualization(for: session))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            // Süre
            Text("\(Int(session.totalFocusDuration / 60)) dk")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, 8)
    }
}
