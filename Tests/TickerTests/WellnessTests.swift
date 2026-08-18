import XCTest
@testable import Ticker

final class WellnessTests: XCTestCase {

    func testBreakKindLabelsAndSymbols() {
        XCTAssertEqual(BreakKind.move.shortLabel, "Move")
        XCTAssertEqual(BreakKind.screen.shortLabel, "Eyes")
        XCTAssertEqual(BreakKind.move.symbol, "figure.walk")
        XCTAssertEqual(BreakKind.screen.symbol, "eye")
    }

    func testIdlePeriodMinutesRoundsDown() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let period = IdlePeriod(start: start, end: start.addingTimeInterval(23 * 60 + 30))
        XCTAssertEqual(period.minutes, 23)
    }

    func testCountdownFormatting() {
        XCTAssertEqual(SidebarBreaksView.format(0), "0:00")
        XCTAssertEqual(SidebarBreaksView.format(59), "0:59")
        XCTAssertEqual(SidebarBreaksView.format(90), "1:30")
        XCTAssertEqual(SidebarBreaksView.format(3661), "1:01:01")
    }

    @MainActor
    func testSettingsPersistAcrossReload() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticker-tests-\(UUID().uuidString)", isDirectory: true)
        let store = TickerStore(directory: dir)
        store.moveBreakMinutes = 20
        store.screenBreakDurationMinutes = 15
        store.save()

        let reloaded = TickerStore(directory: dir)
        XCTAssertEqual(reloaded.moveBreakMinutes, 20)
        XCTAssertEqual(reloaded.screenBreakDurationMinutes, 15)
    }
}
