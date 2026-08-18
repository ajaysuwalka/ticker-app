import AppKit
import Combine
import CoreGraphics

/// The engine: once per second it samples the frontmost app, folds in the
/// keyboard/mouse counts collected since the last tick, decides whether the
/// second was "active" (vs. idle), and writes it to the store. It also
/// publishes live values for the menu-bar popover.
@MainActor
final class Tracker: ObservableObject {
    @Published private(set) var currentAppName: String = "—"
    @Published private(set) var currentBundleId: String?
    @Published private(set) var currentContext: String?   // tab title / project (window title)
    @Published private(set) var isActive: Bool = false
    @Published private(set) var accessibilityGranted: Bool = false
    /// Whether sampling is currently running (toggled by the start/stop button).
    @Published private(set) var isTracking: Bool = false
    /// Shown when tracking has been paused and a resume reminder is due.
    @Published private(set) var pausedReminderActive = false
    /// A ≥10-min away period awaiting the user's label (meeting vs. discard).
    @Published var pendingIdleReview: IdlePeriod?

    private let store: TickerStore
    private let monitor = ActivityMonitor()
    private var timer: Timer?
    private var pausedTimer: Timer?
    private var nextPausedReminder = Date.distantFuture
    private static let pausedReminderInterval: TimeInterval = 60 * 60   // remind every hour
    private var started = false
    private var signalSource: DispatchSourceSignal?
    private var previousBundleId: String?
    private var notifiedGoalDay: Date?
    private var lastCaptureMinute: Date?
    private var idleSince: Date?
    private var lastPresentTick: Date?      // last tick where the user was present (not away)
    private var displaysAsleep = false      // set by screen sleep/wake notifications
    private var systemAsleep = false        // set by system sleep/wake notifications
    private var wasAway = false             // previous tick's away state, for edge detection
    private var awayStart: Date?            // when the current away period began
    private static let idleReviewThreshold: TimeInterval = 10 * 60   // prompt after 10 min away
    weak var breaks: BreakManager?

    /// "Away" = the machine is effectively unattended: screen locked, display
    /// asleep, or the system asleep (lid closed / sleep). Time while away is not
    /// recorded and never surfaced for idle review — only *screen-on* inactivity
    /// (e.g. sitting in a Zoom/Meet call) is treated as reviewable idle time.
    private var isAway: Bool { displaysAsleep || systemAsleep || screenLocked }

    private var screenLocked: Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (info["CGSSessionScreenIsLocked"] as? Int) == 1
    }

    init(store: TickerStore) {
        self.store = store
    }

    func start() {
        guard !started else { return }
        started = true

        accessibilityGranted = Permissions.isAccessibilityTrusted
        installLifecycleHandlers()
        beginSampling()

        // If screenshots are already enabled, re-register with Screen Recording
        // on launch (TCC grants are per-launch and need the app to ask again).
        if store.captureScreenshots {
            ScreenshotService.shared.requestAuthorization()
        }
    }

    /// Start/stop sampling on demand (the start–stop button). Data collected so
    /// far is untouched; pausing just stops recording new activity.
    func setTracking(_ on: Bool) {
        on ? beginSampling() : endSampling()
    }

    private func beginSampling() {
        guard timer == nil else { return }
        monitor.start()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }   // fires on the main run loop
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        isTracking = true
        idleSince = nil          // don't treat the pause gap as an idle stretch
        lastPresentTick = nil
        wasAway = false
        cancelPausedReminders()
    }

    private func endSampling() {
        timer?.invalidate()
        timer = nil
        monitor.stop()
        store.save()
        isActive = false
        isTracking = false
        idleSince = nil
        lastPresentTick = nil
        wasAway = false
        awayStart = nil
        startPausedReminders()
    }

    // MARK: - Paused reminder

    private static let firstReminderAfterWake: TimeInterval = 5 * 60   // ≤5 min after opening the Mac

    /// While tracking is off, remind the user hourly to start it (snoozeable).
    private func startPausedReminders() {
        pausedTimer?.invalidate()
        pausedReminderActive = false
        nextPausedReminder = Date().addingTimeInterval(Self.pausedReminderInterval)
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPausedReminder() }
        }
        RunLoop.main.add(t, forMode: .common)
        pausedTimer = t
    }

    private func cancelPausedReminders() {
        pausedTimer?.invalidate()
        pausedTimer = nil
        pausedReminderActive = false
    }

    /// On waking the Mac, if tracking is off, bring the first reminder forward so
    /// it fires within ~5 minutes of opening the lid (then hourly). Catches the
    /// case where you closed the laptop with tracking paused and forgot to resume.
    private func primePausedReminderOnWake() {
        guard !isTracking else { return }
        let soon = Date().addingTimeInterval(Self.firstReminderAfterWake)
        nextPausedReminder = min(nextPausedReminder, soon)
        pausedReminderActive = false
    }

    private func checkPausedReminder() {
        guard !isTracking, Date() >= nextPausedReminder else { return }
        pausedReminderActive = true
        Notifier.trackingPaused()
        nextPausedReminder = Date().addingTimeInterval(Self.pausedReminderInterval)   // re-remind in an hour
    }

    /// Dismiss the resume reminder for a while (30 / 60 / 120 minutes).
    func snoozePausedReminder(minutes: Int) {
        pausedReminderActive = false
        nextPausedReminder = Date().addingTimeInterval(Double(minutes) * 60)
    }

    func dismissPausedReminder() { pausedReminderActive = false }

    /// Flush pending data on every way the app can go away, so a restart,
    /// logout, shutdown, sleep, or `kill` never drops tracked time. (Writes are
    /// atomic, so an outright crash/power-loss loses at most the last few
    /// seconds without corrupting the file.)
    private func installLifecycleHandlers() {
        // Cmd-Q / normal app termination.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak store] _ in
            MainActor.assumeIsolated { store?.save() }
        }

        // Logout / restart / shutdown, and system sleep.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willPowerOffNotification, NSWorkspace.willSleepNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak store] _ in
                MainActor.assumeIsolated { store?.save() }
            }
        }

        // Presence: display and system sleep/wake mark the machine away so we stop
        // recording and don't misread the gap as reviewable idle time. (Screen
        // *lock* has no notification — it's polled each tick via `isAway`.)
        workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setAway(displays: true) }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setAway(displays: false) }
        }
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.setAway(system: true) }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.setAway(system: false)
                self?.primePausedReminderOnWake()   // first "start tracking" nudge ≤5 min after opening
            }
        }

        // SIGTERM: how the OS terminates apps on logout/restart, and what `kill`
        // sends. The default action would exit immediately without saving, so we
        // ignore it and flush first via a dispatch source.
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak store] in
            MainActor.assumeIsolated { store?.save() }
            exit(0)
        }
        source.resume()
        signalSource = source
    }

    func stop() {
        endSampling()
        cancelPausedReminders()
        started = false
    }

    private func tick() {
        let now = Date()

        // Away (locked / display or system asleep): record nothing and don't
        // accrue idle. On the transition into away, finalize any screen-on idle
        // that preceded it so a Zoom call cut short by a lock is still reviewed.
        if isAway {
            if !wasAway { beginAway() }
            wasAway = true
            _ = monitor.drain()          // discard input so returning doesn't spike
            if isActive { isActive = false }
            return
        }
        if wasAway { endAway() }
        wasAway = false

        let (keys, mouse) = monitor.drain()

        let front = NSWorkspace.shared.frontmostApplication
        let bundleId = front?.bundleIdentifier
        let name = front?.localizedName ?? bundleId ?? "Unknown"

        // Excluded apps are not tracked at all: drop their activity, keys, mouse,
        // context, and screenshots for this tick.
        let excluded = bundleId.map { store.category(for: $0) == .excluded } ?? false

        let recentlyActive = monitor.secondsSinceActivity < Double(store.idleThreshold)
        let active = !excluded && (keys > 0 || mouse > 0 || recentlyActive)

        let switched = bundleId != nil && previousBundleId != nil && bundleId != previousBundleId
        let context = excluded ? nil : ContextReader.frontmostWindowTitle()

        store.addTick(minute: now.startOfMinute,
                      bundleId: excluded ? nil : bundleId,
                      appName: excluded ? nil : name,
                      active: active,
                      keys: excluded ? 0 : keys,
                      mouse: excluded ? 0 : mouse,
                      switched: switched,
                      context: active ? context : nil)

        if let bundleId { previousBundleId = bundleId }
        currentAppName = name
        currentBundleId = bundleId
        currentContext = context
        isActive = active

        updateIdleReview(active: active, now: now)
        lastPresentTick = now
        checkGoalNotification()
        captureScreenshotIfNeeded(minute: now.startOfMinute, active: active)
        breaks?.registerTick(active: active)

        let trusted = Permissions.isAccessibilityTrusted
        if trusted != accessibilityGranted { accessibilityGranted = trusted }
    }

    /// Grabs one screen thumbnail every N active minutes (configurable) when the
    /// user opted in. The attempt itself triggers the permission prompt on first
    /// run (and simply fails quietly until access is granted). Prunes old
    /// thumbnails twice an hour.
    private func captureScreenshotIfNeeded(minute: Date, active: Bool) {
        guard store.captureScreenshots, active else { return }
        let interval = TimeInterval(max(1, store.captureIntervalMinutes) * 60)
        if let last = lastCaptureMinute, minute.timeIntervalSince(last) < interval { return }
        lastCaptureMinute = minute
        ScreenshotService.shared.capture(minute: minute, into: store.screenshotsDirectory)
        if Calendar.current.component(.minute, from: minute) % 30 == 0 {
            store.pruneScreenshots()
        }
    }

    /// Fires a one-time notification the moment today's productive time first
    /// crosses the goal (only if the user opted in).
    private func checkGoalNotification() {
        guard store.notifyOnGoal else { return }
        let goal = store.dailyGoalMinutes * 60
        guard goal > 0 else { return }
        let today = Date().startOfDay
        if notifiedGoalDay != today, store.summary(on: today).productiveSeconds >= goal {
            notifiedGoalDay = today
            Notifier.goalReached(minutes: store.dailyGoalMinutes)
        }
    }

    // MARK: - Presence (away vs. screen-on idle)

    /// Notification-driven away flags. Display/system sleep can suspend the tick
    /// timer, so we mark away here too (not only by polling in `tick`).
    private func setAway(displays: Bool? = nil, system: Bool? = nil) {
        if let displays { displaysAsleep = displays }
        if let system { systemAsleep = system }
        isAway ? beginAway() : endAway()
    }

    /// Entering away: remember when we left, close out any screen-on idle stretch
    /// that ran right up to that moment (so it can still be reviewed), then stop
    /// counting.
    private func beginAway() {
        if awayStart == nil { awayStart = lastPresentTick ?? Date() }
        finalizeIdleOnAway()
        if isActive { isActive = false }
    }

    /// Leaving away: credit the time away as a break — being away from the
    /// computer IS a break, so returning shouldn't immediately fire a reminder
    /// from time accumulated before you left. Then reset the idle baseline so the
    /// unattended gap is never counted as idle.
    private func endAway() {
        if let start = awayStart {
            breaks?.registerAway(seconds: Int(Date().timeIntervalSince(start)))
            awayStart = nil
        }
        idleSince = nil
        lastPresentTick = nil
    }

    /// If screen-on inactivity was accruing when we went away, evaluate just that
    /// screen-on portion (up to the last present tick) for review, then clear it.
    private func finalizeIdleOnAway() {
        guard let start = idleSince else { return }
        let end = lastPresentTick ?? start
        if pendingIdleReview == nil, end.timeIntervalSince(start) >= Self.idleReviewThreshold {
            pendingIdleReview = IdlePeriod(start: start.startOfMinute, end: end.startOfMinute)
        }
        idleSince = nil
    }

    // MARK: - Idle review

    /// Detects a return from ≥10 minutes of inactivity and surfaces the away
    /// period for the user to label. `idleSince` marks when activity first
    /// stopped; on the tick where activity resumes we measure the gap.
    private func updateIdleReview(active: Bool, now: Date) {
        if active {
            if let start = idleSince {
                if pendingIdleReview == nil,
                   now.timeIntervalSince(start) >= Self.idleReviewThreshold {
                    pendingIdleReview = IdlePeriod(start: start.startOfMinute, end: now.startOfMinute)
                }
                idleSince = nil
            }
        } else if idleSince == nil {
            idleSince = now
        }
    }

    /// The away period was a meeting / focused work → count it as productive.
    func confirmIdleWasMeeting() {
        guard let period = pendingIdleReview else { return }
        store.markIntervalAsMeeting(period.interval)
        pendingIdleReview = nil
    }

    /// Discard the away period entirely (remove it from tracked data).
    func discardIdlePeriod() {
        guard let period = pendingIdleReview else { return }
        store.deleteRecords(in: period.interval)
        pendingIdleReview = nil
    }

    /// Dismiss the prompt, leaving the period recorded as ordinary idle time.
    func keepIdlePeriod() { pendingIdleReview = nil }
}
