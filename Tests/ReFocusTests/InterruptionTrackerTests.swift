import XCTest
@testable import ReFocus

final class InterruptionTrackerTests: XCTestCase {

    // MARK: - Focus Flow Visualization Tests

    func testVisualizationWithNoInterruptions() {
        let session = FocusSession(method: .pomodoro)

        let visualization = InterruptionTracker.generateFocusFlowVisualization(for: session)

        // Tüm karakterler dolu olmalı
        XCTAssertTrue(visualization.contains("█"))
        XCTAssertFalse(visualization.contains("░"))
    }

    func testVisualizationWithInterruptions() {
        var session = FocusSession(method: .pomodoro)

        let start = session.startTime.addingTimeInterval(300) // 5 dakika sonra
        let end = start.addingTimeInterval(120) // 2 dakika bölünme

        session.addInterruption(Interruption(startTime: start, endTime: end))

        let visualization = InterruptionTracker.generateFocusFlowVisualization(for: session)

        // Hem dolu hem boş karakterler olmalı
        XCTAssertTrue(visualization.contains("┃"))
    }

    // MARK: - Focus Quality Message Tests

    func testExcellentQualityMessage() {
        var session = FocusSession(method: .pomodoro)
        // Hiç bölünme yok = mükemmel kalite
        session.complete()

        let message = InterruptionTracker.getFocusQualityMessage(for: session)

        XCTAssertTrue(
            message.contains("iyiydi") ||
            message.contains("korundu") ||
            message.contains("başardın") ||
            message.contains("geri dönmendi")
        )
    }

    func testPoorQualityMessage() {
        var session = FocusSession(method: .pomodoro)

        // Çok fazla bölünme ekle (düşük kalite)
        for i in 0..<10 {
            let start = session.startTime.addingTimeInterval(TimeInterval(i * 100))
            let end = start.addingTimeInterval(50)
            session.addInterruption(Interruption(startTime: start, endTime: end))
        }

        session.complete()

        let message = InterruptionTracker.getFocusQualityMessage(for: session)

        // Nazik mesaj olmalı, yargılayıcı değil
        XCTAssertTrue(message.contains("geri dönmendi") || message.contains("bölündün"))
    }

    // MARK: - Interruption Duration Tests

    func testInterruptionDuration() {
        let start = Date()
        let end = start.addingTimeInterval(120) // 2 dakika

        let interruption = Interruption(startTime: start, endTime: end)

        XCTAssertEqual(interruption.duration, 120)
    }

    func testTotalInterruptionDuration() {
        var session = FocusSession(method: .pomodoro)

        // 3 adet 1 dakikalık bölünme
        for i in 0..<3 {
            let start = Date().addingTimeInterval(TimeInterval(i * 300))
            let end = start.addingTimeInterval(60)
            session.addInterruption(Interruption(startTime: start, endTime: end))
        }

        XCTAssertEqual(session.totalInterruptionDuration, 180) // 3 dakika
    }

    // MARK: - Message Situation Tests

    func testMessageSituationForShortBackground() {
        let tracker = InterruptionTracker()
        var session = FocusSession(method: .pomodoro)

        // 30 saniye bölünme
        let start = Date()
        let end = start.addingTimeInterval(30)
        session.addInterruption(Interruption(startTime: start, endTime: end))

        let situation = tracker.determineMessageSituation(for: session)

        XCTAssertEqual(situation, .shortBackground)
    }

    func testMessageSituationForLongBackground() {
        let tracker = InterruptionTracker()
        var session = FocusSession(method: .pomodoro)

        // 2 dakika bölünme
        let start = Date()
        let end = start.addingTimeInterval(120)
        session.addInterruption(Interruption(startTime: start, endTime: end))

        let situation = tracker.determineMessageSituation(for: session)

        XCTAssertEqual(situation, .longBackground)
    }
}
