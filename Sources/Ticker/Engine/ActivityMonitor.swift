import AppKit

/// Watches global keyboard and mouse events and maintains running interaction
/// counters. It records *counts only* — never which keys or where — so no
/// keystroke content is ever captured or stored.
///
/// Callbacks fire on the main thread, and the counters are drained on the main
/// thread by `Tracker`, so no locking is needed.
@MainActor
final class ActivityMonitor {
    private(set) var pendingKeys = 0
    private(set) var pendingMouse = 0
    private var lastEventDate = Date()

    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return }

        let keyMask: NSEvent.EventTypeMask = [.keyDown]
        let mouseClickMask: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel
        ]
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]

        add(keyMask) { [weak self] in
            self?.pendingKeys += 1
            self?.lastEventDate = Date()
        }
        add(mouseClickMask) { [weak self] in
            self?.pendingMouse += 1
            self?.lastEventDate = Date()
        }
        // Movement/drag counts as activity (resets idle) but not as an
        // "interaction" tally, so passive mouse drift doesn't inflate the graph.
        add(moveMask) { [weak self] in
            self?.lastEventDate = Date()
        }
    }

    private func add(_ mask: NSEvent.EventTypeMask, _ handler: @escaping () -> Void) {
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { _ in handler() }) {
            monitors.append(m)
        }
    }

    func stop() {
        for m in monitors { NSEvent.removeMonitor(m) }
        monitors.removeAll()
    }

    /// Returns the counts accumulated since the last drain and resets them.
    func drain() -> (keys: Int, mouse: Int) {
        let result = (pendingKeys, pendingMouse)
        pendingKeys = 0
        pendingMouse = 0
        return result
    }

    /// Seconds since the last observed input, combining our own monitor timing
    /// with the system-wide idle timer (which works even without Accessibility).
    var secondsSinceActivity: TimeInterval {
        let sinceMonitor = Date().timeIntervalSince(lastEventDate)
        let anyEvent = CGEventType(rawValue: ~0) ?? .null
        let systemIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyEvent)
        return min(sinceMonitor, systemIdle)
    }
}
