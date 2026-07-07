import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Ortak sağlayıcı (app group beslemesi)

struct PhaseEntry: TimelineEntry {
    let date: Date
    let phaseEnd: Date?
    let isBreak: Bool
}

struct PhaseProvider: TimelineProvider {
    private static let appGroup = "group.com.mikailyurt.refocus"

    private func currentState() -> (end: Date?, isBreak: Bool) {
        guard let defaults = UserDefaults(suiteName: Self.appGroup),
              defaults.object(forKey: "phaseEnd") != nil else {
            return (nil, false)
        }
        let end = Date(timeIntervalSince1970: defaults.double(forKey: "phaseEnd"))
        guard end > Date() else { return (nil, false) }
        return (end, defaults.bool(forKey: "isBreak"))
    }

    func placeholder(in context: Context) -> PhaseEntry {
        PhaseEntry(date: Date(), phaseEnd: Date().addingTimeInterval(25 * 60), isBreak: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (PhaseEntry) -> Void) {
        let state = currentState()
        completion(PhaseEntry(date: Date(), phaseEnd: state.end, isBreak: state.isBreak))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhaseEntry>) -> Void) {
        let state = currentState()
        var entries = [PhaseEntry(date: Date(), phaseEnd: state.end, isBreak: state.isBreak)]
        if let end = state.end {
            entries.append(PhaseEntry(date: end, phaseEnd: nil, isBreak: false))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
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
                        Text("home.start_session")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
                    } else {
                        Image(systemName: "circle.circle")
                            .font(.system(size: 34))
                            .foregroundStyle(focusGreen)
                        Text("home.start_session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

struct ReFocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReFocusWidget", provider: PhaseProvider()) { entry in
            ReFocusWidgetView(entry: entry)
        }
        .configurationDisplayName("ReFocus")
        .supportedFamilies([.systemSmall, .accessoryCircular,
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
                    .frame(maxWidth: 120)
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
                        .frame(maxWidth: 100)
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
                    .frame(maxWidth: 44)
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
