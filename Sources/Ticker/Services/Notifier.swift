import AppKit
import UserNotifications

/// Local notifications (goal-reached, break reminders, and the "start tracking"
/// reminder with its action button).
enum Notifier {
    /// Category + action identifiers for the "tracking is off" reminder.
    static let pausedCategory = "TRACKING_OFF"
    static let startTrackingAction = "START_TRACKING"

    private static var center: UNUserNotificationCenter? {
        // UNUserNotificationCenter.current() crashes when there's no real .app
        // bundle proxy (unit tests, CLI). Only touch it when running as an app.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return UNUserNotificationCenter.current()
    }

    static func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Registers the "Start Tracking" action button used by the reminder.
    static func registerCategories() {
        guard let center else { return }
        let start = UNNotificationAction(identifier: startTrackingAction,
                                         title: "Start Tracking",
                                         options: [.foreground])
        let category = UNNotificationCategory(identifier: pausedCategory,
                                              actions: [start],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }

    static func goalReached(minutes: Int) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus goal reached 🎯"
        content.body = "You've hit \(Format.compactDuration(minutes * 60)) of productive time today. Nice work!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "ticker.goal.reached", content: content, trigger: nil)
        center.add(request)
    }

    /// Hourly reminder shown while tracking is off, with a "Start Tracking"
    /// button so the user can resume without opening the app.
    static func trackingPaused() {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Ticker isn't tracking"
        content.body = "Tracking is off — you may have forgotten to start it. Your time isn't being counted."
        content.sound = .default
        content.categoryIdentifier = pausedCategory
        let request = UNNotificationRequest(identifier: "ticker.tracking.off", content: content, trigger: nil)
        center.add(request)
    }

    static func breakReminder(_ kind: BreakKind) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.headline + "."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "ticker.break.\(kind.rawValue)", content: content, trigger: nil)
        center.add(request)
    }
}
