import XCTest
@testable import Ticker

@MainActor
final class SummaryAnalyticsTests: XCTestCase {

    func testSummaryCategorizesAndIgnoresExcluded() {
        let store = TestSupport.makeStore()
        store.setCategory(.productive, for: "app.prod")
        store.setCategory(.distracting, for: "app.dist")
        store.setCategory(.excluded, for: "app.excl")
        let minute = fixedDay.addingTimeInterval(9 * 3600)
        TestSupport.addActive(store, minute: minute, bundle: "app.prod", seconds: 60, keys: 10, mouse: 5)
        TestSupport.addActive(store, minute: minute, bundle: "app.dist", seconds: 30)
        TestSupport.addActive(store, minute: minute, bundle: "app.excl", seconds: 120)  // excluded → ignored

        let s = store.summary(on: fixedDay)
        XCTAssertEqual(s.activeSeconds, 90, "excluded time must not count")
        XCTAssertEqual(s.productiveSeconds, 60)
        XCTAssertEqual(s.distractingSeconds, 30)
        XCTAssertEqual(s.keyCount, 10)
        XCTAssertEqual(s.mouseCount, 5)
        XCTAssertEqual(s.productivity, 60.0 / 90.0, accuracy: 0.0001)
        XCTAssertEqual(s.apps.count, 2, "excluded apps are dropped from the breakdown")
        XCTAssertEqual(s.apps.first?.bundleId, "app.prod")
    }

    func testHourlyStatsGroupByHour() {
        let store = TestSupport.makeStore()
        store.setCategory(.productive, for: "a")
        TestSupport.addActive(store, minute: fixedDay.addingTimeInterval(9 * 3600), bundle: "a", seconds: 40, keys: 3)

        let stats = store.hourlyStats(in: Timescale.day.interval(containing: fixedDay))
        XCTAssertEqual(stats[9].activeSeconds, 40)
        XCTAssertEqual(stats[9].interactions, 3)
        XCTAssertEqual(stats[10].activeSeconds, 0)
    }

    func testActivityBucketsCountInteractions() {
        let store = TestSupport.makeStore()
        store.setCategory(.productive, for: "a")
        TestSupport.addActive(store, minute: fixedDay.addingTimeInterval(60), bundle: "a", seconds: 5, keys: 2, mouse: 3)

        let buckets = store.activityBuckets(on: fixedDay, bucketMinutes: 15)
        XCTAssertEqual(buckets.count, 96)
        XCTAssertEqual(buckets[0].interactions, 5)   // 2 keys + 3 clicks, first 15-min bucket
        XCTAssertEqual(buckets[1].interactions, 0)
    }

    func testContextSwitchesSum() {
        let store = TestSupport.makeStore()
        store.setCategory(.neutral, for: "a")
        TestSupport.addActive(store, minute: fixedDay.addingTimeInterval(3600), bundle: "a", seconds: 10, switches: 4)
        XCTAssertEqual(store.contextSwitches(in: Timescale.day.interval(containing: fixedDay)), 4)
    }

    func testDailyProductivityRatio() {
        let store = TestSupport.makeStore()
        store.setCategory(.productive, for: "p")
        store.setCategory(.distracting, for: "d")
        let minute = fixedDay.addingTimeInterval(3600)
        TestSupport.addActive(store, minute: minute, bundle: "p", seconds: 30)
        TestSupport.addActive(store, minute: minute, bundle: "d", seconds: 10)

        let points = store.dailyProductivity(in: Timescale.day.interval(containing: fixedDay))
        let today = points.first { $0.activeSeconds > 0 }
        XCTAssertEqual(today?.productivity ?? 0, 30.0 / 40.0, accuracy: 0.0001)
    }

    func testWeeklyGoalDefaultsTo40AndPersists() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticker-tests-\(UUID().uuidString)", isDirectory: true)
        let store = TickerStore(directory: dir)
        XCTAssertEqual(store.weeklyGoalHours, 40)          // default
        store.weeklyGoalHours = 32
        store.save()
        XCTAssertEqual(TickerStore(directory: dir).weeklyGoalHours, 32)
    }

    func testWeeklyActiveHoursSumOverWeek() {
        let store = TestSupport.makeStore()
        store.setCategory(.productive, for: "a")
        // 40 active minutes on the fixed day → contributes to that day's week total.
        TestSupport.addActive(store, minute: fixedDay.addingTimeInterval(9 * 3600), bundle: "a", seconds: 40 * 60)
        let week = Timescale.week.interval(containing: fixedDay)
        XCTAssertEqual(store.summary(in: week).activeSeconds, 40 * 60)
    }

    func testFocusStreakCountsDayMeetingGoal() {
        let store = TestSupport.makeStore()
        store.dailyGoalMinutes = 10   // small goal for the test
        let today = Date().startOfDay
        store.markIntervalAsMeeting(DateInterval(start: today.addingTimeInterval(9 * 3600), duration: 12 * 60))
        XCTAssertGreaterThanOrEqual(store.focusStreakDays(), 1)
    }
}
