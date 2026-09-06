import XCTest
@testable import AppUtils

/// `PausableCountdown` — a deadline that stops while the app is waiting for a person.
///
/// The failure it prevents, seen in production: a 120-second budget, a captcha shown at t+2 and
/// solved at t+64, and the operation dying at t+120 — seconds after the person had done exactly what
/// was asked of them, and before the source they had just unlocked could answer.
final class PausableCountdownTests: XCTestCase {

    private func countdown(_ budget: TimeInterval = 120,
                           maxPause: TimeInterval = 120) -> PausableCountdown {
        PausableCountdown(budgetSec: budget, now: 0, maxPauseSec: maxPause)
    }

    // MARK: - Uninterrupted, it is an ordinary countdown

    func testTimeSpentRunningIsCharged() {
        let c = countdown()

        XCTAssertEqual(c.remaining(at: 0), 120)
        XCTAssertEqual(c.remaining(at: 50), 70)
        XCTAssertEqual(c.remaining(at: 120), 0)
    }

    /// Never negative: callers schedule timers straight from this value.
    func testASpentBudgetStaysAtZero() {
        XCTAssertEqual(countdown().remaining(at: 500), 0)
    }

    // MARK: - The case it exists for

    func testTheInterruptionIsNotCharged() {
        var c = countdown()
        c.pause(at: 2)
        c.resume(at: 64)

        XCTAssertEqual(c.remaining(at: 64), 118)
    }

    func testTimeAfterTheInterruptionIsChargedAgain() {
        var c = countdown()
        c.pause(at: 2)
        c.resume(at: 64)

        XCTAssertEqual(c.remaining(at: 84), 98)
    }

    /// Read DURING the pause, not only after it — a caller may ask at any moment.
    func testNothingIsChargedWhileStillPaused() {
        var c = countdown()
        c.pause(at: 10)

        XCTAssertEqual(c.remaining(at: 70), 110)
        XCTAssertTrue(c.isPaused)
    }

    // MARK: - The shapes real events arrive in

    /// The trigger fires more than once for one occurrence. Counting the second call would move the
    /// pause start forward and quietly charge the gap between them.
    func testPausingTwiceDoesNotDoubleCount() {
        var c = countdown()
        c.pause(at: 2)
        c.pause(at: 12)
        c.resume(at: 64)

        XCTAssertEqual(c.remaining(at: 64), 118)
    }

    func testResumingWithoutAPauseIsHarmless() {
        var c = countdown()
        c.resume(at: 30)

        XCTAssertEqual(c.remaining(at: 30), 90)
        XCTAssertFalse(c.isPaused)
    }

    func testTwoInterruptionsBothStopTheClock() {
        var c = countdown()
        c.pause(at: 10);  c.resume(at: 40)
        c.pause(at: 50);  c.resume(at: 70)

        XCTAssertEqual(c.remaining(at: 70), 100)
    }

    // MARK: - The ceiling on pausing

    func testPausingHasACeilingOfItsOwn() {
        var c = countdown()
        c.pause(at: 2)
        c.resume(at: 602)

        XCTAssertEqual(c.remaining(at: 602), 0, "600s of waiting buys 120s of pause, not 600")
    }

    /// The ceiling is on the TOTAL, so several long interruptions cannot each buy the full pause.
    func testTheCeilingIsOnTheTotalNotOnOneInterruption() {
        var c = countdown(300)
        c.pause(at: 0);   c.resume(at: 100)
        c.pause(at: 100); c.resume(at: 200)

        XCTAssertEqual(c.remaining(at: 200), 220, "120s of pause allowed, so 80s of the 200 was charged")
    }

    /// And it applies while the interruption is still open — otherwise a forgotten dialog freezes
    /// the countdown indefinitely, which is the thing the ceiling exists to prevent.
    func testTheCeilingAppliesWhileStillPaused() {
        var c = countdown()
        c.pause(at: 0)

        XCTAssertEqual(c.remaining(at: 300), 0)
    }

    /// The ceiling is configurable, because "how long is it reasonable to wait" is the caller's
    /// question, not this type's.
    func testTheCeilingIsTheCallersChoice() {
        var c = countdown(300, maxPause: 30)
        c.pause(at: 0)
        c.resume(at: 100)

        XCTAssertEqual(c.remaining(at: 100), 230, "only 30s of the 100 was excused")
    }
}

// MARK: - What a caller needs to schedule against

extension PausableCountdownTests {

    /// A caller cancels its timer when it pauses. Nothing then wakes it at the moment the ceiling
    /// runs out — the budget resumes on paper while the operation hangs in practice. `remainingPause`
    /// is what lets the caller arm a timer for that instant instead.
    func testRemainingPauseStartsAtTheCeiling() {
        XCTAssertEqual(countdown().remainingPause, 120)
        XCTAssertEqual(countdown(300, maxPause: 30).remainingPause, 30)
    }

    func testRemainingPauseShrinksByWhatWasAlreadySpent() {
        var c = countdown()
        c.pause(at: 0)
        c.resume(at: 50)

        XCTAssertEqual(c.remainingPause, 70)
    }

    func testRemainingPauseReachesZeroAtTheCeiling() {
        var c = countdown()
        c.pause(at: 0)
        c.resume(at: 500)

        XCTAssertEqual(c.remainingPause, 0)
    }

    /// The sum a caller arms its timer with, and the reason it is a DELAY rather than an instant:
    /// everything left of the budget plus everything left of the pause allowance is how long from
    /// now the operation could still be alive, even if the interruption is never closed.
    func testBudgetPlusRemainingPauseIsHowLongTheOperationCanStillLive() {
        var c = countdown()
        c.pause(at: 20)

        let delay = c.remaining(at: 20) + c.remainingPause
        XCTAssertEqual(delay, 220, "100s of budget left, plus the full 120s of pause allowance")

        XCTAssertGreaterThan(c.remaining(at: 20 + delay - 1), 0, "a second early it is still alive")
        XCTAssertEqual(c.remaining(at: 20 + delay), 0, "and at that instant it is spent")
    }
}
