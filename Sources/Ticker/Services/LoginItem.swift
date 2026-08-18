import ServiceManagement
import Foundation

/// Launch-at-login registration via `SMAppService`.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Ticker: login-item toggle failed: \(error.localizedDescription)")
            return false
        }
    }
}
