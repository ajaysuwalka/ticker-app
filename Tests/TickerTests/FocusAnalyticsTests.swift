import XCTest
@testable import Ticker

/// Focus Goal logic: only a single *continuous* streak counts (gaps up to 10 min
/// tolerated), never the sum of fragmented productive blocks.
@MainActor
final class FocusAnalyticsTests: XCTestCase {

    func testFocusedSecondsCountsLongestStreakNotSum() {
        let store = TestSupport.makeStore()
        store.markIntervalAsMeeting(DateInterval(start: fixedDay, duration: 12 * 60))
        let second = fixedDay.addingTimeInterval((12 + 15) * 60)   // 15-min gap > 10
        store.markIntervalAsMeeting(DateInterval(start: second, duration: 8 * 60))

        let interval = DateInterval(start: fixedDay, duration: 24 * 3600)
        XCTAssertEqual(store.focusedSeconds(in: interval), 12 * 60)   // longest, not 20 min
    }

    func testShortGapDoesNotBreakStreak() {
        let store = TestSupport.makeStore()
        store.markIntervalAsMeeting(DateInterval(start: fixedDay, duration: 5 * 60))
        let second = fixedDay.addingTimeInterval((5 + 3) * 60)        // 3-min gap <= 10
        store.markIntervalAsMeeting(DateInterval(start: second, duration: 5 * 60))

        let interval = DateInterval(start: fixedDay, duration: 24 * 3600)
        XCTAssertEqual(store.focusedSeconds(in: interval), 10 * 60)
    }

    func testDeleteRecordsRemovesTrackedTime() {
        let store = TestSupport.makeStore()
        store.markIntervalAsMeeting(DateInterval(start: fixedDay, duration: 10 * 60))
        let interval = DateInterval(start: fixedDay, duration: 24 * 3600)
        XCTAssertEqual(store.focusedSeconds(in: interval), 10 * 60)

        store.deleteRecords(in: DateInterval(start: fixedDay, duration: 10 * 60))
        XCTAssertEqual(store.focusedSeconds(in: interval), 0)
    }
}
