import Foundation
import SwiftUI

// MARK: - Productivity category

enum AppCategory: String, Codable, CaseIterable, Identifiable {
    case productive
    case neutral
    case distracting
    case excluded          // not tracked at all

    var id: String { rawValue }

    /// Categories that count toward tracked time (everything except Excluded).
    static var tracked: [AppCategory] { [.productive, .neutral, .distracting] }

    /// Whether time in this category is recorded/counted.
    var isTracked: Bool { self != .excluded }

    var title: String {
        switch self {
        case .productive: return tr("Productive")
        case .neutral: return tr("Neutral")
        case .distracting: return tr("Distracting")
        case .excluded: return tr("Excluded")
        }
    }

    var symbol: String {
        switch self {
        case .productive: return "checkmark.seal.fill"
        case .neutral: return "circle.fill"
        case .distracting: return "exclamationmark.triangle.fill"
        case .excluded: return "nosign"
        }
    }

    var color: Color {
        switch self {
        case .productive: return Color(red: 0.20, green: 0.78, blue: 0.45)
        case .neutral: return Color(red: 0.38, green: 0.55, blue: 0.95)
        case .distracting: return Color(red: 0.98, green: 0.55, blue: 0.20)
        case .excluded: return Color(white: 0.5)
        }
    }
}

// MARK: - Persisted per-minute record

/// One record per wall-clock minute. `appSeconds` counts only *active* seconds
/// (keyboard/mouse activity or within the idle threshold) attributed to the
/// frontmost app, so productive time reflects real engagement.
struct MinuteRecord: Codable, Identifiable {
    let minute: Date                 // truncated to the start of the minute
    var appSeconds: [String: Int]    // bundleId -> active seconds
    var keyCount: Int
    var mouseCount: Int
    var activeSeconds: Int
    var switchCount: Int = 0          // frontmost-app changes within the minute
    var contextSeconds: [String: Int] = [:]   // window title (tab/project) -> active seconds

    var id: Date { minute }

    var interactions: Int { keyCount + mouseCount }
}

// Tolerant decoding so adding fields (e.g. switchCount) never invalidates
// existing records on disk.
extension MinuteRecord {
    enum CodingKeys: String, CodingKey {
        case minute, appSeconds, keyCount, mouseCount, activeSeconds, switchCount, contextSeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        minute = try c.decode(Date.self, forKey: .minute)
        appSeconds = try c.decodeIfPresent([String: Int].self, forKey: .appSeconds) ?? [:]
        keyCount = try c.decodeIfPresent(Int.self, forKey: .keyCount) ?? 0
        mouseCount = try c.decodeIfPresent(Int.self, forKey: .mouseCount) ?? 0
        activeSeconds = try c.decodeIfPresent(Int.self, forKey: .activeSeconds) ?? 0
        switchCount = try c.decodeIfPresent(Int.self, forKey: .switchCount) ?? 0
        contextSeconds = try c.decodeIfPresent([String: Int].self, forKey: .contextSeconds) ?? [:]
    }
}

/// A stretch of ≥10 minutes with no keyboard/mouse activity, surfaced when the
/// user comes back so they can label it: a meeting/away-from-keyboard focus (→
/// counted as productive) or dead time (→ deleted).
struct IdlePeriod: Equatable {
    let start: Date
    let end: Date
    var interval: DateInterval { DateInterval(start: start, end: end) }
    var minutes: Int { max(1, Int(end.timeIntervalSince(start) / 60)) }
}

/// Active time and interactions grouped by hour-of-day (0–23).
struct HourStat: Identifiable {
    let hour: Int
    let activeSeconds: Int
    let interactions: Int
    var id: Int { hour }
}

/// One minute of the day for the minute-level timeline strip.
struct MinuteCell: Identifiable {
    let index: Int              // 0..<1440
    let minute: Date
    let category: AppCategory?  // dominant app's category, nil when idle
    let active: Bool
    var id: Int { index }
}

/// A per-minute screen thumbnail plus the app that was in focus.
struct ScreenShot: Identifiable {
    let minute: Date
    let url: URL
    let appName: String
    let category: AppCategory
    var id: Date { minute }
}

/// One minute of keyboard/mouse activity within an activity block.
struct MinuteEntry: Identifiable {
    let minute: Date
    let keys: Int
    let clicks: Int
    let appName: String
    let bundleId: String?
    let context: String?
    let category: AppCategory
    var id: Date { minute }
}

/// A 10-minute window: the screen you were on, block totals, and the per-minute
/// keyboard/mouse breakdown.
struct ActivityBlock: Identifiable {
    let start: Date
    let keys: Int
    let clicks: Int
    let appName: String
    let bundleId: String?
    let context: String?
    let category: AppCategory
    let shotURL: URL?
    let minutes: [MinuteEntry]
    var id: Date { start }
    var end: Date { start.addingTimeInterval(600) }
}

// MARK: - Derived day summary

struct AppTotal: Identifiable {
    let bundleId: String
    let name: String
    let seconds: Int
    let category: AppCategory
    var id: String { bundleId }
}

struct DaySummary {
    var activeSeconds: Int = 0
    var productiveSeconds: Int = 0
    var neutralSeconds: Int = 0
    var distractingSeconds: Int = 0
    var keyCount: Int = 0
    var mouseCount: Int = 0
    var apps: [AppTotal] = []

    var productivity: Double {
        activeSeconds > 0 ? Double(productiveSeconds) / Double(activeSeconds) : 0
    }
}

struct ActivityBucket: Identifiable {
    let date: Date
    let interactions: Int
    var id: Date { date }
}

// MARK: - Time scope (calendar filtering)

enum Timescale: String, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return tr("Day")
        case .week: return tr("Week")
        case .month: return tr("Month")
        }
    }

    var component: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    /// The date interval this scope covers around `date` (half-open: [start, end)).
    func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .day:
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .week:
            var weekCal = calendar
            weekCal.firstWeekday = 2      // weeks run Monday–Sunday
            return weekCal.dateInterval(of: .weekOfYear, for: date)
                ?? DateInterval(start: date.startOfDay, duration: 7 * 86_400)
        case .month:
            return calendar.dateInterval(of: .month, for: date)
                ?? DateInterval(start: date.startOfDay, duration: 30 * 86_400)
        }
    }
}

/// Per-day category totals, used for the week/month stacked bar chart.
struct DayBreakdown: Identifiable {
    let date: Date
    let productive: Int
    let neutral: Int
    let distracting: Int
    var id: Date { date }

    var total: Int { productive + neutral + distracting }

    func seconds(for category: AppCategory) -> Int {
        switch category {
        case .productive: return productive
        case .neutral: return neutral
        case .distracting: return distracting
        case .excluded: return 0
        }
    }
}

/// One day's productivity ratio, for the trend line.
struct ProductivityPoint: Identifiable {
    let date: Date
    let productivity: Double
    let activeSeconds: Int
    var id: Date { date }
}

/// A flattened (day, category) point so Swift Charts can stack bars by series.
struct DaySeriesPoint: Identifiable {
    let date: Date
    let category: AppCategory
    let seconds: Int
    var id: String { "\(date.timeIntervalSince1970)-\(category.rawValue)" }
}

/// A digest comparing the trailing 7 days to the previous 7.
struct WeeklyRecap {
    var productiveSeconds: Int = 0
    var previousProductiveSeconds: Int = 0
    var avgProductivity: Double = 0
    var bestDay: Date? = nil
    var bestDaySeconds: Int = 0
    var topApp: String? = nil
    var topAppSeconds: Int = 0

    /// Change vs. the previous week as a signed fraction (e.g. +0.2 = +20%).
    var deltaFraction: Double {
        if previousProductiveSeconds > 0 {
            return Double(productiveSeconds - previousProductiveSeconds) / Double(previousProductiveSeconds)
        }
        return productiveSeconds > 0 ? 1 : 0
    }

    var hasData: Bool { productiveSeconds > 0 || previousProductiveSeconds > 0 }
}

// MARK: - Dashboard layout

/// A configurable card on the Overview screen. The raw value is the stable key
/// persisted in `PersistedData.hiddenDashboardWidgets` and used to reorder cards,
/// so it must never change once shipped.
enum DashboardWidget: String, CaseIterable, Codable, Identifiable {
    // Declaration order is the default Overview layout. Weekly hours leads, then
    // the stat tiles, then the side-by-side focus/activity/trend row.
    case weeklyHours
    case stats
    case focusGoal
    case activity
    case trend

    var id: String { rawValue }

    /// Human-readable name shown in the layout editor.
    var title: String {
        switch self {
        case .stats: return tr("Stat tiles")
        case .focusGoal: return tr("Focus goal")
        case .activity: return tr("Activity graph")
        case .trend: return tr("Productivity trend")
        case .weeklyHours: return tr("Weekly hours")
        }
    }

    /// One-line description shown under the title in the layout editor.
    var blurb: String {
        switch self {
        case .stats: return tr("Tracked, focus, keys & clicks at a glance")
        case .focusGoal: return tr("Daily focus ring and streak")
        case .activity: return tr("Per-hour activity for the period")
        case .trend: return tr("Productive vs. distracting over time")
        case .weeklyHours: return tr("Progress toward your weekly hours goal")
        }
    }

    var systemImage: String {
        switch self {
        case .stats: return "square.grid.2x2"
        case .focusGoal: return "target"
        case .activity: return "waveform.path.ecg"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .weeklyHours: return "calendar"
        }
    }
}

// MARK: - Persistence container

struct PersistedData: Codable {
    var records: [MinuteRecord] = []
    var appNames: [String: String] = [:]
    var categories: [String: String] = [:]   // bundleId -> AppCategory.rawValue (user overrides)
    var idleThreshold: Int = 90
    var dailyGoalMinutes: Int = 240
    var weeklyGoalHours: Int = 40        // target total tracked hours per week
    var notifyOnGoal: Bool = false
    var captureScreenshots: Bool = false
    var captureIntervalMinutes: Int = 5
    var screenshotRetentionDays: Int = 2
    var breakRemindersEnabled: Bool = true
    var moveBreakMinutes: Int = 30       // stand up & move (interval)
    var screenBreakMinutes: Int = 60     // look away from the screen (interval)
    var moveBreakDurationMinutes: Int = 2     // how long the move break countdown runs
    var screenBreakDurationMinutes: Int = 5   // how long the screen break countdown runs
    var minBreakGapMinutes: Int = 30          // minimum active time between any two breaks
    var breakOverlayAllScreens: Bool = true   // float the reminder above all apps
    // Overview layout: the order cards appear in, and which are hidden. Empty
    // order means "use the default order"; unknown/new keys are appended.
    var dashboardWidgetOrder: [String] = []
    var hiddenDashboardWidgets: [String] = []
    // Whether the user has hand-customized the layout. Until they do, the app
    // follows the built-in default order, so shipping a new default order (or a
    // new card) reaches existing users instead of being frozen at install time.
    var dashboardLayoutCustomized: Bool = false
}

// Tolerant decoding: missing keys fall back to defaults instead of throwing, so
// adding a new field never invalidates an existing data file. Defined in an
// extension so the memberwise initializer is preserved for saving.
extension PersistedData {
    enum CodingKeys: String, CodingKey {
        case records, appNames, categories, idleThreshold, dailyGoalMinutes, weeklyGoalHours
        case notifyOnGoal, captureScreenshots, captureIntervalMinutes, screenshotRetentionDays
        case breakRemindersEnabled, moveBreakMinutes, screenBreakMinutes
        case moveBreakDurationMinutes, screenBreakDurationMinutes, minBreakGapMinutes
        case breakOverlayAllScreens
        case dashboardWidgetOrder, hiddenDashboardWidgets, dashboardLayoutCustomized
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        records = try c.decodeIfPresent([MinuteRecord].self, forKey: .records) ?? records
        appNames = try c.decodeIfPresent([String: String].self, forKey: .appNames) ?? appNames
        categories = try c.decodeIfPresent([String: String].self, forKey: .categories) ?? categories
        idleThreshold = try c.decodeIfPresent(Int.self, forKey: .idleThreshold) ?? idleThreshold
        dailyGoalMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyGoalMinutes) ?? dailyGoalMinutes
        weeklyGoalHours = try c.decodeIfPresent(Int.self, forKey: .weeklyGoalHours) ?? weeklyGoalHours
        notifyOnGoal = try c.decodeIfPresent(Bool.self, forKey: .notifyOnGoal) ?? notifyOnGoal
        captureScreenshots = try c.decodeIfPresent(Bool.self, forKey: .captureScreenshots) ?? captureScreenshots
        captureIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .captureIntervalMinutes) ?? captureIntervalMinutes
        screenshotRetentionDays = try c.decodeIfPresent(Int.self, forKey: .screenshotRetentionDays) ?? screenshotRetentionDays
        breakRemindersEnabled = try c.decodeIfPresent(Bool.self, forKey: .breakRemindersEnabled) ?? breakRemindersEnabled
        moveBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .moveBreakMinutes) ?? moveBreakMinutes
        screenBreakMinutes = try c.decodeIfPresent(Int.self, forKey: .screenBreakMinutes) ?? screenBreakMinutes
        moveBreakDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .moveBreakDurationMinutes) ?? moveBreakDurationMinutes
        screenBreakDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .screenBreakDurationMinutes) ?? screenBreakDurationMinutes
        minBreakGapMinutes = try c.decodeIfPresent(Int.self, forKey: .minBreakGapMinutes) ?? minBreakGapMinutes
        breakOverlayAllScreens = try c.decodeIfPresent(Bool.self, forKey: .breakOverlayAllScreens) ?? breakOverlayAllScreens
        dashboardWidgetOrder = try c.decodeIfPresent([String].self, forKey: .dashboardWidgetOrder) ?? dashboardWidgetOrder
        hiddenDashboardWidgets = try c.decodeIfPresent([String].self, forKey: .hiddenDashboardWidgets) ?? hiddenDashboardWidgets
        dashboardLayoutCustomized = try c.decodeIfPresent(Bool.self, forKey: .dashboardLayoutCustomized) ?? dashboardLayoutCustomized
    }
}

// MARK: - Formatting helpers

enum Format {
    static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(seconds)s"
    }

    static func compactDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h\(m > 0 ? " \(m)m" : "")" }
        return "\(m)m"
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func hourLabel(_ hour: Int) -> String {
        let h = ((hour % 12) == 0) ? 12 : hour % 12
        return "\(h) \(hour < 12 ? "AM" : "PM")"
    }
}

extension Calendar {
    /// The current calendar with weeks starting on Monday (Mon–Sun).
    static var mondayFirst: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2   // Monday
        return c
    }
}

extension Date {
    var startOfMinute: Date {
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return Calendar.current.date(from: c) ?? self
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
