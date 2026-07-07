#if DEBUG
import SwiftUI
import CloudKit

/// App Store ekran görüntüleri için vitrin modu (yalnızca DEBUG derlemede).
///
/// Kullanım: uygulamayı `-marketingShot <1-6>` argümanıyla başlat;
/// ilgili ekran örnek verilerle doğrudan açılır. Dil, `-AppleLanguages`
/// argümanıyla belirlenir; tüm metinler o dilde render edilir.
enum MarketingTour {
    static var shotNumber: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-marketingShot"),
              args.count > index + 1 else { return nil }
        return Int(args[index + 1])
    }

    static var isActive: Bool { shotNumber != nil }

    /// Örnek verileri UserDefaults'a yazar.
    /// AppState/SessionManager oluşturulmadan ÖNCE çağrılmalıdır.
    static func seedIfNeeded() {
        guard isActive else { return }
        let defaults = UserDefaults.standard

        // Onboarding tamam + profil
        defaults.set(true, forKey: "hasCompletedOnboarding")
        let answers = OnboardingAnswers(
            workType: .student,
            struggleTime: .medium,
            hardestPart: .starting,
            phoneCheckingFrequency: .sometimes
        )
        if let encoded = try? JSONEncoder().encode(UserProfile(onboardingAnswers: answers)) {
            defaults.set(encoded, forKey: "userProfile")
        }

        // Günlük check-in'i bugün yapılmış say (sheet açılmasın)
        defaults.set(Date(), forKey: "lastDailyCheckIn")
        defaults.set("normal", forKey: "todaysMood")

        // Çalışma bağlamları (yerelleştirilmiş adlarla)
        let contexts = Array(WorkContext.suggestions.prefix(4))
        if let encoded = try? JSONEncoder().encode(contexts) {
            defaults.set(encoded, forKey: "userWorkContexts")
        }

        // 3 haftalık makul seans geçmişi
        var history: [FocusSession] = []
        let calendar = Calendar.current
        let methods: [FocusMethod] = [.pomodoro, .extended, .deepWork]
        for dayOffset in 0..<21 {
            if dayOffset % 7 == 5 { continue } // haftada bir sakin gün
            let sessionCount = [2, 3, 1, 2, 3, 2][dayOffset % 6]
            for index in 0..<sessionCount {
                guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
                var start = calendar.date(bySettingHour: 9 + index * 3,
                                          minute: [5, 20, 40][index % 3],
                                          second: 0, of: day) ?? day
                if dayOffset == 0 {
                    // Bugünün seansları "şimdiden önce" olsun
                    start = calendar.date(byAdding: .hour, value: -(2 + index * 2), to: Date()) ?? day
                }
                let method = methods[(dayOffset + index) % methods.count]
                let duration = TimeInterval(method.focusDuration * 60)
                let withInterruption = (dayOffset + index) % 4 == 0
                history.append(backdatedSession(
                    method: method,
                    context: contexts[(dayOffset + index) % contexts.count],
                    start: start,
                    duration: duration,
                    withInterruption: withInterruption
                ))
            }
        }
        if let encoded = try? JSONEncoder().encode(history) {
            defaults.set(encoded, forKey: "sessionHistory")
        }
    }

    /// startTime'ı geçmişe alınmış tamamlanmış seans üretir.
    /// FocusSession.startTime `let` olduğundan JSON üzerinden kurulur.
    private static func backdatedSession(
        method: FocusMethod,
        context: WorkContext,
        start: Date,
        duration: TimeInterval,
        withInterruption: Bool
    ) -> FocusSession {
        var session = FocusSession(method: method, intent: .mixed, workContext: context)
        if withInterruption {
            session.addInterruption(Interruption(
                startTime: start.addingTimeInterval(duration * 0.4),
                endTime: start.addingTimeInterval(duration * 0.4 + 150)
            ))
        }
        session.isActive = false
        session.feedback = SessionFeedback(
            wasDifficult: withInterruption,
            didStayFocused: !withInterruption,
            wasDurationAppropriate: true,
            additionalNotes: nil
        )

        guard let data = try? JSONEncoder().encode(session),
              var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return session
        }
        object["startTime"] = start.timeIntervalSinceReferenceDate
        object["endTime"] = start.addingTimeInterval(duration).timeIntervalSinceReferenceDate
        guard let mutated = try? JSONSerialization.data(withJSONObject: object),
              let rebuilt = try? JSONDecoder().decode(FocusSession.self, from: mutated) else {
            return session
        }
        return rebuilt
    }

    /// Vitrin arkadaş listesi (yerelleştirilmiş bağlam adlarıyla)
    static func demoFriends() -> [FriendSummary] {
        let math = String(localized: "workcontext.math")
        let coding = String(localized: "workcontext.coding")
        let reading = String(localized: "workcontext.reading")
        let calendar = Calendar.current

        func day(_ offset: Int, _ minutes: Int, _ sessions: Int,
                 _ contexts: [(String, Int)]) -> FriendDayActivity {
            FriendDayActivity(
                date: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()),
                totalMinutes: minutes,
                sessionCount: sessions,
                averageQuality: 0.82,
                contexts: contexts
            )
        }

        return [
            FriendSummary(
                zoneID: CKRecordZone.ID(zoneName: "demo1", ownerName: "demo1"),
                displayName: "Deniz",
                days: [
                    day(0, 85, 3, [(math, 45), (coding, 40)]),
                    day(1, 110, 4, [(math, 70), (reading, 40)]),
                    day(2, 60, 2, [(coding, 60)])
                ],
                isFocusing: true,
                focusingSince: Date().addingTimeInterval(-25 * 60)
            ),
            FriendSummary(
                zoneID: CKRecordZone.ID(zoneName: "demo2", ownerName: "demo2"),
                displayName: "Mia",
                days: [
                    day(0, 50, 2, [(reading, 50)]),
                    day(1, 95, 3, [(reading, 55), (math, 40)])
                ],
                isFocusing: false,
                focusingSince: nil
            )
        ]
    }
}

/// Vitrin modunda gösterilecek ekranlar
struct MarketingShotView: View {
    let shot: Int
    @EnvironmentObject var appState: AppState

    @State private var intent: SessionIntent = .watching
    @State private var context: WorkContext? = WorkContext.suggestions.first

    var body: some View {
        switch shot {
        case 1:
            HomeView()
        case 2:
            FocusView(sessionManager: appState.sessionManager)
                .onAppear {
                    appState.sessionManager.startDemoSession(remaining: 17 * 60 + 24)
                }
        case 3:
            SessionStartSheet(
                method: .pomodoro,
                selectedIntent: $intent,
                selectedWorkContext: $context,
                contextManager: WorkContextManager.shared,
                onStart: {}
            )
        case 4:
            HeatmapView(
                sessionManager: appState.sessionManager,
                initialPeriod: .month,
                initialSelectedDate: Calendar.current.date(
                    byAdding: .day, value: -1,
                    to: Calendar.current.startOfDay(for: Date())
                )
            )
        case 5:
            FriendsView()
                .onAppear {
                    FriendSyncManager.shared.enableDemoMode()
                }
        case 6:
            CloudStatusView(sessionManager: appState.sessionManager)
        default:
            HomeView()
        }
    }
}
#endif
