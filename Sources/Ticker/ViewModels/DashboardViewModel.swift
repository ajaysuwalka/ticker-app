import SwiftUI
import AppKit

/// Owns the dashboard's state and logic: which period is shown, the on-demand
/// data snapshot, refresh cadence, and user actions. The view is purely
/// declarative on top of it. Kept intentionally small — one focused
/// `ObservableObject`, no extra layers.
@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var scope: Timescale = .day { didSet { if oldValue != scope { rebuild() } } }
    @Published var anchor: Date = Date() { didSet { if oldValue != anchor { rebuild() } } }
    @Published private(set) var snapshot = DashboardSnapshot()
    @Published private(set) var lastRefreshed = Date()
    @Published private(set) var accessibilityGranted = Permissions.isAccessibilityTrusted

    private let store: TickerStore
    private var appActive = true
    private static let refreshInterval: TimeInterval = 300   // 5 minutes

    init(store: TickerStore) { self.store = store }

    // MARK: - Derived

    var interval: DateInterval { scope.interval(containing: anchor) }
    var isCurrentPeriod: Bool { interval.contains(Date()) }
    private var isStale: Bool { Date().timeIntervalSince(lastRefreshed) >= Self.refreshInterval }

    /// Elapsed days within the current period (full length for past periods).
    var goalDays: Int {
        let cal = Calendar.current
        let start = interval.start.startOfDay
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date().startOfDay) ?? interval.end
        let last = min(interval.end, tomorrow)
        return max(1, cal.dateComponents([.day], from: start, to: last).day ?? 1)
    }
    var goalSeconds: Int { snapshot.dailyGoalMinutes * 60 * snapshot.goalDays }
    var goalProgress: Double {
        goalSeconds > 0 ? Double(snapshot.focusedSeconds) / Double(goalSeconds) : 0
    }

    var daysWithData: Set<Date> { Set(store.daysWithData()) }

    /// Day scope trends over the trailing 14 days; week/month over the period.
    private var trendInterval: DateInterval {
        guard scope == .day else { return interval }
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: anchor.startOfDay) ?? anchor
        let start = cal.date(byAdding: .day, value: -13, to: anchor.startOfDay) ?? end
        return DateInterval(start: start, end: end)
    }

    // MARK: - Lifecycle

    func onAppear() {
        appActive = NSApp.isActive
        accessibilityGranted = Permissions.isAccessibilityTrusted
        rebuild()
    }

    /// Called by the 1-minute UI timer; only refreshes when active and stale.
    func tick() {
        accessibilityGranted = Permissions.isAccessibilityTrusted
        if appActive && isStale { rebuild() }
    }

    func appBecameActive() {
        appActive = true
        accessibilityGranted = Permissions.isAccessibilityTrusted   // reflect a just-granted permission
        if isStale { rebuild() }
    }

    func appResignedActive() { appActive = false }

    // MARK: - Navigation

    func shift(_ direction: Int) {
        let cal = Calendar.current
        guard let moved = cal.date(byAdding: scope.component, value: direction, to: anchor) else { return }
        if direction > 0 && scope.interval(containing: moved).start > Date() { return }   // no future
        anchor = moved   // triggers rebuild via didSet
    }

    func goToToday() { anchor = Date() }

    // MARK: - Actions

    func moveApp(_ bundleId: String, to category: AppCategory) {
        store.setCategory(category, for: bundleId)
        rebuild()
    }

    func deleteBlockScreenshots(_ block: ActivityBlock) {
        store.deleteScreenshots(in: DateInterval(start: block.start, end: block.end))
        rebuild()
    }

    func deleteScreenshot(_ url: URL) {
        store.deleteScreenshot(at: url)
        rebuild()
    }

    func exportCSV() { CSVExporter.exportSummaries(store: store) }

    func exportWeeklyPDF() {
        PDFReporter.export(store: store, interval: Timescale.week.interval(containing: anchor),
                           title: "Weekly Report", monthly: false)
    }

    func exportMonthlyPDF() {
        PDFReporter.export(store: store, interval: Timescale.month.interval(containing: anchor),
                           title: "Monthly Report", monthly: true)
    }

    // MARK: - Snapshot

    /// Runs every heavy query once and stores the results. Called on appear,
    /// on scope/date change, every 5 minutes (while active), and on refresh.
    func rebuild() {
        var s = DashboardSnapshot()
        s.scope = scope
        s.summary = store.summary(in: interval)
        if scope == .day {
            s.dayBuckets = store.activityBuckets(on: anchor)
            s.minuteCells = store.minuteTimeline(on: anchor)
            s.shots = store.screenshots(on: anchor)
            s.blocks = store.activityBlocks(on: anchor)
        } else {
            s.breakdowns = store.dailyBreakdowns(in: interval)
        }
        s.captureEnabled = store.captureScreenshots
        s.trend = store.dailyProductivity(in: trendInterval)
        s.hourStats = store.hourlyStats(in: interval)
        s.sessions = store.focusSessions(in: interval)
        s.streak = store.focusStreakDays()
        s.contextSwitches = store.contextSwitches(in: interval)
        s.goalDays = goalDays
        s.dailyGoalMinutes = store.dailyGoalMinutes
        s.focusedSeconds = store.focusedSeconds(in: interval)
        s.weeklyActiveSeconds = store.summary(in: Timescale.week.interval(containing: anchor)).activeSeconds
        s.weeklyGoalHours = store.weeklyGoalHours
        s.excludedApps = store.knownApps().filter { $0.category == .excluded }
        s.recap = store.weeklyRecap()
        snapshot = s
        lastRefreshed = Date()
    }
}
