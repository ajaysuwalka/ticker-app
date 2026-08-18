import Foundation
import Combine

/// The single source of truth for persisted data: per-minute records, discovered
/// app names, category assignments, and user settings. Handles recording,
/// persistence, and on-disk screenshot management. Derived/aggregated reads live
/// in `TickerStore+Analytics`.
///
/// `recordsByMinute` is intentionally **not** `@Published` — it mutates every
/// second while tracking, and views read it through on-demand snapshots rather
/// than re-rendering on every tick.
@MainActor
final class TickerStore: ObservableObject {
    private(set) var recordsByMinute: [Date: MinuteRecord] = [:]
    @Published private(set) var appNames: [String: String] = [:]
    @Published private var categoryOverrides: [String: AppCategory] = [:]

    @Published var idleThreshold = 90 { didSet { scheduleSave() } }
    @Published var dailyGoalMinutes = 240 { didSet { scheduleSave() } }
    @Published var weeklyGoalHours = 40 { didSet { scheduleSave() } }
    @Published var notifyOnGoal = false { didSet { scheduleSave() } }
    @Published var captureScreenshots = false { didSet { scheduleSave() } }
    @Published var captureIntervalMinutes = 5 { didSet { scheduleSave() } }
    @Published var screenshotRetentionDays = 2 { didSet { scheduleSave(); pruneScreenshots() } }
    @Published var breakRemindersEnabled = true { didSet { scheduleSave() } }
    @Published var moveBreakMinutes = 30 { didSet { scheduleSave() } }
    @Published var screenBreakMinutes = 60 { didSet { scheduleSave() } }
    @Published var moveBreakDurationMinutes = 2 { didSet { scheduleSave() } }
    @Published var screenBreakDurationMinutes = 5 { didSet { scheduleSave() } }
    @Published var minBreakGapMinutes = 30 { didSet { scheduleSave() } }
    @Published var breakOverlayAllScreens = true { didSet { scheduleSave() } }

    let screenshotsDirectory: URL
    private let fileURL: URL
    private var savePending = false

    /// - Parameter directory: storage location; defaults to the app-support dir.
    ///   Tests pass a temporary directory for deterministic, isolated state.
    init(directory: URL? = nil) {
        let fm = FileManager.default
        let dir: URL
        if let directory {
            dir = directory
        } else {
            let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            dir = support.appendingPathComponent("Ticker", isDirectory: true)
            // One-time migration from the app's former name ("Pulse") so existing
            // users keep their tracked data and screenshots after the rename.
            let legacy = support.appendingPathComponent("Pulse", isDirectory: true)
            if !fm.fileExists(atPath: dir.path), fm.fileExists(atPath: legacy.path) {
                try? fm.moveItem(at: legacy, to: dir)
            }
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")
        screenshotsDirectory = dir.appendingPathComponent("shots", isDirectory: true)
        load()
        pruneScreenshots()
    }

    // MARK: - Recording

    func addTick(minute: Date, bundleId: String?, appName: String?, active: Bool,
                 keys: Int, mouse: Int, switched: Bool, context: String?) {
        var rec = recordsByMinute[minute]
            ?? MinuteRecord(minute: minute, appSeconds: [:], keyCount: 0, mouseCount: 0, activeSeconds: 0)
        rec.keyCount += keys
        rec.mouseCount += mouse
        if switched { rec.switchCount += 1 }
        if active {
            rec.activeSeconds += 1
            if let bundleId { rec.appSeconds[bundleId, default: 0] += 1 }
            if let context { rec.contextSeconds[context, default: 0] += 1 }
        }
        recordsByMinute[minute] = rec

        if let bundleId, let appName, appNames[bundleId] != appName {
            appNames[bundleId] = appName
        }
        scheduleSave()
    }

    // MARK: - Categorization

    func category(for bundleId: String) -> AppCategory {
        if let override = categoryOverrides[bundleId] { return override }
        return CategoryGuesser.guess(bundleId: bundleId, name: appNames[bundleId] ?? "")
    }

    func isUserAssigned(_ bundleId: String) -> Bool {
        categoryOverrides[bundleId] != nil
    }

    func setCategory(_ category: AppCategory, for bundleId: String) {
        categoryOverrides[bundleId] = category
        scheduleSave()
    }

    // MARK: - Idle review

    /// Pseudo-app id representing away-from-keyboard time the user confirmed was
    /// productive (e.g. a meeting), so it aggregates like any other productive app.
    static let meetingBundleId = "ticker.meeting"

    /// Fill an away period with productive "Meeting" time — the user confirmed the
    /// idle stretch was a meeting / focused work away from the keyboard.
    func markIntervalAsMeeting(_ interval: DateInterval) {
        if appNames[Self.meetingBundleId] != "Meeting" { appNames[Self.meetingBundleId] = "Meeting" }
        categoryOverrides[Self.meetingBundleId] = .productive
        var minute = interval.start.startOfMinute
        while minute < interval.end {
            var rec = recordsByMinute[minute]
                ?? MinuteRecord(minute: minute, appSeconds: [:], keyCount: 0, mouseCount: 0, activeSeconds: 0)
            rec.appSeconds[Self.meetingBundleId] = 60
            rec.activeSeconds = 60
            recordsByMinute[minute] = rec
            minute = minute.addingTimeInterval(60)
        }
        scheduleSave()
    }

    /// Drop every per-minute record within a window — the user discarded the idle
    /// time so it stops counting against active/tracked totals.
    func deleteRecords(in interval: DateInterval) {
        var minute = interval.start.startOfMinute
        while minute < interval.end {
            recordsByMinute[minute] = nil
            minute = minute.addingTimeInterval(60)
        }
        scheduleSave()
    }

    // MARK: - Screenshot files

    func pruneScreenshots() {
        let cutoff = Date().addingTimeInterval(-Double(screenshotRetentionDays) * 86_400)
        forEachScreenshot { url, minute in
            if minute < cutoff { try? FileManager.default.removeItem(at: url) }
        }
    }

    func clearScreenshots() {
        try? FileManager.default.removeItem(at: screenshotsDirectory)
        try? FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
    }

    /// Delete a single screenshot (e.g. one that captured sensitive content).
    func deleteScreenshot(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Delete every screenshot captured within a time window (a whole block).
    func deleteScreenshots(in interval: DateInterval) {
        forEachScreenshot { url, minute in
            if minute >= interval.start && minute < interval.end {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Iterates saved screenshot files, decoding the minute from each filename.
    func forEachScreenshot(_ body: (_ url: URL, _ minute: Date) -> Void) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: screenshotsDirectory, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "jpg" {
            guard let secs = Double(file.deletingPathExtension().lastPathComponent) else { continue }
            body(file, Date(timeIntervalSinceReferenceDate: secs))
        }
    }

    // MARK: - Persistence

    func clearAllData() {
        recordsByMinute = [:]
        appNames = [:]
        clearScreenshots()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(PersistedData.self, from: data) else { return }

        // uniquingKeysWith (not uniqueKeysWithValues) so a corrupted or hand-edited
        // file with duplicate minutes can't crash the app on launch.
        recordsByMinute = Dictionary(decoded.records.map { ($0.minute, $0) },
                                     uniquingKeysWith: { _, newer in newer })
        appNames = decoded.appNames
        categoryOverrides = decoded.categories.reduce(into: [:]) { acc, pair in
            if let cat = AppCategory(rawValue: pair.value) { acc[pair.key] = cat }
        }
        idleThreshold = decoded.idleThreshold
        dailyGoalMinutes = decoded.dailyGoalMinutes
        weeklyGoalHours = decoded.weeklyGoalHours
        notifyOnGoal = decoded.notifyOnGoal
        captureScreenshots = decoded.captureScreenshots
        captureIntervalMinutes = decoded.captureIntervalMinutes
        screenshotRetentionDays = decoded.screenshotRetentionDays
        breakRemindersEnabled = decoded.breakRemindersEnabled
        moveBreakMinutes = decoded.moveBreakMinutes
        screenBreakMinutes = decoded.screenBreakMinutes
        moveBreakDurationMinutes = decoded.moveBreakDurationMinutes
        screenBreakDurationMinutes = decoded.screenBreakDurationMinutes
        minBreakGapMinutes = decoded.minBreakGapMinutes
        breakOverlayAllScreens = decoded.breakOverlayAllScreens
    }

    /// Coalescing debounce: the first change schedules a flush ~10s out; further
    /// changes in that window ride along rather than resetting the timer, so
    /// continuous per-second activity still gets persisted on a fixed cadence.
    private func scheduleSave() {
        guard !savePending else { return }
        savePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.savePending = false
            self?.save()
        }
    }

    func save() {
        let payload = PersistedData(
            records: Array(recordsByMinute.values).sorted { $0.minute < $1.minute },
            appNames: appNames,
            categories: categoryOverrides.mapValues { $0.rawValue },
            idleThreshold: idleThreshold,
            dailyGoalMinutes: dailyGoalMinutes,
            weeklyGoalHours: weeklyGoalHours,
            notifyOnGoal: notifyOnGoal,
            captureScreenshots: captureScreenshots,
            captureIntervalMinutes: captureIntervalMinutes,
            screenshotRetentionDays: screenshotRetentionDays,
            breakRemindersEnabled: breakRemindersEnabled,
            moveBreakMinutes: moveBreakMinutes,
            screenBreakMinutes: screenBreakMinutes,
            moveBreakDurationMinutes: moveBreakDurationMinutes,
            screenBreakDurationMinutes: screenBreakDurationMinutes,
            minBreakGapMinutes: minBreakGapMinutes,
            breakOverlayAllScreens: breakOverlayAllScreens
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
