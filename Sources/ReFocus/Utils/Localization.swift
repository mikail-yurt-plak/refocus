import SwiftUI

// MARK: - Localization Helper Extensions

/// String extension for easy localization access
extension String {
    /// Returns the localized version of this string key
    var localized: String {
        String(localized: String.LocalizationValue(self))
    }

    /// Returns localized string with format arguments
    func localized(_ args: CVarArg...) -> String {
        String(format: self.localized, arguments: args)
    }
}

/// LocalizedStringKey extension for dynamic key creation
extension LocalizedStringKey {
    /// Initialize with a dynamic string key
    static func dynamic(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(key)
    }
}

// MARK: - Language Manager

/// Uygulama dili seçimini yöneten sınıf.
/// Seçim "AppleLanguages" üzerinden yapılır; değişiklik uygulama
/// yeniden başlatıldığında etkinleşir (tüm String(localized:) ve
/// Text çağrılarıyla uyumlu, en güvenilir yöntem).
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private static let overrideKey = "app.selectedLanguage"

    /// Seçili dil kodu; nil = sistem dili
    @Published private(set) var selectedCode: String?

    private init() {
        selectedCode = UserDefaults.standard.string(forKey: Self.overrideKey)
    }

    /// Desteklenen diller (katalogdaki 20 dil), kendi dillerindeki adlarıyla
    static let supportedLanguages: [(code: String, nativeName: String)] = [
        ("tr", "Türkçe"),
        ("en", "English"),
        ("ar", "العربية"),
        ("de", "Deutsch"),
        ("es", "Español"),
        ("fr", "Français"),
        ("hi", "हिन्दी"),
        ("id", "Bahasa Indonesia"),
        ("it", "Italiano"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("nl", "Nederlands"),
        ("pl", "Polski"),
        ("pt", "Português"),
        ("ru", "Русский"),
        ("th", "ไทย"),
        ("uk", "Українська"),
        ("vi", "Tiếng Việt"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文")
    ]

    /// Dili seç; nil sistem diline döndürür
    func select(_ code: String?) {
        selectedCode = code
        let defaults = UserDefaults.standard
        if let code {
            defaults.set(code, forKey: Self.overrideKey)
            defaults.set([code], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: Self.overrideKey)
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}

// MARK: - Localization Keys

/// Centralized localization key constants
/// Usage: Text(L10n.Home.greeting)
enum L10n {
    // MARK: - Common
    enum Common {
        enum Button {
            static let start = "common.button.start"
            static let back = "common.button.back"
            static let next = "common.button.next"
            static let skip = "common.button.skip"
            static let complete = "common.button.complete"
            static let close = "common.button.close"
            static let cancel = "common.button.cancel"
            static let `continue` = "common.button.continue"
            static let change = "common.button.change"
            static let add = "common.button.add"
            static let end = "common.button.end"
        }

        enum Label {
            static let focus = "common.label.focus"
            static let `break` = "common.label.break"
            static let session = "common.label.session"
            static let minutes = "common.label.minutes"
            static let seconds = "common.label.seconds"
            static let optional = "common.label.optional"
            static let quality = "common.label.quality"
            static let interruption = "common.label.interruption"
            static let remaining = "common.label.remaining"
            static let total = "common.label.total"
        }
    }

    // MARK: - Home Screen
    enum Home {
        enum Greeting {
            static let morning = "home.greeting.morning"
            static let afternoon = "home.greeting.afternoon"
            static let evening = "home.greeting.evening"
            static let `default` = "home.greeting.default"
        }

        static let todayFocusTime = "home.today_focus_time"
        static let firstSessionWelcome = "home.first_session_welcome"
        static let noSessionsToday = "home.no_sessions_today"
        static let thisWeek = "home.this_week"
        static let startSession = "home.start_session"
        static let intentPrompt = "home.intent_prompt"
    }

    // MARK: - Onboarding
    enum Onboarding {
        enum Question {
            static let workType = "onboarding.question.work_type"
            static let struggleTime = "onboarding.question.struggle_time"
            static let hardestPart = "onboarding.question.hardest_part"
            static let phoneFrequency = "onboarding.question.phone_frequency"
            static let workContext = "onboarding.question.work_context"
        }

        enum Option {
            // Work types
            static let student = "onboarding.option.student"
            static let knowledgeWorker = "onboarding.option.knowledge_worker"
            static let creative = "onboarding.option.creative"
            static let manager = "onboarding.option.manager"

            // Struggle times
            static let short = "onboarding.option.struggle_short"
            static let medium = "onboarding.option.struggle_medium"
            static let long = "onboarding.option.struggle_long"

            // Hardest parts
            static let starting = "onboarding.option.starting"
            static let continuing = "onboarding.option.continuing"
            static let finishing = "onboarding.option.finishing"

            // Phone frequency
            static let veryOften = "onboarding.option.very_often"
            static let sometimes = "onboarding.option.sometimes"
            static let rarely = "onboarding.option.rarely"
        }

        enum Profile {
            static let yourProfile = "onboarding.profile.your_profile"
            static let shortFocus = "onboarding.profile.short_focus"
            static let mediumFocus = "onboarding.profile.medium_focus"
            static let deepFocus = "onboarding.profile.deep_focus"
            static let firstSessionSuggestion = "onboarding.profile.first_session_suggestion"
            static let improvementNote = "onboarding.profile.improvement_note"
        }

        static let letsStart = "onboarding.lets_start"
        static let contextDescription = "onboarding.context_description"
        static let addLaterNote = "onboarding.add_later_note"
    }

    // MARK: - Focus Screen
    enum Focus {
        static let endSession = "focus.end_session"
        static let skipBreak = "focus.skip_break"
        static let confirmEndTitle = "focus.confirm_end_title"
        static let confirmEndMessage = "focus.confirm_end_message"
        static let focusing = "focus.focusing"
    }

    // MARK: - Feedback Screen
    enum Feedback {
        static let sessionCompleted = "feedback.session_completed"
        static let focusedMinutes = "feedback.focused_minutes"
        static let howDidYouFeel = "feedback.how_did_you_feel"
        static let sessionProgress = "feedback.session_progress"
        static let sessionNote = "feedback.session_note"
        static let notePlaceholder = "feedback.note_placeholder"
        static let noteDescription = "feedback.note_description"

        enum Question {
            static let wasDifficult = "feedback.question.was_difficult"
            static let didStayFocused = "feedback.question.did_stay_focused"
            static let wasDurationAppropriate = "feedback.question.was_duration_appropriate"
        }

        enum Answer {
            static let yesStruggled = "feedback.answer.yes_struggled"
            static let noGood = "feedback.answer.no_good"
            static let yesFocused = "feedback.answer.yes_focused"
            static let noDistracted = "feedback.answer.no_distracted"
            static let yesAppropriate = "feedback.answer.yes_appropriate"
            static let noNotAppropriate = "feedback.answer.no_not_appropriate"
        }

        enum Mood {
            static let great = "feedback.mood.great"
            static let okay = "feedback.mood.okay"
            static let struggled = "feedback.mood.struggled"
        }
    }

    // MARK: - Daily Check-in
    enum CheckIn {
        static let title = "checkin.title"
        static let description = "checkin.description"

        enum Mood {
            static let energeticTitle = "checkin.mood.energetic.title"
            static let energeticDescription = "checkin.mood.energetic.description"
            static let normalTitle = "checkin.mood.normal.title"
            static let normalDescription = "checkin.mood.normal.description"
            static let tiredTitle = "checkin.mood.tired.title"
            static let tiredDescription = "checkin.mood.tired.description"
            static let scatteredTitle = "checkin.mood.scattered.title"
            static let scatteredDescription = "checkin.mood.scattered.description"
        }
    }

    // MARK: - Summary
    enum Summary {
        static let title = "summary.title"
        static let totalFocus = "summary.total_focus"
        static let yourSessions = "summary.your_sessions"
        static let forTomorrow = "summary.for_tomorrow"

        enum Status {
            static let stable = "summary.status.stable"
            static let fluctuating = "summary.status.fluctuating"
            static let tough = "summary.status.tough"
        }

        enum Tomorrow {
            static let stable = "summary.tomorrow.stable"
            static let fluctuating = "summary.tomorrow.fluctuating"
            static let tough = "summary.tomorrow.tough"
        }
    }

    // MARK: - Heatmap
    enum Heatmap {
        static let title = "heatmap.title"
        static let week = "heatmap.week"
        static let month = "heatmap.month"
        static let low = "heatmap.low"
        static let high = "heatmap.high"
        static let sessions = "heatmap.sessions"
        static let emptyTitle = "heatmap.empty_title"
        static let emptyDescription = "heatmap.empty_description"
        static let totalInterruption = "heatmap.total_interruption"
        static let focusMinutes = "heatmap.focus_minutes"
    }

    // MARK: - Break
    enum Break {
        static let skipBreak = "break.skip_break"

        enum Suggestion {
            static let deepBreathTitle = "break.suggestion.deep_breath.title"
            static let deepBreathDescription = "break.suggestion.deep_breath.description"
            static let walkTitle = "break.suggestion.walk.title"
            static let walkDescription = "break.suggestion.walk.description"
            static let waterTitle = "break.suggestion.water.title"
            static let waterDescription = "break.suggestion.water.description"
            static let eyesTitle = "break.suggestion.eyes.title"
            static let eyesDescription = "break.suggestion.eyes.description"
            static let windowTitle = "break.suggestion.window.title"
            static let windowDescription = "break.suggestion.window.description"
            static let stretchTitle = "break.suggestion.stretch.title"
            static let stretchDescription = "break.suggestion.stretch.description"
        }
    }

    // MARK: - Method
    enum Method {
        static let chooseTitle = "method.choose_title"
        static let chooseDescription = "method.choose_description"

        enum Description {
            static let pomodoro = "method.description.pomodoro"
            static let extended = "method.description.extended"
            static let optimal = "method.description.optimal"
            static let deepWork = "method.description.deep_work"
        }
    }

    // MARK: - Intent
    enum Intent {
        enum Label {
            static let reading = "intent.label.reading"
            static let watching = "intent.label.watching"
            static let mixed = "intent.label.mixed"
        }

        enum ShortLabel {
            static let reading = "intent.short.reading"
            static let watching = "intent.short.watching"
            static let mixed = "intent.short.mixed"
        }

        enum Description {
            static let reading = "intent.description.reading"
            static let watching = "intent.description.watching"
            static let mixed = "intent.description.mixed"
        }
    }

    // MARK: - Work Context
    enum WorkContext {
        static let general = "workcontext.general"
        static let newContext = "workcontext.new_context"
        static let nameLabel = "workcontext.name_label"
        static let namePlaceholder = "workcontext.name_placeholder"
        static let chooseIcon = "workcontext.choose_icon"
        static let alreadyExists = "workcontext.already_exists"
        static let pickerTitle = "workcontext.picker_title"
        static let pickerDescription = "workcontext.picker_description"

        // Suggested contexts
        static let coding = "workcontext.coding"
        static let reading = "workcontext.reading"
        static let writing = "workcontext.writing"
        static let design = "workcontext.design"
        static let research = "workcontext.research"
        static let math = "workcontext.math"
        static let language = "workcontext.language"
        static let music = "workcontext.music"
        static let video = "workcontext.video"
        static let planning = "workcontext.planning"

        // Icon categories
        enum Category {
            static let work = "workcontext.category.work"
            static let creativity = "workcontext.category.creativity"
            static let learning = "workcontext.category.learning"
            static let sports = "workcontext.category.sports"
            static let life = "workcontext.category.life"
            static let entertainment = "workcontext.category.entertainment"
            static let technology = "workcontext.category.technology"
            static let finance = "workcontext.category.finance"
            static let communication = "workcontext.category.communication"
            static let nature = "workcontext.category.nature"
        }
    }
}
