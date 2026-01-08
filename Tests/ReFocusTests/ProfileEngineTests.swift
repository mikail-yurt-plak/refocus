import XCTest
@testable import ReFocus

final class ProfileEngineTests: XCTestCase {

    // MARK: - Profile Type Determination Tests

    func testShortFocusProfile() {
        // Kısa mücadele süresi + çok sık telefon kontrolü = Kısa Odaklı
        let answers = OnboardingAnswers(
            workType: .student,
            struggleTime: .short,
            hardestPart: .continuing,
            phoneCheckingFrequency: .veryOften
        )

        let profile = UserProfile(onboardingAnswers: answers)

        XCTAssertEqual(profile.profileType, .shortFocus)
        XCTAssertEqual(profile.profileType.recommendedMethod, .pomodoro)
    }

    func testDeepFocusProfile() {
        // Uzun mücadele süresi + nadiren telefon kontrolü = Derin Odaklı
        let answers = OnboardingAnswers(
            workType: .knowledgeWorker,
            struggleTime: .long,
            hardestPart: .finishing,
            phoneCheckingFrequency: .rarely
        )

        let profile = UserProfile(onboardingAnswers: answers)

        XCTAssertEqual(profile.profileType, .deepFocus)
        XCTAssertEqual(profile.profileType.recommendedMethod, .deepWork)
    }

    func testFluctuatingFocusProfile() {
        // Başlamak zor + sık telefon kontrolü = Dalgalı Odaklı
        let answers = OnboardingAnswers(
            workType: .creative,
            struggleTime: .medium,
            hardestPart: .starting,
            phoneCheckingFrequency: .sometimes
        )

        let profile = UserProfile(onboardingAnswers: answers)

        XCTAssertEqual(profile.profileType, .fluctuating)
        XCTAssertEqual(profile.profileType.recommendedMethod, .optimal)
    }

    func testMediumFocusProfile() {
        // Orta mücadele süresi = Orta Odaklı
        let answers = OnboardingAnswers(
            workType: .manager,
            struggleTime: .medium,
            hardestPart: .finishing,
            phoneCheckingFrequency: .rarely
        )

        let profile = UserProfile(onboardingAnswers: answers)

        XCTAssertEqual(profile.profileType, .mediumFocus)
        XCTAssertEqual(profile.profileType.recommendedMethod, .extended)
    }

    // MARK: - Profile Update Tests

    func testProfileUpdateFromBehavior() {
        let answers = OnboardingAnswers(
            workType: .student,
            struggleTime: .short,
            hardestPart: .starting,
            phoneCheckingFrequency: .veryOften
        )

        var profile = UserProfile(onboardingAnswers: answers)

        // İlk güncelleme
        profile.updateFromBehavior(
            sessionDuration: 1500, // 25 dakika
            interruptionCount: 2,
            wasSuccessful: true
        )

        XCTAssertEqual(profile.totalSessions, 1)
        XCTAssertEqual(profile.successfulSessions, 1)
        XCTAssertEqual(profile.averageFocusDuration, 1500)
        XCTAssertEqual(profile.averageInterruptionCount, 2)

        // İkinci güncelleme
        profile.updateFromBehavior(
            sessionDuration: 1800, // 30 dakika
            interruptionCount: 4,
            wasSuccessful: false
        )

        XCTAssertEqual(profile.totalSessions, 2)
        XCTAssertEqual(profile.successfulSessions, 1)
        XCTAssertEqual(profile.averageFocusDuration, 1650) // (1500 + 1800) / 2
        XCTAssertEqual(profile.averageInterruptionCount, 3) // (2 + 4) / 2
    }
}
