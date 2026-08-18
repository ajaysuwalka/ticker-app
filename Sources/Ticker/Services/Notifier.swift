import AppKit
import UserNotifications

/// Local notifications (goal-reached).
enum Notifier {
    private static var center: UNUserNotificationCenter? {
        // UNUserNotificationCenter.current() crashes when there's no real .app
        // bundle proxy (unit tests, CLI). Only touch it when running as an app.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return UNUserNotificationCenter.current()
    }

    static func requestAuthorization() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
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

    static func trackingPaused() {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Ticker is paused ⏸"
        content.body = "Tracking is off — resume when you're ready."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "ticker.paused", content: content, trigger: nil)
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
