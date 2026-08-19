import XCTest
@testable import Ticker

@MainActor
final class DashboardLayoutTests: XCTestCase {

    func testDefaultLayoutShowsEveryWidgetInOrder() {
        let store = TestSupport.makeStore()
        XCTAssertEqual(store.dashboardWidgetOrder, DashboardWidget.allCases)
        XCTAssertTrue(store.hiddenDashboardWidgets.isEmpty)
        XCTAssertEqual(store.visibleDashboardWidgets, DashboardWidget.allCases)
    }

    func testWeeklyHoursLeadsTheDefaultLayout() {
        XCTAssertEqual(DashboardWidget.allCases.first, .weeklyHours)
        XCTAssertEqual(TestSupport.makeStore().visibleDashboardWidgets.first, .weeklyHours)
    }

    func testNonCustomizedLayoutFollowsCurrentDefault() {
        // A file with a stale saved order but no customization must fall through
        // to the built-in default order (so shipping a new default reaches it).
        var data = PersistedData()
        data.dashboardLayoutCustomized = false
        data.dashboardWidgetOrder = ["stats", "focusGoal", "activity", "trend", "weeklyHours"]
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticker-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? JSONEncoder().encode(data).write(to: dir.appendingPathComponent("data.json"))

        let store = TickerStore(directory: dir)
        XCTAssertEqual(store.dashboardWidgetOrder, DashboardWidget.allCases)
        XCTAssertEqual(store.dashboardWidgetOrder.first, .weeklyHours)
    }

    func testHidingAndShowingWidgets() {
        let store = TestSupport.makeStore()
        store.setWidget(.activity, visible: false)
        XCTAssertFalse(store.isWidgetVisible(.activity))
        XCTAssertFalse(store.visibleDashboardWidgets.contains(.activity))
        // Order is preserved even while hidden.
        XCTAssertTrue(store.dashboardWidgetOrder.contains(.activity))

        store.setWidget(.activity, visible: true)
        XCTAssertTrue(store.isWidgetVisible(.activity))
        XCTAssertTrue(store.visibleDashboardWidgets.contains(.activity))
    }

    func testReorderAndResetLayout() {
        let store = TestSupport.makeStore()
        store.moveWidget(fromOffsets: IndexSet(integer: 0), toOffset: DashboardWidget.allCases.count)
        XCTAssertNotEqual(store.dashboardWidgetOrder.first, DashboardWidget.allCases.first)

        store.resetDashboardLayout()
        XCTAssertEqual(store.dashboardWidgetOrder, DashboardWidget.allCases)
        XCTAssertTrue(store.hiddenDashboardWidgets.isEmpty)
    }

    func testLayoutRoundTrips() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticker-tests-\(UUID().uuidString)", isDirectory: true)

        let store = TickerStore(directory: dir)
        store.setWidget(.weeklyHours, visible: false)
        store.moveWidget(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        let expectedOrder = store.dashboardWidgetOrder
        store.save()

        let reloaded = TickerStore(directory: dir)
        XCTAssertEqual(reloaded.dashboardWidgetOrder, expectedOrder)
        XCTAssertFalse(reloaded.isWidgetVisible(.weeklyHours))
    }

    func testResolveOrderAppendsNewWidgetsAndDropsUnknown() {
        // A file saved by an older version knows only a subset of widgets, plus a
        // stale key. On load the known order is preserved, the stale key dropped,
        // and any newer widgets appended so nothing silently disappears.
        var data = PersistedData()
        data.dashboardLayoutCustomized = true   // otherwise the built-in default order is used
        data.dashboardWidgetOrder = ["weeklyHours", "stats", "ghost-widget"]
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ticker-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("data.json")
        try? JSONEncoder().encode(data).write(to: file)

        let store = TickerStore(directory: dir)
        XCTAssertEqual(store.dashboardWidgetOrder.prefix(2), [.weeklyHours, .stats])
        XCTAssertFalse(store.dashboardWidgetOrder.contains { $0.rawValue == "ghost-widget" })
        XCTAssertEqual(Set(store.dashboardWidgetOrder), Set(DashboardWidget.allCases))
    }
}
