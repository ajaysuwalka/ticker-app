import XCTest
@testable import Ticker

@MainActor
final class BreakManagerTests: XCTestCase {

    private func drive(_ breaks: BreakManager, activeSeconds: Int) {
        for _ in 0..<activeSeconds { breaks.registerTick(active: true) }
    }

    // Interval-focused tests disable the minimum gap so they exercise the
    // per-break timers in isolation (see the *MinGap* tests for spacing).

    func testBothDueShowsTheOneWithMoreTimeAvailable() {
        let store = TestSupport.makeStore()
        store.minBreakGapMinutes = 0
        store.moveBreakMinutes = 5      // equal intervals so both cross at once
        store.screenBreakMinutes = 5
        let breaks = BreakManager(store: store)
        drive(breaks, activeSeconds: 5 * 60)
        XCTAssertEqual(breaks.pending, .screen)   // tie → screen (also covers move)
    }

    func testMoveOnlyDueShowsMove() {
        let store = TestSupport.makeStore()
        store.minBreakGapMinutes = 0
        store.moveBreakMinutes = 5
        store.screenBreakMinutes = 120
        let breaks = BreakManager(store: store)
        drive(breaks, activeSeconds: 5 * 60)
        XCTAssertEqual(breaks.pending, .move)
    }

    func testSecondsUntilCountsDownWithActiveTime() {
        let store = TestSupport.makeStore()
        store.minBreakGapMinutes = 0
        store.moveBreakMinutes = 30
        let breaks = BreakManager(store: store)
        let before = breaks.secondsUntilMove
        drive(breaks, activeSeconds: 60)
        XCTAssertEqual(breaks.secondsUntilMove, before - 60)
    }

    func testSteppingAwayCountsMoveBreakAsTaken() {
        let store = TestSupport.makeStore()
        store.minBreakGapMinutes = 0
        store.moveBreakMinutes = 5
        let breaks = BreakManager(store: store)
        drive(breaks, activeSeconds: 5 * 60)
        XCTAssertEqual(breaks.pending, .move)
        for _ in 0..<90 { breaks.registerTick(active: false) }   // ~1.5 min away
        XCTAssertNil(breaks.pending)
    }

    func testDisablingRemindersClearsPending() {
        let store = TestSupport.makeStore()
        store.minBreakGapMinutes = 0
        store.moveBreakMinutes = 5
        let breaks = BreakManager(store: store)
        drive(breaks, activeSeconds: 5 * 60)
        XCTAssertNotNil(breaks.pending)

        store.breakRemindersEnabled = false
        breaks.registerTick(active: true)
        XCTAssertNil(breaks.pending)
    }

    func testSnoozePostponesAndClears() {
        let store = TestSupport.makeStore()
        store.minBreakGapMinutes = 0
        store.moveBreakMinutes = 5
        let breaks = BreakManager(store: store)
        drive(breaks, activeSeconds: 5 * 60)
        XCTAssertEqual(breaks.pending, .move)

        breaks.snooze(.move, minutes: 5)
        XCTAssertNil(breaks.pending)
        XCTAssertGreaterThan(breaks.secondsUntilMove, 0)
    }

    // MARK: - Minimum gap between breaks

    func testMinGapGatesFirstBreak() {
        let store = TestSupport.makeStore()
        store.moveBreakMinutes = 5
        store.screenBreakMinutes = 999       // keep screen out of the way
        store.minBreakGapMinutes = 10
        let breaks = BreakManager(store: store)

        drive(breaks, activeSeconds: 5 * 60)     // move interval met, but gap (10 min) not
        XCTAssertNil(breaks.pending)
        drive(breaks, activeSeconds: 5 * 60)     // now 10 min total → gap satisfied
        XCTAssertEqual(breaks.pending, .move)
    }

    func testMinGapSpacesConsecutiveBreaks() {
        let store = TestSupport.makeStore()
        store.moveBreakMinutes = 5
        store.screenBreakMinutes = 999
        store.minBreakGapMinutes = 30
        let breaks = BreakManager(store: store)

        drive(breaks, activeSeconds: 30 * 60)    // first break lands at the 30-min gap
        XCTAssertEqual(breaks.pending, .move)
        breaks.take(.move)                       // clears it, restarts the gap clock

        // Next break can't be sooner than the 30-min gap, even though the move
        // interval (5 min) is met well before that.
        XCTAssertEqual(breaks.secondsUntilMove, 30 * 60)
        drive(breaks, activeSeconds: 6 * 60)
        XCTAssertNil(breaks.pending)
        drive(breaks, activeSeconds: 24 * 60)    // 30 min since the previous break
        XCTAssertEqual(breaks.pending, .move)
    }

    func testCountdownsAreNeverEqualUnderMinGap() {
        let store = TestSupport.makeStore()
        store.moveBreakMinutes = 30
        store.screenBreakMinutes = 60
        store.minBreakGapMinutes = 30
        let breaks = BreakManager(store: store)
        // Fresh session: previously both were clamped to the gap and read equal.
        XCTAssertNotEqual(breaks.secondsUntilMove, breaks.secondsUntilScreen)
        drive(breaks, activeSeconds: 12 * 60)
        XCTAssertNotEqual(breaks.secondsUntilMove, breaks.secondsUntilScreen)
    }

    func testAwayResetsTimersSoNoBreakRightAfterReturning() {
        let store = TestSupport.makeStore()
        store.minBreakGapMinutes = 0
        store.moveBreakMinutes = 30
        store.screenBreakMinutes = 60
        let breaks = BreakManager(store: store)

        // Accrue 29 minutes of active time (just shy of the move break).
        drive(breaks, activeSeconds: 29 * 60)
        XCTAssertNil(breaks.pending)

        // Laptop closed for 10 minutes → counts as a break, timers reset.
        breaks.registerAway(seconds: 10 * 60)

        // Back at the keyboard for 5 minutes → must NOT fire (was 29+5 before).
        drive(breaks, activeSeconds: 5 * 60)
        XCTAssertNil(breaks.pending, "away time should reset the break timers")
    }

    func testShortAwayCreditsOnlyMove() {
        let store = TestSupport.makeStore()
        store.minBreakGapMinutes = 0
        store.moveBreakMinutes = 30
        store.screenBreakMinutes = 60
        let breaks = BreakManager(store: store)
        drive(breaks, activeSeconds: 20 * 60)
        breaks.registerAway(seconds: 2 * 60)     // 2 min away → move reset, screen kept
        XCTAssertEqual(breaks.secondsUntilMove, 30 * 60)   // move restarted
        XCTAssertEqual(breaks.secondsUntilScreen, 40 * 60) // screen unchanged (60 - 20)
    }

    func testDurationsAreConfigurable() {
        let store = TestSupport.makeStore()
        store.moveBreakDurationMinutes = 3
        store.screenBreakDurationMinutes = 10
        let breaks = BreakManager(store: store)
        XCTAssertEqual(breaks.breakDurationSeconds(.move), 3 * 60)
        XCTAssertEqual(breaks.breakDurationSeconds(.screen), 10 * 60)
    }
}
