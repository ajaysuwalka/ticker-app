import SwiftUI
import AppKit
import Combine

/// A borderless panel that floats above every app and Space — used to show the
/// break reminder system-wide.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Bridges `BreakManager.pending` to a system-wide floating overlay window (when
/// enabled in Settings). When disabled, the dashboard's in-app overlay is used
/// instead.
@MainActor
final class BreakPresenter: ObservableObject {
    private let breaks: BreakManager
    private let store: TickerStore
    private var panel: FloatingPanel?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    init(breaks: BreakManager, store: TickerStore) {
        self.breaks = breaks
        self.store = store
    }

    func start() {
        guard !started else { return }
        started = true
        breaks.$pending
            .receive(on: RunLoop.main)
            .sink { [weak self] kind in self?.update(kind) }
            .store(in: &cancellables)
        store.$breakOverlayAllScreens
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update(self?.breaks.pending) }
            .store(in: &cancellables)
    }

    private func update(_ kind: BreakKind?) {
        guard let kind, store.breakOverlayAllScreens else { hide(); return }
        show(kind)
    }

    private func show(_ kind: BreakKind) {
        guard let screen = NSScreen.main else { return }
        let view = BreakOverlayView(
            kind: kind,
            intervalMinutes: breaks.intervalMinutes(kind),
            breakSeconds: breaks.breakDurationSeconds(kind),
            onComplete: { [weak self] in self?.breaks.take(kind) },
            onSnooze: { [weak self] in self?.breaks.snooze(kind) })

        let panel = self.panel ?? makePanel(on: screen)
        panel.contentView = NSHostingView(rootView: view)
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func makePanel(on screen: NSScreen) -> FloatingPanel {
        let panel = FloatingPanel(contentRect: screen.frame,
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: false)
        panel.level = .screenSaver                 // above normal & floating windows
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        return panel
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
