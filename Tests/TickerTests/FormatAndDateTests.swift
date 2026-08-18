import XCTest
@testable import Ticker

final class FormatAndDateTests: XCTestCase {

    func testDuration() {
        XCTAssertEqual(Format.duration(0), "0s")
        XCTAssertEqual(Format.duration(45), "45s")
        XCTAssertEqual(Format.duration(90), "1m")
        XCTAssertEqual(Format.duration(3661), "1h 1m")
    }

    func testCompactDuration() {
        XCTAssertEqual(Format.compactDuration(120), "2m")
        XCTAssertEqual(Format.compactDuration(3600), "1h")
        XCTAssertEqual(Format.compactDuration(3660), "1h 1m")
    }

    func testPercent() {
        XCTAssertEqual(Format.percent(0), "0%")
        XCTAssertEqual(Format.percent(0.5), "50%")
        XCTAssertEqual(Format.percent(0.999), "100%")
        XCTAssertEqual(Format.percent(1), "100%")
    }

    func testHourLabel() {
        XCTAssertEqual(Format.hourLabel(0), "12 AM")
        XCTAssertEqual(Format.hourLabel(9), "9 AM")
        XCTAssertEqual(Format.hourLabel(12), "12 PM")
        XCTAssertEqual(Format.hourLabel(13), "1 PM")
        XCTAssertEqual(Format.hourLabel(23), "11 PM")
    }

    func testWeekRunsMondayToSunday() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // 2026-08-12 is a Wednesday.
        let wed = cal.date(from: DateComponents(year: 2026, month: 8, day: 12))!
        let week = Timescale.week.interval(containing: wed, calendar: cal)

        let startWeekday = cal.component(.weekday, from: week.start)   // 2 = Monday
        let lastDay = week.end.addingTimeInterval(-1)
        let endWeekday = cal.component(.weekday, from: lastDay)        // 1 = Sunday
        XCTAssertEqual(startWeekday, 2, "week should start on Monday")
        XCTAssertEqual(endWeekday, 1, "week should end on Sunday")
        XCTAssertEqual(Int(week.duration), 7 * 86_400)
    }

    func testStartOfMinuteAndDay() {
        let d = Date(timeIntervalSinceReferenceDate: 800_000_045.7)
        let secondsIntoMinute = d.startOfMinute.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 60)
        XCTAssertEqual(secondsIntoMinute, 0, accuracy: 0.001)
        XCTAssertLessThanOrEqual(d.startOfDay, d)
        XCTAssertEqual(d.startOfDay, d.startOfDay.startOfDay)   // idempotent
    }
}
