import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Captures a single downscaled screenshot of the main display and saves it as a
/// small JPEG thumbnail. Entirely opt-in and on-device — see `TickerStore
/// .captureScreenshots`. Files are named by the minute they belong to
/// (`<secondsSinceReferenceDate>.jpg`).
@MainActor
final class ScreenshotService {
    static let shared = ScreenshotService()

    private var inFlight = false

    /// Registers Ticker with the Screen Recording privacy list and shows the
    /// permission prompt. An app only appears in that list once it actually
    /// touches ScreenCaptureKit, so we call it here rather than relying on the
    /// CoreGraphics request alone.
    func requestAuthorization() {
        Permissions.requestScreenRecording()               // CoreGraphics prompt
        Task { _ = try? await SCShareableContent.current }  // ScreenCaptureKit registration
    }

    /// Fire-and-forget capture for `minute`. No-ops only if a capture is already
    /// running. When permission hasn't been granted yet, the `SCShareableContent`
    /// call throws — which is exactly what registers Ticker in the Screen
    /// Recording list and shows the prompt on the first attempt.
    func capture(minute: Date, into directory: URL, maxWidth: CGFloat = 800) {
        guard !inFlight else { return }
        inFlight = true

        Task {
            defer { inFlight = false }
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first else { return }

                let config = SCStreamConfiguration()
                let scale = min(1, maxWidth / CGFloat(display.width))
                config.width = max(2, Int((CGFloat(display.width) * scale).rounded()))
                config.height = max(2, Int((CGFloat(display.height) * scale).rounded()))
                config.showsCursor = false

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                       configuration: config)
                save(image, minute: minute, into: directory)
            } catch {
                // Capture can fail transiently (permission just revoked, display
                // asleep, etc.). Skip this minute silently.
            }
        }
    }

    private func save(_ cgImage: CGImage, minute: Date, into directory: URL) {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.45]) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(Int(minute.timeIntervalSinceReferenceDate)).jpg"
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }
}
