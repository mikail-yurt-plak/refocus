import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Ortak sağlayıcı (app group beslemesi)

struct PhaseEntry: TimelineEntry {
    let date: Date
    let phaseEnd: Date?
    let isBreak: Bool
    let todayMinutes: Int
    let weekMinutes: Int
    let monthMinutes: Int
}

struct PhaseProvider: TimelineProvider {
    private static let appGroup = "group.com.mikailyurt.refocus"

    private func mondayOf(_ date: Date, _ calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        return calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day) ?? day
    }

    private func read() -> PhaseEntry {
        let now = Date()
        guard let defaults = UserDefaults(suiteName: Self.appGroup) else {
            return PhaseEntry(date: now, phaseEnd: nil, isBreak: false,
                              todayMinutes: 0, weekMinutes: 0, monthMinutes: 0)
        }

        var end: Date?
        if defaults.object(forKey: "phaseEnd") != nil {
            let candidate = Date(timeIntervalSince1970: defaults.double(forKey: "phaseEnd"))
            if candidate > now { end = candidate }
        }

        // Dönem devrilme kontrolü: veriler en son yazıldığı günün damgasını taşır.
        // Gün/hafta/ay o günden beri değiştiyse ilgili sayaç sıfır kabul edilir.
        let calendar = Calendar.current
        let stamp = Date(timeIntervalSince1970: defaults.double(forKey: "todayStamp"))
        let sameDay = calendar.isDate(stamp, inSameDayAs: now)
        let sameWeek = mondayOf(stamp, calendar) == mondayOf(now, calendar)
        let sameMonth = calendar.isDate(stamp, equalTo: now, toGranularity: .month)

        return PhaseEntry(
            date: now,
            phaseEnd: end,
            isBreak: defaults.bool(forKey: "isBreak"),
            todayMinutes: sameDay ? defaults.integer(forKey: "todayMinutes") : 0,
            weekMinutes: sameWeek ? defaults.integer(forKey: "weekMinutes") : 0,
            monthMinutes: sameMonth ? defaults.integer(forKey: "monthMinutes") : 0
        )
    }

    func placeholder(in context: Context) -> PhaseEntry {
        PhaseEntry(date: Date(), phaseEnd: Date().addingTimeInterval(25 * 60), isBreak: false,
                   todayMinutes: 62, weekMinutes: 240, monthMinutes: 890)
    }

    func getSnapshot(in context: Context, completion: @escaping (PhaseEntry) -> Void) {
        completion(read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhaseEntry>) -> Void) {
        let entry = read()
        var entries = [entry]

        if let end = entry.phaseEnd {
            // Faz bitince boş duruma dön (istatistikler korunur)
            entries.append(PhaseEntry(date: end, phaseEnd: nil, isBreak: false,
                                      todayMinutes: entry.todayMinutes,
                                      weekMinutes: entry.weekMinutes,
                                      monthMinutes: entry.monthMinutes))
        }

        // Gece yarısı yenile: "Bugün" sayacı yeni güne sıfırlansın
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        completion(Timeline(entries: entries, policy: .after(entry.phaseEnd ?? midnight)))
    }
}

// MARK: - Widget görünümleri

private let focusGreen = Color(red: 0.18, green: 0.49, blue: 0.44)
private let focusGreenLight = Color(red: 0.31, green: 0.64, blue: 0.58)

struct ReFocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PhaseEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let end = entry.phaseEnd {
                    Text(timerInterval: entry.date...end, countsDown: true)
                } else {
                    Text("ReFocus")
                }

            case .accessoryCircular:
                if let end = entry.phaseEnd {
                    ProgressView(timerInterval: entry.date...end, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        Text(timerInterval: entry.date...end, countsDown: true)
                            .font(.system(size: 12, weight: .medium))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                    }
                    .progressViewStyle(.circular)
                } else {
                    Image(systemName: "circle.circle")
                        .font(.title2)
                }

            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    if let end = entry.phaseEnd {
                        Text(entry.isBreak ? "common.label.break" : "common.label.focus")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(timerInterval: entry.date...end, countsDown: true)
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                    } else {
                        Text("ReFocus")
                            .font(.headline)
                        statLine(labelKey: "friends.today", minutes: entry.todayMinutes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        statLine(labelKey: "home.this_week", minutes: entry.weekMinutes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

            case .systemMedium:
                HStack(spacing: 16) {
                    if let end = entry.phaseEnd {
                        VStack(spacing: 4) {
                            Text(entry.isBreak ? "common.label.break" : "common.label.focus")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(timerInterval: entry.date...end, countsDown: true)
                                .font(.system(size: 34, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(entry.isBreak ? Color.blue : focusGreen)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        Divider()
                    }
                    statsColumn
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            default: // systemSmall — ana ekran
                VStack(spacing: 6) {
                    if let end = entry.phaseEnd {
                        Text(entry.isBreak ? "common.label.break" : "common.label.focus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timerInterval: entry.date...end, countsDown: true)
                            .font(.system(size: 32, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(entry.isBreak ? Color.blue : focusGreen)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)
                        statLine(labelKey: "friends.today", minutes: entry.todayMinutes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        statsColumn
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    /// "Bugün  62 dk" biçiminde tek istatistik satırı
    private func statLine(labelKey: LocalizedStringKey, minutes: Int) -> some View {
        HStack(spacing: 4) {
            Text(labelKey)
            Spacer(minLength: 8)
            Text(String(format: String(localized: "common.minutes_format"), minutes))
                .monospacedDigit()
                .fontWeight(.medium)
        }
    }

    /// Bugün / Bu Hafta / Bu Ay sütunu (boş durum ve orta boy için)
    private var statsColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "circle.circle")
                    .foregroundStyle(focusGreen)
                Text("ReFocus")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .padding(.bottom, 1)

            statLine(labelKey: "friends.today", minutes: entry.todayMinutes)
                .font(.caption2)
            statLine(labelKey: "home.this_week", minutes: entry.weekMinutes)
                .font(.caption2)
                .foregroundStyle(.secondary)
            statLine(labelKey: "common.this_month", minutes: entry.monthMinutes)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ReFocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReFocusWidget", provider: PhaseProvider()) { entry in
            ReFocusWidgetView(entry: entry)
        }
        .configurationDisplayName("ReFocus")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular,
                            .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Live Activity (Dynamic Island + kilit ekranı)

struct ReFocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            // Kilit ekranı kartı
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.methodName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(context.state.isBreak ? "common.label.break" : "common.label.focus")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(timerInterval: Date.now...max(Date.now, context.state.endDate),
                     countsDown: true)
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(context.state.isBreak ? Color.blue : focusGreenLight)
                    .frame(maxWidth: 170)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))

        } dynamicIsland: { context in
            DynamicIsland {
                // Genişletilmiş görünüm (basılı tutunca)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.methodName)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(context.state.isBreak ? "common.label.break" : "common.label.focus")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(Date.now, context.state.endDate),
                         countsDown: true)
                        .font(.system(size: 30, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(context.state.isBreak ? Color.blue : focusGreenLight)
                        .frame(maxWidth: 140)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.trailing)
                        .padding(.trailing, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "circle.circle")
                    .foregroundStyle(context.state.isBreak ? Color.blue : focusGreenLight)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(Date.now, context.state.endDate),
                     countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(context.state.isBreak ? Color.blue : focusGreenLight)
                    .frame(maxWidth: 52)
                    .minimumScaleFactor(0.8)
            } minimal: {
                Image(systemName: "circle.circle")
                    .foregroundStyle(focusGreenLight)
            }
        }
    }
}

// MARK: - Paket

@main
struct ReFocusWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReFocusWidget()
        ReFocusLiveActivity()
    }
}
