import WidgetKit
import SwiftUI

/// Kadran komplikasyonu: aktif seansta kalan süreyi sayar,
/// boşta uygulamaya sakin bir kısayol olur.
/// Veri, watch uygulamasından app group üzerinden gelir.

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
            // Faz bitince kadran kendiliğinden boş duruma döner
            entries.append(PhaseEntry(date: end, phaseEnd: nil, isBreak: false))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PhaseEntry

    private let focusGreen = Color(red: 0.31, green: 0.64, blue: 0.58)

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                if let end = entry.phaseEnd {
                    Text(timerInterval: entry.date...end, countsDown: true)
                } else {
                    Text("ReFocus")
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
                            .foregroundStyle(entry.isBreak ? Color.blue : focusGreen)
                    } else {
                        Text("ReFocus")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Image(systemName: "circle.circle")
                            .foregroundStyle(focusGreen)
                    }
                }

            default: // accessoryCircular, accessoryCorner
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
                    .tint(entry.isBreak ? Color.blue : focusGreen)
                } else {
                    Image(systemName: "circle.circle")
                        .font(.title2)
                        .foregroundStyle(focusGreen)
                }
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

@main
struct ReFocusComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ReFocusComplication", provider: PhaseProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("ReFocus")
        .supportedFamilies([.accessoryCircular, .accessoryCorner,
                            .accessoryInline, .accessoryRectangular])
    }
}
