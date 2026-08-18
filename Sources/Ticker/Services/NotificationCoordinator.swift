import AppKit
import UserNotifications

/// Registers notification categories/actions and routes the "Start Tracking"
/// button (and taps) on the reminder back to the tracker. Retained by the app so
/// it stays the `UNUserNotificationCenter` delegate for the app's lifetime.
@MainActor
final class NotificationCoordinator: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let tracker: Tracker
    private var started = false

    init(tracker: Tracker) {
        self.tracker = tracker
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        // UNUserNotificationCenter.current() crashes without a real .app bundle.
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        Notifier.registerCategories()
        Notifier.requestAuthorization()
    }

    // Show the reminder even when Ticker itself is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle the "Start Tracking" action button (and a tap on the reminder).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let category = response.notification.request.content.categoryIdentifier
        guard category == Notifier.pausedCategory,
              action == Notifier.startTrackingAction || action == UNNotificationDefaultActionIdentifier
        else { return }
        await MainActor.run { tracker.setTracking(true) }
    }
}
