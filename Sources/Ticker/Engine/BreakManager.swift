import Foundation
import Combine

/// Tracks continuous active screen time and raises a health-break reminder when
/// the configured interval is reached (a short "move" break and a longer "screen"
/// break). Stepping away long enough counts the break as taken and resets it.
///
/// Only `pending` is `@Published` — the per-second counters are plain so the UI
/// doesn't re-render every tick; live readouts (menu bar) recompute on their own
/// cadence.
@MainActor
final class BreakManager: ObservableObject {
    @Published private(set) var pending: BreakKind?

    private var moveElapsed = 0        // active seconds since last move break
    private var screenElapsed = 0      // active seconds since last screen break
    private var sinceLastBreak = 0     // active seconds since ANY break last fired
    private var idleRun = 0

    private unowned let store: TickerStore

    init(store: TickerStore) { self.store = store }

    var overlayAllScreens: Bool { store.breakOverlayAllScreens }

    /// The configured interval (minutes) that triggers a given break.
    func intervalMinutes(_ kind: BreakKind) -> Int {
        kind == .move ? store.moveBreakMinutes : store.screenBreakMinutes
    }

    var moveInterval: Int { max(5, store.moveBreakMinutes) * 60 }
    var screenInterval: Int { max(5, store.screenBreakMinutes) * 60 }

    /// No break may fire until at least this much active time has passed since the
    /// previous break, so breaks are spaced out instead of bunching together
    /// (e.g. a long break lands ≥ this long after the last short break).
    var minBreakGap: Int { max(0, store.minBreakGapMinutes) * 60 }
    private var gapRemaining: Int { max(0, minBreakGap - sinceLastBreak) }

    /// Configured length of the on-screen break countdown for a given kind.
    func breakDurationSeconds(_ kind: BreakKind) -> Int {
        let minutes = kind == .move ? store.moveBreakDurationMinutes : store.screenBreakDurationMinutes
        return max(1, minutes) * 60
    }

    // Next-appearance countdowns for both breaks. A break appears only once BOTH
    // its own interval and the minimum gap are met — and since only one break can
    // fire at a time, the two are *staggered*: whichever is sooner fires first,
    // and the other is pushed to at least `minBreakGap` after it. This guarantees
    // the two never show the same time.
    var secondsUntilMove: Int { breakCountdowns.move }
    var secondsUntilScreen: Int { breakCountdowns.screen }

    private var breakCountdowns: (move: Int, screen: Int) {
        let moveRem = max(0, moveInterval - moveElapsed)
        let screenRem = max(0, screenInterval - screenElapsed)
        let moveFirst = max(moveRem, gapRemaining)
        let screenFirst = max(screenRem, gapRemaining)

        if screenFirst <= moveFirst {
            // Screen goes first (ties → screen, matching the trigger rule); it also
            // resets the move timer, so move comes a full interval/gap later.
            return (move: screenFirst + max(moveInterval, minBreakGap), screen: screenFirst)
        } else {
            // Move goes first; screen keeps counting but can't precede the gap.
            return (move: moveFirst, screen: max(screenRem, moveFirst + minBreakGap))
        }
    }

    /// Called once per second by the tracker while tracking is running.
    func registerTick(active: Bool) {
        guard store.breakRemindersEnabled else {
            if pending != nil { pending = nil }
            return
        }

        if active {
            idleRun = 0
            moveElapsed += 1
            screenElapsed += 1
            sinceLastBreak += 1
        } else {
            idleRun += 1
            if idleRun == 90 { resetMove() }          // ~1.5 min away → move break taken
            if idleRun == 5 * 60 { resetScreen() }     // 5 min away → screen break taken
        }

        // Enforce the minimum spacing between breaks before considering any trigger.
        if pending == nil && sinceLastBreak >= minBreakGap {
            let dueScreen = screenElapsed >= screenInterval
            let dueMove = moveElapsed >= moveInterval
            if dueScreen && dueMove {
                // Both are due — show only one. Pick the break with more time
                // available (the longer interval); completing a screen break also
                // resets the move timer, so the shorter one won't pop right after.
                trigger(screenInterval >= moveInterval ? .screen : .move)
            } else if dueScreen {
                trigger(.screen)
            } else if dueMove {
                trigger(.move)
            }
        }
    }

    /// Credit a period spent away from the computer (screen locked, display or
    /// system asleep, lid closed) as a break. Without this, time accumulated
    /// before you stepped away would still be there on return and fire a reminder
    /// within minutes of reopening the laptop. Mirrors the idle-away thresholds.
    func registerAway(seconds: Int) {
        guard store.breakRemindersEnabled else { return }
        if seconds >= 5 * 60 {
            resetScreen()          // a real break away from the screen (also covers move)
        } else if seconds >= 90 {
            resetMove()            // long enough to count as a move break
        }
    }

    /// Marks a break as taken and resets its timer.
    func take(_ kind: BreakKind) {
        switch kind {
        case .move: resetMove()
        case .screen: resetScreen()
        }
    }

    /// Dismisses the reminder for now; it returns after `minutes`.
    func snooze(_ kind: BreakKind, minutes: Int = 5) {
        switch kind {
        case .move: moveElapsed = max(0, moveElapsed - minutes * 60)
        case .screen: screenElapsed = max(0, screenElapsed - minutes * 60)
        }
        // Let the snoozed break reappear after `minutes` even under the min-gap
        // rule — snooze is an explicit "remind me soon", not a fresh break.
        sinceLastBreak = max(sinceLastBreak, minBreakGap - minutes * 60)
        pending = nil
    }

    private func trigger(_ kind: BreakKind) {
        pending = kind
        sinceLastBreak = 0          // start the minimum-gap clock from this break
        Notifier.breakReminder(kind)
    }

    private func resetMove() {
        moveElapsed = 0
        sinceLastBreak = 0
        if pending == .move { pending = nil }
    }

    private func resetScreen() {
        screenElapsed = 0
        moveElapsed = 0        // a real break covers moving too
        sinceLastBreak = 0
        pending = nil
    }
}
