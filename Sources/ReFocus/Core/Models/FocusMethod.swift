import Foundation

/// Odak metodları - 4 farklı zaman yönetimi tekniği
enum FocusMethod: String, Codable, CaseIterable {
    case pomodoro = "Pomodoro"
    case extended = "40/10"
    case optimal = "52/17"
    case deepWork = "Deep Work"

    /// Odak süresi (dakika)
    var focusDuration: Int {
        switch self {
        case .pomodoro: return 25
        case .extended: return 40
        case .optimal: return 52
        case .deepWork: return 90
        }
    }

    /// Mola süresi (dakika)
    var breakDuration: Int {
        switch self {
        case .pomodoro: return 5
        case .extended: return 10
        case .optimal: return 17
        case .deepWork: return 15
        }
    }

    /// Kullanıcıya gösterilen açıklama (localized)
    var description: String {
        switch self {
        case .pomodoro:
            return String(localized: "method.description.pomodoro")
        case .extended:
            return String(localized: "method.description.extended")
        case .optimal:
            return String(localized: "method.description.optimal")
        case .deepWork:
            return String(localized: "method.description.deep_work")
        }
    }

    /// İkon/emoji gösterimi
    var icon: String {
        switch self {
        case .pomodoro: return "🍅"
        case .extended: return "⏱️"
        case .optimal: return "⚡️"
        case .deepWork: return "🎯"
        }
    }

    /// Toplam döngü süresi (fokus + mola)
    var totalCycleDuration: Int {
        return focusDuration + breakDuration
    }
}
