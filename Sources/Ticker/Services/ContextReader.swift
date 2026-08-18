import AppKit
import ApplicationServices

/// Reads the title of the frontmost window — which is the active tab title in
/// browsers and the project/file in editors and IDEs. Needs Accessibility
/// permission (the same one used for keyboard counts); returns nil otherwise.
enum ContextReader {
    static func frontmostWindowTitle() -> String? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowRef, CFGetTypeID(windowRef) == AXUIElementGetTypeID() else { return nil }
        // Safe: we just checked CFGetTypeID matches AXUIElement above.
        let window = windowRef as! AXUIElement   // swiftlint:disable:this force_cast

        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
              let title = titleRef as? String else { return nil }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(200))
    }
}
