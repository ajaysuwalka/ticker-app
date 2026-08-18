import SwiftUI
import AppKit
import Combine

/// Compact "tracking is paused" card with Resume + snooze (30 / 60 / 120 min).
struct PausedReminderView: View {
    var onResume: () -> Void
    var onSnooze: (Int) -> Void

    private let tint = Color(red: 0.42, green: 0.60, blue: 1.0)
    private let cardBG = Color(red: 0.12, green: 0.13, blue: 0.16)

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Tracking is paused")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Ticker isn't recording your activity.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.72))
                HStack(spacing: 8) {
                    Button("Resume") { onResume() }
                        .buttonStyle(.borderedProminent).controlSize(.small).tint(tint)
                    Text("Snooze").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    snooze(30, "30m"); snooze(60, "1h"); snooze(120, "2h")
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 400, alignment: .leading)
        .background(cardBG, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.14)))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 8)
        .environment(\.colorScheme, .dark)
    }

    private func snooze(_ minutes: Int, _ label: String) -> some View {
        Button(label) { onSnooze(minutes) }
            .buttonStyle(.bordered).controlSize(.small).tint(.white)
    }
}

/// Floats the paused reminder near the top of the screen, above other apps.
@MainActor
final class PausedReminderPresenter: ObservableObject {
    private let tracker: Tracker
    private var panel: FloatingPanel?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    init(tracker: Tracker) { self.tracker = tracker }

    func start() {
        guard !started else { return }
        started = true
        tracker.$pausedReminderActive
            .receive(on: RunLoop.main)
            .sink { [weak self] active in active ? self?.show() : self?.hide() }
            .store(in: &cancellables)
    }

    private func show() {
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 400, height: 108)
        let view = PausedReminderView(
            onResume: { [weak self] in self?.tracker.setTracking(true) },
            onSnooze: { [weak self] m in self?.tracker.snoozePausedReminder(minutes: m) })

        let panel = self.panel ?? makePanel()
        panel.contentView = NSHostingView(rootView: view)
        let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2,
                             y: screen.visibleFrame.maxY - size.height - 12)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func makePanel() -> FloatingPanel {
        let p = FloatingPanel(contentRect: .zero,
                              styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
        p.level = .statusBar
        p.appearance = NSAppearance(named: .darkAqua)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return p
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
