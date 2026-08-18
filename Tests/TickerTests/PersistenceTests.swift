import XCTest
@testable import Ticker

@MainActor
final class PersistenceTests: XCTestCase {

    func testSettingsAndRecordsRoundTrip() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticker-tests-\(UUID().uuidString)", isDirectory: true)

        let store = TickerStore(directory: dir)
        store.dailyGoalMinutes = 300
        store.idleThreshold = 120
        store.moveBreakDurationMinutes = 3
        store.setCategory(.distracting, for: "app.x")
        TestSupport.addActive(store, minute: fixedDay.addingTimeInterval(3600), bundle: "app.x", seconds: 20)
        store.save()

        let reloaded = TickerStore(directory: dir)
        XCTAssertEqual(reloaded.dailyGoalMinutes, 300)
        XCTAssertEqual(reloaded.idleThreshold, 120)
        XCTAssertEqual(reloaded.moveBreakDurationMinutes, 3)
        XCTAssertEqual(reloaded.category(for: "app.x"), .distracting)
        XCTAssertEqual(reloaded.records(in: Timescale.day.interval(containing: fixedDay)).count, 1)
    }

    func testClearAllDataEmptiesRecords() {
        let store = TestSupport.makeStore()
        TestSupport.addActive(store, minute: fixedDay.addingTimeInterval(3600), bundle: "a", seconds: 10)
        XCTAssertFalse(store.records(in: Timescale.day.interval(containing: fixedDay)).isEmpty)

        store.clearAllData()
        XCTAssertTrue(store.records(in: Timescale.day.interval(containing: fixedDay)).isEmpty)
    }

    func testTolerantDecodeFillsDefaults() throws {
        // An empty object decodes to all defaults — adding fields never
        // invalidates an existing on-disk file.
        let decoded = try JSONDecoder().decode(PersistedData.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded.dailyGoalMinutes, 240)
        XCTAssertEqual(decoded.idleThreshold, 90)
        XCTAssertEqual(decoded.moveBreakMinutes, 30)
        XCTAssertEqual(decoded.screenBreakMinutes, 60)
        XCTAssertEqual(decoded.moveBreakDurationMinutes, 2)
        XCTAssertEqual(decoded.screenBreakDurationMinutes, 5)
        XCTAssertTrue(decoded.breakRemindersEnabled)
    }

    func testMinuteRecordTolerantDecode() throws {
        let rec = try JSONDecoder().decode(MinuteRecord.self, from: Data(#"{"minute": 800000000}"#.utf8))
        XCTAssertEqual(rec.activeSeconds, 0)
        XCTAssertEqual(rec.keyCount, 0)
        XCTAssertTrue(rec.appSeconds.isEmpty)
    }
}
