import XCTest
@testable import ReFocus

final class MethodSelectionEngineTests: XCTestCase {

    // MARK: - Basic Method Selection Tests

    func testPomodoroForShortFocus() {
        let answers = OnboardingAnswers(
            workType: .student,
            struggleTime: .short,
            hardestPart: .continuing,
            phoneCheckingFrequency: .veryOften
        )

        let profile = UserProfile(onboardingAnswers: answers)
        let method = MethodSelectionEngine.selectMethod(for: profile)

        XCTAssertEqual(method, .pomodoro)
    }

    func testDeepWorkForDeepFocus() {
        let answers = OnboardingAnswers(
            workType: .knowledgeWorker,
            struggleTime: .long,
            hardestPart: .finishing,
            phoneCheckingFrequency: .rarely
        )

        let profile = UserProfile(onboardingAnswers: answers)
        let method = MethodSelectionEngine.selectMethod(for: profile)

        XCTAssertEqual(method, .deepWork)
    }

    func testExtendedForMediumFocus() {
        let answers = OnboardingAnswers(
            workType: .manager,
            struggleTime: .medium,
            hardestPart: .finishing,
            phoneCheckingFrequency: .rarely
        )

        let profile = UserProfile(onboardingAnswers: answers)
        let method = MethodSelectionEngine.selectMethod(for: profile)

        XCTAssertEqual(method, .extended)
    }

    func testOptimalForFluctuating() {
        let answers = OnboardingAnswers(
            workType: .creative,
            struggleTime: .medium,
            hardestPart: .starting,
            phoneCheckingFrequency: .sometimes
        )

        let profile = UserProfile(onboardingAnswers: answers)
        let method = MethodSelectionEngine.selectMethod(for: profile)

        XCTAssertEqual(method, .optimal)
    }

    // MARK: - Method Adjustment Tests

    func testSuggestShorterMethodAfterPoorSession() {
        var session = FocusSession(method: .deepWork)

        // Çok bölünme simüle et (düşük kalite)
        for i in 0..<5 {
            let start = Date().addingTimeInterval(TimeInterval(i * 300))
            let end = start.addingTimeInterval(120)
            session.addInterruption(Interruption(startTime: start, endTime: end))
        }

        let suggestion = MethodSelectionEngine.suggestMethodAdjustment(from: session, feedback: nil)

        // Deep Work'ten Optimal'e inmeli
        XCTAssertEqual(suggestion, .optimal)
    }

    func testNoAdjustmentForGoodSession() {
        let session = FocusSession(method: .pomodoro)

        let feedback = SessionFeedback(
            wasDifficult: false,
            didStayFocused: true,
            wasDurationAppropriate: true,
            additionalNotes: nil
        )

        let suggestion = MethodSelectionEngine.suggestMethodAdjustment(from: session, feedback: feedback)

        XCTAssertNil(suggestion)
    }

    // MARK: - Recommendation Message Tests

    func testRecommendationMessageContainsMethodName() {
        let answers = OnboardingAnswers(
            workType: .student,
            struggleTime: .short,
            hardestPart: .starting,
            phoneCheckingFrequency: .sometimes
        )

        let profile = UserProfile(onboardingAnswers: answers)
        let message = MethodSelectionEngine.getRecommendationMessage(for: .pomodoro, profile: profile)

        XCTAssertTrue(message.contains("Pomodoro"))
    }
}
